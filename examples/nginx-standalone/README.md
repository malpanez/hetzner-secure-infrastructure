# nginx Standalone Example

This example demonstrates applying the `nginx` role by itself, with no
consumer role on top.

## What This Example Shows

- The minimal invocation needed to install and harden nginx: `roles: [nginx]`,
  nothing else.
- The role alone creates **no vhost**. Once converged, nginx serves its
  package-default page on port 80 — vhosts, backend application pools, and
  app-specific cache paths are a consumer role's concern, not this role's.
- The hardening drop-ins (Cloudflare real-IP trust, rate-limit zones, security
  headers, JSON logging, a local-only `stub_status` endpoint) and reusable
  snippets (TLS params, gzip, static-asset caching) are all applied regardless
  of what a consumer role serves.

## Prerequisites

- A Debian 13 host reachable over SSH with a sudo-capable user
- [ansible-core](https://docs.ansible.com/) >= 2.15

## Usage

### 1. Copy and edit the inventory

```bash
cd examples/nginx-standalone
cp inventory.example.yml inventory.yml
# edit inventory.yml: replace the placeholder host/IP with your own
```

### 2. Review the playbook

`playbook.yml` applies the role with its defaults. Uncomment and adjust the
`vars:` block only if you need to override an extension point (see below).

### 3. Run it

This example lives outside `ansible/roles/`, so Ansible's default role search
path won't find `nginx` on its own — point `ANSIBLE_ROLES_PATH` at the repo's
roles directory (relative to the repo root):

```bash
ANSIBLE_ROLES_PATH=../../ansible/roles ansible-playbook -i inventory.yml playbook.yml
```

## Customization

The full variable surface — feature toggles, extension points (CSP
`script-src`/`style-src`/`font-src`/`connect-src` extras, hotlink protection),
and the directory facts a consumer role should reference — is documented in
the role's own README:

[`../../ansible/roles/nginx/README.md`](../../ansible/roles/nginx/README.md)

## Cleanup

This example makes no infrastructure-provisioning changes (no VPS is created
here — pair it with the `basic-server` Terraform example if you need one).
To remove nginx itself, revert the converge manually or rebuild the host.
