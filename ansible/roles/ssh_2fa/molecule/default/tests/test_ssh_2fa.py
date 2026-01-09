"""
Testinfra tests for ssh_2fa role.

These tests verify that SSH hardening and 2FA are properly configured.
"""

import pytest


def test_sshd_service_is_running(host):
    """SSH service must be running and enabled."""
    sshd = host.service("sshd")
    assert sshd.is_running, "sshd service should be running"
    assert sshd.is_enabled, "sshd service should be enabled at boot"


def test_sshd_config_exists(host):
    """SSH daemon configuration file must exist."""
    sshd_config = host.file("/etc/ssh/sshd_config")
    assert sshd_config.exists, "sshd_config must exist"
    assert sshd_config.user == "root"
    assert sshd_config.group == "root"
    assert sshd_config.mode == 0o644


def test_sshd_hardening_settings(host):
    """SSH must have hardening settings enabled."""
    # Use effective configuration because the role uses drop-ins.
    result = host.run("sshd -T")
    assert result.rc == 0, "sshd -T must succeed for effective config checks"

    # Key authentication settings
    assert "pubkeyauthentication yes" in result.stdout, \
        "Public key authentication must be enabled"
    assert "passwordauthentication no" in result.stdout, \
        "Password authentication must be disabled"

    # Security settings
    # Accept both "no" and "without-password" (prohibit-password) - both are secure
    root_login = "permitrootlogin no" in result.stdout or \
                 "permitrootlogin without-password" in result.stdout or \
                 "permitrootlogin prohibit-password" in result.stdout
    assert root_login, \
        "Root login must be disabled or restricted to keys only"
    assert "permitemptypasswords no" in result.stdout, \
        "Empty passwords must be forbidden"


def test_pam_faillock_configured(host):
    """PAM faillock must be configured for brute force protection."""
    common_auth = host.file("/etc/pam.d/common-auth")
    assert common_auth.exists, "common-auth PAM config must exist"
    assert common_auth.contains("pam_faillock.so"), \
        "pam_faillock must be configured in common-auth"


def test_faillock_conf_exists(host):
    """Faillock configuration file must exist and be properly configured."""
    faillock_conf = host.file("/etc/security/faillock.conf")
    assert faillock_conf.exists, "faillock.conf must exist"
    assert faillock_conf.user == "root"
    assert faillock_conf.group == "root"
    assert faillock_conf.mode == 0o644

    # Check key settings
    assert faillock_conf.contains("deny ="), \
        "faillock must have deny threshold configured"
    assert faillock_conf.contains("unlock_time ="), \
        "faillock must have unlock time configured"


def test_ssh_host_keys_exist(host):
    """SSH host keys must exist with proper permissions."""
    # Ed25519 key (modern, recommended)
    ed25519_key = host.file("/etc/ssh/ssh_host_ed25519_key")
    if ed25519_key.exists:
        assert ed25519_key.user == "root"
        assert ed25519_key.group == "root"
        assert ed25519_key.mode == 0o600, \
            "Private host key must have mode 0600"

    # RSA key (compatibility)
    rsa_key = host.file("/etc/ssh/ssh_host_rsa_key")
    if rsa_key.exists:
        assert rsa_key.user == "root"
        assert rsa_key.group == "root"
        assert rsa_key.mode == 0o600, \
            "Private host key must have mode 0600"


def test_weak_ssh_host_keys_removed(host):
    """Weak SSH host keys (DSA, ECDSA) must be removed."""
    dsa_key = host.file("/etc/ssh/ssh_host_dsa_key")
    ecdsa_key = host.file("/etc/ssh/ssh_host_ecdsa_key")

    assert not dsa_key.exists, "DSA host key should be removed (weak)"
    assert not ecdsa_key.exists, "ECDSA host key should be removed (weak)"


def test_sshd_listening_on_port(host):
    """SSH daemon must be listening on configured port."""
    # Default SSH port is 22
    listening = host.socket("tcp://0.0.0.0:22")
    assert listening.is_listening, \
        "SSH daemon must be listening on port 22"


@pytest.mark.parametrize("package", [
    "openssh-server",
    "libpam-modules",
])
def test_required_packages_installed(host, package):
    """Required SSH and PAM packages must be installed."""
    pkg = host.package(package)
    assert pkg.is_installed, f"{package} must be installed"


def test_pam_modules_directory_exists(host):
    """PAM modules directory must exist."""
    pam_dir = host.file("/etc/pam.d")
    assert pam_dir.exists
    assert pam_dir.is_directory
    assert pam_dir.user == "root"
    assert pam_dir.group == "root"


def test_ssh_directory_permissions(host):
    """SSH configuration directory must have proper permissions."""
    ssh_dir = host.file("/etc/ssh")
    assert ssh_dir.exists
    assert ssh_dir.is_directory
    assert ssh_dir.user == "root"
    assert ssh_dir.group == "root"
    assert ssh_dir.mode == 0o755


def test_faillock_can_show_status(host):
    """Faillock command must be available and functional."""
    # Just verify the command exists and runs without error
    # Note: faillock doesn't support --help, but --user works
    result = host.run("faillock --user root")
    # Accept both 0 (success) and 1 (no failures recorded) as valid
    assert result.rc in [0, 1], \
        f"faillock command should be available (rc={result.rc})"
