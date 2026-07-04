# Hetzner Secure Infrastructure

[![CI](https://github.com/malpanez/hetzner-secure-infrastructure/actions/workflows/ci.yml/badge.svg)](https://github.com/malpanez/hetzner-secure-infrastructure/actions/workflows/ci.yml)
[![Terraform Validation](https://github.com/malpanez/hetzner-secure-infrastructure/actions/workflows/terraform-validate.yml/badge.svg)](https://github.com/malpanez/hetzner-secure-infrastructure/actions/workflows/terraform-validate.yml)
[![Release](https://img.shields.io/github/v/release/malpanez/hetzner-secure-infrastructure)](https://github.com/malpanez/hetzner-secure-infrastructure/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Reusable, production-tested **Terraform/OpenTofu modules** and **Ansible roles** for running
hardened workloads on [Hetzner Cloud](https://www.hetzner.com/cloud) behind
[Cloudflare](https://www.cloudflare.com/) — built and maintained by
[Winning Concepts Ltd](https://github.com/malpanez).

Everything here runs a real production workload: a hardened Debian 13 VPS serving WordPress
behind Cloudflare Full (strict) TLS, with OpenBao secrets management, SSH 2FA, AppArmor
confinement and off-site backups.

## What's inside

### Terraform / OpenTofu modules (`terraform/modules/`)

| Module | What it does |
|---|---|
| `hetzner-server` | VPS + firewall (origin locked to Cloudflare IPs optional) |
| `cloudflare-config` | DNS, zone hardening (TLS strict, HSTS), WAF custom rules, CSP via response-header transforms, cache rules, per-path config rules, Zero Trust Access apps |
| `object-storage` | Hetzner S3-compatible buckets with lifecycle/CORS |

### Ansible roles (`ansible/roles/`)

| Role | What it does |
|---|---|
| `common` | Base system: users, packages, timezone, journald |
| `security_hardening` | CIS-flavoured hardening: sysctl, auditd, AIDE, module blacklists |
| `ssh_2fa` | OpenSSH + TOTP (Google Authenticator PAM), faillock |
| `firewall` | UFW with strict defaults |
| `fail2ban` | Jailed brute-force protection |
| `apparmor` | AppArmor profiles deployed as templates, enforce/complain toggle |
| `valkey` | Valkey (Redis-compatible) object cache |
| `openbao` | OpenBao (Vault fork) with transit auto-unseal dual-instance pattern |
| `monitoring` | Prometheus + Grafana + exporters behind nginx reverse proxies |
| `backup` | Encrypted off-site backups to S3-compatible storage |
| `grype` | Container/filesystem vulnerability scanning |
| `cloudflare_origin_ssl` | Deploy a Cloudflare Origin CA certificate for Full (strict) TLS |

### Examples (`examples/`)

- `basic-server` — minimal VPS + firewall
- `wordpress-production` — the full stack wired together

## Quick start

```bash
# 1. Provision the server
cd examples/basic-server
tofu init && tofu plan   # set your hcloud token + domain first (no defaults on purpose)

# 2. Configure it
cd ../../ansible
ansible-playbook -i inventory/hosts.yml site.yml
```

Every variable that identifies *your* infrastructure (domain, IPs, buckets) has **no default** —
the modules force you to set them explicitly.

## Testing

- **Molecule** scenarios for all 13 roles (Docker, Debian 13 images)
- **Terratest** suite for the Terraform modules (`terraform/test/`)
- Lint suite via pre-commit: ansible-lint (production profile), tflint, tfsec, yamllint, gitleaks

Performance notes: ARM64 (CAX11) vs x86 (CX22) benchmarks are documented in
`docs/performance/` — measured results, draw your own conclusions for your workload.

## Security

See [SECURITY.md](SECURITY.md). Highlights of the design:

- Origin firewall locked to Cloudflare IPs; TLS Full (strict) with Origin CA certs
- SSH: key-only + TOTP 2FA, faillock, no root login
- Secrets never in git: OpenBao (transit auto-unseal) or ansible-vault
- AppArmor enforced on exposed services; auditd + AIDE for integrity

## License

[MIT](LICENSE)
