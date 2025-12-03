#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Minimal, simple bootstrap for VersityGW internal IAM
#
# For EACH user:
#   - Generate random access/secret (stored in /etc/versitygw/users.d/<user>.env)
#   - Create IAM user with role "user"
#   - Create bucket "<user>-bucket" (if missing)
#   - Assign bucket owner to that user
#
# All operations are idempotent and safe to re-run.
# ------------------------------------------------------------------------------

GATEWAY_ENDPOINT="${GATEWAY_ENDPOINT:-http://127.0.0.1:7070}"
CONTAINER_NAME="${CONTAINER_NAME:-versitygw}"

ROOT_ACCESS="${ROOT_ACCESS_KEY:?ROOT_ACCESS_KEY not set}"
ROOT_SECRET="${ROOT_SECRET_KEY:?ROOT_SECRET_KEY not set}"

USERS_DIR=/etc/versitygw/users.d

# ------------------------------
# Define your users here
# ------------------------------
USERS=(
  "slurmd"
  "fabricmanager"
)

# ------------------------------------------------------------------------------
# Wait for gateway to be up
# ------------------------------------------------------------------------------
echo "bootstrap: waiting for VersityGW at ${GATEWAY_ENDPOINT}..."
for i in {1..60}; do
  if curl -sSf "${GATEWAY_ENDPOINT}" >/dev/null 2>&1; then
    echo "bootstrap: gateway is up."
    break
  fi
  sleep 1
done

# ------------------------------------------------------------------------------
# Helper to call versitygw admin inside container
# ------------------------------------------------------------------------------
vgw_admin() {
  podman exec "${CONTAINER_NAME}" \
    versitygw admin \
      --access "${ROOT_ACCESS}" \
      --secret "${ROOT_SECRET}" \
      --endpoint-url "${GATEWAY_ENDPOINT}" \
      "$@"
}

# Ensure dir exists
mkdir -p "${USERS_DIR}"
chmod 700 "${USERS_DIR}"
chown root:root "${USERS_DIR}"

# ------------------------------------------------------------------------------
# Configure root AWS profile for bucket operations
# ------------------------------------------------------------------------------
ROOT_PROFILE="vgw-root"

mkdir -p /root/.aws
chmod 700 /root/.aws

cat > /root/.aws/credentials <<EOF
[${ROOT_PROFILE}]
aws_access_key_id     = ${ROOT_ACCESS}
aws_secret_access_key = ${ROOT_SECRET}
EOF

chmod 600 /root/.aws/credentials

# ------------------------------------------------------------------------------
# Main loop: per-user IAM + bucket
# ------------------------------------------------------------------------------
for user in "${USERS[@]}"; do
  echo "bootstrap: processing '${user}'"

  user_file="${USERS_DIR}/${user}.env"

  # 1. Generate access/secret if not already created
  if [[ ! -f "${user_file}" ]]; then
    echo "  generating new credentials"
    umask 077
    access=$(openssl rand -hex 16)
    secret=$(openssl rand -hex 32)
    cat > "${user_file}" <<EOF
VGW_USER=${user}
VGW_ACCESS_KEY=${access}
VGW_SECRET_KEY=${secret}
EOF
    chmod 600 "${user_file}"
    chown root:root "${user_file}"
  else
    # shellcheck disable=SC1090
    . "${user_file}"
    access="${VGW_ACCESS_KEY}"
    secret="${VGW_SECRET_KEY}"
    echo "  using existing credentials"
  fi

  # 2. Ensure IAM user exists (role=default 'user')
  if vgw_admin list-users 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx "${access}"; then
    echo "  IAM user exists"
  else
    echo "  creating IAM user"
    vgw_admin create-user \
      --access "${access}" \
      --secret "${secret}" \
      --role user
  fi

  # 3. Ensure bucket exists
  bucket="${user}-bucket"

  if aws --profile "${ROOT_PROFILE}" \
         --endpoint-url "${GATEWAY_ENDPOINT}" \
         s3api head-bucket --bucket "${bucket}" >/dev/null 2>&1; then
    echo "  bucket exists (${bucket})"
  else
    echo "  creating bucket ${bucket}"
    aws --profile "${ROOT_PROFILE}" \
        --endpoint-url "${GATEWAY_ENDPOINT}" \
        s3api create-bucket --bucket "${bucket}"
  fi

  # 4. Assign bucket owner
  echo "  assigning bucket owner"
  vgw_admin change-bucket-owner \
    --bucket "${bucket}" \
    --owner "${access}"

  echo "  done for ${user}"
done

echo "bootstrap: COMPLETE"
