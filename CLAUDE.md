# Project: hetzner-secure-infrastructure

## Purpose

Hetzner VPS infrastructure for WordPress (LearnDash LMS) managed with Terraform + Ansible,
hardened with OpenBao secrets management, SSH 2FA, AppArmor, and Cloudflare.

## Stack

- **IaC**: Terraform (cloud resources) + Ansible (config management)
- **Target**: Hetzner Cloud (single VPS, production)
- **OS**: Debian 13
- **CI**: GitHub Actions (CI runs on GitHub; primary remote is Codeberg)
- **Secrets**: OpenBao (Vault fork) on port 8200/8201 (transit auto-unseal)

## Project structure

```text
ansible/
  inventory/          # hcloud dynamic + static inventories
  playbooks/          # site.yml (unified orchestrator), dual-wordpress.yml, openbao.yml, monitoring.yml, validate.yml
  roles/              # apparmor, common, fail2ban, firewall, geerlingguy.mysql,
                      # monitoring, nginx_wordpress, openbao, security_hardening,
                      # ssh_2fa, valkey, cloudflare_origin_ssl
terraform/
  modules/
    hetzner-server/   # VPS + firewall
    cloudflare-config/ # DNS + SSL
scripts/              # deploy-full.sh, generate-secrets.sh, validate-all.sh
docs/                 # architecture, guides, security, troubleshooting
```

## Key conventions

- All roles must pass `molecule test` (default scenario) before merge
- Ansible: FQCN for all modules (`ansible.builtin.*`)
- Terraform: `_` not `-` in resource names; never `apply` without plan review
- Pre-commit hooks: yamllint (max 250 chars), ansible-lint (production profile), gitleaks
- Conventional commits: `feat/fix/refactor/docs(scope): message`
- No auto-push — always confirm before pushing to remotes

## Verification commands

```bash
# Ansible
ansible-lint .
molecule test                              # from inside a role dir

# Terraform
terraform validate && terraform fmt -check -recursive

# General
pre-commit run --all-files
```

## Constraints & gotchas

- OpenBao must be manually unsealed after every reboot (transit on 8201 first, then primary on 8200)
- Molecule uses `geerlingguy/docker-debian13-ansible:latest` — no `cache_valid_time` in converge.yml
- SSH is locked to a single IP — prefer MOTD for credential delivery
- Two git remotes: `origin` = Codeberg, `github` = GitHub
- Binary logging added to Ansible (`mariadb_log_bin_enabled: true`) but not yet applied to production

## Non-obvious decisions
<!-- Claude: update this section when you make non-obvious architectural decisions -->
- OpenBao transit (port 8201) runs as a separate instance to enable auto-unseal of primary (8200)
- Static secrets (MariaDB root, WP admin) stored in OpenBao KV; dynamic DB creds via database engine
- MariaDB binary logging deferred to next maintenance window (server live 50+ days, risk averse)
- `openbao-bootstrap.yml` seeds KV secrets only when `openbao_bootstrap_token` is defined (init run or token file).
  On re-runs against an already-initialized vault, pass `--extra-vars "openbao_admin_token=<token>"` to trigger seeding.
