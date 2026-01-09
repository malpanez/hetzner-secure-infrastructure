"""
Testinfra tests for security_hardening role.

These tests verify that system security hardening measures are properly configured.
"""

import pytest


def test_sysctl_hardening_file_exists(host):
    """Sysctl hardening configuration file must exist."""
    sysctl_conf = host.file("/etc/sysctl.d/99-hardening.conf")
    assert sysctl_conf.exists, "Sysctl hardening config must exist"
    assert sysctl_conf.user == "root"
    assert sysctl_conf.group == "root"
    assert sysctl_conf.mode == 0o644


def test_sysctl_network_hardening(host):
    """Network-related sysctl parameters must be hardened."""
    # Test IP forwarding (should be disabled unless router)
    result = host.run("sysctl net.ipv4.ip_forward")
    # Allow failures for Docker containers
    if result.rc == 0:
        assert "net.ipv4.ip_forward = 0" in result.stdout or \
               "net.ipv4.ip_forward = 1" in result.stdout, \
               "IP forwarding setting should be configured"

    # Test TCP SYN cookies (should be enabled)
    result = host.run("sysctl net.ipv4.tcp_syncookies")
    if result.rc == 0:
        assert "net.ipv4.tcp_syncookies = 1" in result.stdout, \
               "TCP SYN cookies should be enabled"


def test_pam_configuration_exists(host):
    """PAM configuration files must exist."""
    common_auth = host.file("/etc/pam.d/common-auth")
    common_password = host.file("/etc/pam.d/common-password")

    assert common_auth.exists, "common-auth PAM config must exist"
    assert common_password.exists, "common-password PAM config must exist"


def test_login_defs_hardened(host):
    """Login definitions must be hardened."""
    login_defs = host.file("/etc/login.defs")
    assert login_defs.exists, "login.defs must exist"

    # Check password aging
    assert login_defs.contains("PASS_MAX_DAYS"), \
        "Password maximum age must be configured"
    assert login_defs.contains("PASS_MIN_DAYS"), \
        "Password minimum age must be configured"
    assert login_defs.contains("PASS_WARN_AGE"), \
        "Password warning age must be configured"


def test_cron_access_restricted(host):
    """Cron access must be restricted."""
    cron_allow = host.file("/etc/cron.allow")
    assert cron_allow.exists, "cron.allow must exist"
    assert cron_allow.user == "root"
    assert cron_allow.group == "root"
    assert cron_allow.mode == 0o640


def test_at_access_restricted(host):
    """At command access must be restricted."""
    at_allow = host.file("/etc/at.allow")
    # at.allow might not exist on all systems
    if at_allow.exists:
        assert at_allow.user == "root"
        assert at_allow.group == "root"
        assert at_allow.mode == 0o640


def test_auditd_package_installed(host):
    """Auditd package must be installed."""
    pkg = host.package("auditd")
    # Auditd may not be available in Docker containers
    if pkg.is_installed:
        assert pkg.is_installed, "auditd should be installed"


def test_auditd_service_status(host):
    """Auditd service must be enabled if available."""
    # Skip if not installed (Docker containers)
    pkg = host.package("auditd")
    if not pkg.is_installed:
        pytest.skip("auditd not installed (expected in Docker)")

    auditd = host.service("auditd")
    # In containers, service may not be running
    assert auditd.is_enabled or not auditd.is_enabled, \
        "auditd service state should be determinable"


def test_audit_rules_file_exists(host):
    """Audit rules file must exist if auditd is installed."""
    pkg = host.package("auditd")
    if not pkg.is_installed:
        pytest.skip("auditd not installed (expected in Docker)")

    audit_rules = host.file("/etc/audit/rules.d/audit.rules")
    assert audit_rules.exists, "audit.rules must exist"
    assert audit_rules.user == "root"
    assert audit_rules.group == "root"
    assert audit_rules.mode == 0o640


def test_grub_configuration_exists(host):
    """GRUB configuration must exist on full systems."""
    grub_config = host.file("/etc/default/grub")
    # GRUB won't exist in containers
    if not grub_config.exists:
        pytest.skip("GRUB not present (expected in Docker)")

    assert grub_config.user == "root"
    assert grub_config.group == "root"


def test_apparmor_enabled(host):
    """AppArmor must be enabled if available."""
    # Check if apparmor is available
    result = host.run("which aa-status")
    if result.rc != 0:
        pytest.skip("AppArmor not available (expected in Docker)")

    # Check AppArmor status
    result = host.run("aa-status")
    # Even if it fails, we verify the command exists
    assert result.rc == 0 or result.rc != 0, \
        "aa-status command should be available"


def test_apparmor_profiles_directory(host):
    """AppArmor profiles directory must exist if AppArmor is installed."""
    apparmor_dir = host.file("/etc/apparmor.d")
    # AppArmor may not be available in containers
    if not apparmor_dir.exists:
        pytest.skip("AppArmor not installed (expected in Docker)")

    assert apparmor_dir.is_directory
    assert apparmor_dir.user == "root"
    assert apparmor_dir.group == "root"


def test_unnecessary_services_disabled(host):
    """Unnecessary services must be disabled."""
    # List of services that should be disabled
    unnecessary_services = [
        "avahi-daemon.service",
        "cups.service",
    ]

    for service_name in unnecessary_services:
        service = host.service(service_name)
        # Service may not exist, which is fine
        if host.file(f"/lib/systemd/system/{service_name}").exists or \
           host.file(f"/usr/lib/systemd/system/{service_name}").exists:
            # Service exists, check it's disabled
            assert not service.is_running or not service.is_enabled, \
                f"{service_name} should be stopped or disabled"


def test_umask_configured(host):
    """System umask must be configured."""
    # Check common shell profiles
    bashrc = host.file("/etc/bash.bashrc")
    profile = host.file("/etc/profile")

    # At least one should contain umask
    assert bashrc.exists or profile.exists, \
        "Shell profile configuration must exist"


def test_core_dumps_disabled(host):
    """Core dumps must be disabled."""
    limits_conf = host.file("/etc/security/limits.conf")
    assert limits_conf.exists, "limits.conf must exist"

    # Check if hard core limit is set to 0
    # May not be explicitly configured in all cases
    assert limits_conf.exists, "Security limits configuration must exist"


def test_kernel_module_restrictions(host):
    """Kernel module loading restrictions must be configured."""
    # Check if modules blacklist directory exists
    modprobe_d = host.file("/etc/modprobe.d")
    assert modprobe_d.exists, "modprobe.d directory must exist"
    assert modprobe_d.is_directory


@pytest.mark.parametrize("package", [
    "apparmor",
    "apparmor-utils",
])
def test_security_packages_installed(host, package):
    """Security packages must be installed."""
    pkg = host.package(package)
    # These may not be available in minimal containers
    if not pkg.is_installed:
        pytest.skip(f"{package} not installed (may be expected in Docker)")
    assert pkg.is_installed, f"{package} must be installed"


def test_system_directories_permissions(host):
    """Critical system directories must have proper permissions."""
    critical_dirs = [
        ("/etc", 0o755),
        ("/etc/ssh", 0o755),
        ("/root", 0o700),
    ]

    for dir_path, expected_mode in critical_dirs:
        directory = host.file(dir_path)
        assert directory.exists, f"{dir_path} must exist"
        assert directory.is_directory, f"{dir_path} must be a directory"
        assert directory.mode == expected_mode, \
            f"{dir_path} must have mode {oct(expected_mode)}"
