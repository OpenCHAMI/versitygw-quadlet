#!/usr/bin/env bash
set -euo pipefail

SECRET_DIR=/etc/versitygw
SECRET_FILE="${SECRET_DIR}/secrets.env"

mkdir -p "${SECRET_DIR}"
chmod 700 "${SECRET_DIR}"
chown root:root "${SECRET_DIR}"

if [[ -f "${SECRET_FILE}" ]]; then
  echo "versitygw-gensecrets: ${SECRET_FILE} already exists, leaving it alone."
  exit 0
fi

umask 077

ROOT_ACCESS_KEY=$(openssl rand -hex 16)
ROOT_SECRET_KEY=$(openssl rand -hex 32)

cat > "${SECRET_FILE}" <<EOF
# Root credentials for VersityGW
ROOT_ACCESS_KEY=${ROOT_ACCESS_KEY}
ROOT_SECRET_KEY=${ROOT_SECRET_KEY}
VGW_REGION=us-east-1
EOF

chmod 600 "${SECRET_FILE}"
chown root:root "${SECRET_FILE}"

echo "versitygw-gensecrets: created ${SECRET_FILE}"
