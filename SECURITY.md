# Security Policy

## Supported Versions

We actively support and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of this infrastructure code seriously. If you discover a security vulnerability, please follow these steps:

### 1. **Do Not** Open a Public Issue

Please **do not** report security vulnerabilities through public GitHub issues.

### 2. Report Privately

Report security vulnerabilities by emailing **<security@example.com>** or using [GitHub Security Advisories](https://github.com/malpanez/hetzner-secure-infrastructure/security/advisories/new).

### 3. Provide Details

Include the following information:

- Type of issue (e.g., privilege escalation, code injection, etc.)
- Full paths of source file(s) related to the issue
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

### 4. Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: Within 7 days
  - High: Within 14 days
  - Medium: Within 30 days
  - Low: Next scheduled release

## Security Best Practices

When deploying this infrastructure, follow these security best practices:

### Credentials Management

- Never commit credentials to version control
- Use OpenBao/Vault for secrets management
- Rotate credentials regularly
- Use SSH keys with passphrases
- Enable 2FA where possible

### Infrastructure Hardening

- Keep all software up to date
- Enable automatic security updates
- Use UFW firewall with minimal open ports
- Configure Fail2ban for intrusion prevention
- Enable AppArmor profiles
- Regular security audits with `lynis`

### Monitoring & Logging

- Enable centralized logging
- Monitor Prometheus alerts
- Review Grafana dashboards regularly
- Set up alerting for suspicious activities
- Retain logs for compliance requirements

### Network Security

- Use Cloudflare WAF
- Enable DDoS protection
- Use private networking where possible
- Segment networks appropriately
- Use VPN for management access

### Access Control

- Implement least privilege principle
- Use separate accounts for different purposes
- Disable root SSH login
- Use SSH keys only (no passwords)
- Regular access reviews

## Security Testing

This project includes:

- **TFSec**: Terraform security scanning
- **Trivy**: Container and infrastructure vulnerability scanning
- **GitLeaks**: Secret detection
- **Ansible-lint**: Ansible security best practices
- **KICS**: Infrastructure as Code security scanning

Run security scans:

```bash
make security-scan
```

## Known Security Considerations

### Terraform State

- State files may contain sensitive data
- Use remote state with encryption
- Restrict access to state files
- Never commit state files to version control

### Ansible Vault

- Use strong passwords for Ansible Vault
- Rotate vault passwords regularly
- Store vault passwords securely (e.g., password manager)
- Use separate vaults for different environments

### SSH Access

- Use YubiKey or similar hardware keys for 2FA
- Disable password authentication
- Use SSH certificates where appropriate
- Regular key rotation

## Compliance

This infrastructure aims to follow:

- CIS Benchmarks for Linux
- OWASP Top 10 security practices
- Red Hat Community of Practice standards
- SOC 2 Type II controls (where applicable)

## Security Updates

Subscribe to security updates:

- Watch this repository for security advisories
- Follow [@malpanez](https://codeberg.org/malpanez) for announcements
- Check [CHANGELOG.md](CHANGELOG.md) for security fixes

## Credits

We recognize and thank security researchers who responsibly disclose vulnerabilities:

<!-- This section will be updated as vulnerabilities are reported and fixed -->

## Questions?

For general security questions (not vulnerabilities), please:

1. Check existing documentation
2. Search closed issues
3. Open a discussion in GitHub Discussions

---

**Last Updated**: 2025-12-26
