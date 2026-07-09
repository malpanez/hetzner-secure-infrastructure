# ansible-role-nginx

A generic, application-agnostic Ansible role for installing, configuring, and
hardening nginx as a web server. This role has zero application awareness: it
does not know or care what it is serving (a static site, a dynamic
application, an API backend, anything). Application-specific hosting
concerns (vhosts, backend application-runtime pools, cache paths,
per-application security snippets) belong in a consumer role that depends on
this one.

## Purpose

This role covers the full lifecycle of an nginx installation:

- **Install** — nginx itself via the nginx.org official repository, with an
  automatic fallback to the distribution's own package if the official repo
  is unavailable or unreachable, plus `certbot` and the Cloudflare DNS plugin
  for certificate issuance.
- **TLS / Let's Encrypt** — DNS-01 challenge via Cloudflare, disabled by
  default (`nginx_letsencrypt_enabled: false`). Most deployments terminate
  TLS with a Cloudflare Origin CA certificate instead and never need this
  path; it exists for hosts that are not behind Cloudflare or need a
  standalone public certificate.
- **Hardening drop-ins** (`conf.d/`) — global, `http{}`-scope directives
  applied regardless of which vhost(s) a consumer role adds on top:
  - `cloudflare-real-ip.conf` — trusts `CF-Connecting-IP` only from
    Cloudflare's published IP ranges.
  - `rate-limits.conf` — `limit_req_zone` definitions (login/api/general);
    zones are declared here, applied by the consuming vhost.
  - `security-headers.conf` — CSP, X-Frame-Options, X-Content-Type-Options,
    Referrer-Policy, Permissions-Policy response headers.
  - `logging.conf` — structured/JSON access log format.
  - `stub-status.conf` — `nginx_status` endpoint bound to `127.0.0.1:8080`
    for local metrics scraping only.
- **Reusable snippets** (`snippets/`) — `include`-able fragments with no
  application content: `ssl-params.conf` (TLS 1.2/1.3, Mozilla-modern cipher
  list), `gzip-params.conf`, and `static-assets.conf` (baseline
  image/CSS/JS/font caching rules).
- **systemd startup self-heal** — a systemd drop-in that hardens
  `nginx.service` restart/backoff behavior at the unit level, independent of
  anything served.

Nothing in this role references a specific application, framework, or
business. It is intended to be reusable across any host that needs nginx.

## Variable Surface

### Feature toggles (`defaults/`)

| Variable | Default | Purpose |
|---|---|---|
| `nginx_enabled` | `true` | Master switch for the whole role. |
| `nginx_install_nginx` | `true` | Install/manage the nginx package and service. |
| `nginx_cloudflare_enabled` | `true` | Deploy the Cloudflare real-IP trust drop-in. |
| `nginx_enable_rate_limiting` | `true` | Deploy the `limit_req_zone` drop-in. |
| `nginx_enable_security_headers` | `true` | Deploy the security-headers drop-in. |
| `nginx_enable_json_logging` | `true` | Deploy the structured/JSON logging drop-in. |
| `nginx_enable_stub_status` | `true` | Deploy the local-only `nginx_status` endpoint. |
| `nginx_systemd_selfheal_enabled` | `true` | Deploy the systemd startup self-heal drop-in. |

### Extension points

The `security-headers` and `static-assets` drop-ins are the two places where
a consumer role most commonly needs to inject application-specific values
(a CDN domain in the CSP, a set of file extensions that need hotlink
protection, and so on) without touching this role. Each extension point
defaults to empty/disabled, so an unconfigured consumer gets a strict,
minimal baseline:

| Variable | Default | Purpose |
|---|---|---|
| `nginx_security_headers_csp_script_src_extra` | `[]` | Extra `script-src` origins appended to the Content-Security-Policy `map` block. |
| `nginx_security_headers_csp_style_src_extra` | `[]` | Extra `style-src` origins appended to the CSP. |
| `nginx_security_headers_csp_font_src_extra` | `[]` | Extra `font-src` origins appended to the CSP. |
| `nginx_security_headers_csp_connect_src_extra` | `[]` | Extra `connect-src` origins appended to the CSP. |
| `nginx_static_assets_hotlink_protection_enabled` | `false` | Enables a `valid_referers`-gated location block for the extensions/referers below. |
| `nginx_static_assets_hotlink_extensions` | `[]` | File extensions (e.g. media/document types) covered by hotlink protection when enabled. |
| `nginx_static_assets_hotlink_referers` | `[]` | Allowed referer hostnames for the hotlink-protected extensions. |

A consumer role (for example, an application-hosting role built on top of
this one) sets these to reproduce its own application's exact CSP/hotlink
requirements without this role ever needing to know what those requirements
are.

## Consumed Directory Facts

Downstream/consumer roles that add their own vhosts, snippets, or cache
configuration on top of this role should reference these facts rather than
hardcoding filesystem paths:

| Variable | Default | Purpose |
|---|---|---|
| `nginx_service` | `nginx` | systemd unit name, used by both handlers (`reload nginx`, `restart nginx`). |
| `nginx_config_dir` | `/etc/nginx` | Root nginx configuration directory. |
| `nginx_sites_available` | `/etc/nginx/sites-available` | Where a consumer role should render its own vhost templates. |
| `nginx_sites_enabled` | `/etc/nginx/sites-enabled` | Where a consumer role should symlink its enabled vhosts. |
| `nginx_snippets_dir` | `/etc/nginx/snippets` | Where a consumer role can add its own reusable `include` fragments alongside `ssl-params.conf`/`gzip-params.conf`/`static-assets.conf`. |

This role manages the directories and the base configuration inside them; it
does not manage per-application vhost enablement or symlinks — that is a
consumer-role concern.

## Handlers

| Handler | Action |
|---|---|
| `reload nginx` | `systemd` reload of `{{ nginx_service }}` — used after any config/drop-in/snippet change. |
| `restart nginx` | `systemd` restart of `{{ nginx_service }}` — used only when a full restart is required (e.g. after a binary upgrade). |

No backend application-runtime handlers live here; those belong to whichever
consumer role manages that application.

## Testing

This role ships a Molecule scenario (`molecule/default/`) that converges the
role standalone, with **no** database or application variables set at all.
That absence is itself a smoke test: if the converge fails without them,
something application-specific has leaked into this role.

```bash
cd ansible/roles/nginx
molecule test
```

The scenario uses a digest-pinned `geerlingguy/docker-debian13-ansible`
systemd container and verifies: the nginx package is installed, the service
is enabled and running, `nginx -t` passes, and the server is listening on
port 80.
