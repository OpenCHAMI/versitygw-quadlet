Name:           versitygw-quadlet
Version:        0.1.0
Release:        1%{?dist}
Summary:        VersityGW Podman Quadlet and bootstrap services

License:        MIT
URL:            https://github.com/openchami/versitygw-quadlet
Source0:        versitygw-gensecrets.sh
Source1:        versitygw-bootstrap.sh
Source2:        versitygw-gensecrets.service
Source3:        versitygw-bootstrap.service
Source4:        versitygw.container

BuildArch:      noarch

Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd
Requires:       podman
Requires:       aws-cli
Requires:       openssl

%description
Installs a Podman Quadlet unit to run the Versity S3 Gateway (versitygw)
with internal IAM, plus two systemd oneshot services:

  - versitygw-gensecrets.service: generate root credentials in
    /etc/versitygw/secrets.env

  - versitygw-bootstrap.service: generate random per-user API keys,
    create IAM users and per-user buckets, and assign bucket ownership.

This package does **not** provide the versitygw container image itself;
it expects ghcr.io/versity/versitygw:latest (or equivalent) to be
available to Podman.


%prep
# Nothing to unpack; sources are just unit/script files.


%build
# No build step required.


%install
mkdir -p %{buildroot}/usr/local/libexec
mkdir -p %{buildroot}/etc/systemd/system
mkdir -p %{buildroot}/usr/share/containers/systemd
mkdir -p %{buildroot}/etc/versitygw/users.d
mkdir -p %{buildroot}/var/lib/versitygw/data
mkdir -p %{buildroot}/var/lib/versitygw/iam

# Scripts
install -m 0755 %{SOURCE0} %{buildroot}/usr/local/libexec/versitygw-gensecrets.sh
install -m 0755 %{SOURCE1} %{buildroot}/usr/local/libexec/versitygw-bootstrap.sh

# systemd units
install -m 0644 %{SOURCE2} %{buildroot}/etc/systemd/system/versitygw-gensecrets.service
install -m 0644 %{SOURCE3} %{buildroot}/etc/systemd/system/versitygw-bootstrap.service

# Quadlet unit
install -m 0644 %{SOURCE4} %{buildroot}/usr/share/containers/systemd/versitygw.container

# Directories with appropriate permissions (secrets dir will be tightened at runtime)
chmod 0755 %{buildroot}/etc/versitygw
chmod 0700 %{buildroot}/etc/versitygw/users.d
chmod 0755 %{buildroot}/var/lib/versitygw
chmod 0755 %{buildroot}/var/lib/versitygw/data
chmod 0755 %{buildroot}/var/lib/versitygw/iam


%pre
# Ensure base directories exist and are root-owned at install time.
# Secrets file will be created by versitygw-gensecrets.service.
if [ $1 -eq 1 ]; then
    # fresh install
    mkdir -p /etc/versitygw/users.d
    chown root:root /etc/versitygw /etc/versitygw/users.d || :
    chmod 0755 /etc/versitygw || :
    chmod 0700 /etc/versitygw/users.d || :

    mkdir -p /var/lib/versitygw/data /var/lib/versitygw/iam
    chown root:root /var/lib/versitygw /var/lib/versitygw/data /var/lib/versitygw/iam || :
fi


%post
# Reload systemd so it sees new units and quadlet-derived services.
%systemd_post versitygw-gensecrets.service versitygw-bootstrap.service

# Note: we do NOT auto-enable services by default; admins can
#       enable them as appropriate:
#       systemctl enable --now versitygw-gensecrets.service versitygw.service versitygw-bootstrap.service

# Optionally, ensure quadlet units are re-generated into systemd:
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || :
fi


%preun
%systemd_preun versitygw-gensecrets.service versitygw-bootstrap.service


%postun
%systemd_postun_with_restart versitygw-gensecrets.service versitygw-bootstrap.service


%files
%license
%doc

# Scripts
/usr/local/libexec/versitygw-gensecrets.sh
/usr/local/libexec/versitygw-bootstrap.sh

# systemd units
/etc/systemd/system/versitygw-gensecrets.service
/etc/systemd/system/versitygw-bootstrap.service

# Quadlet definition
/usr/share/containers/systemd/versitygw.container

# Config & runtime dirs
%dir /etc/versitygw
%dir /etc/versitygw/users.d
%dir /var/lib/versitygw
%dir /var/lib/versitygw/data
%dir /var/lib/versitygw/iam


%changelog
* Wed Dec 03 2025 Your Name <alovelltroy@lanl.gov> - 0.1.0-1
- Initial package for versitygw quadlet + IAM bootstrap
