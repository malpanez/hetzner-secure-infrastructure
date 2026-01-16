# Cloudflare Origin SSL Role

Deploys Cloudflare Origin Certificates for secure HTTPS communication between Cloudflare edge and your origin server.

## Why Cloudflare Origin Certificates?

- **Free**: No cost, valid for up to 15 years
- **Easy**: No renewal automation needed (unlike Let's Encrypt)
- **Secure**: Works with Cloudflare "Full (strict)" SSL mode
- **Simple**: Only trusted by Cloudflare (not browsers directly)

## Requirements

1. Domain proxied through Cloudflare (orange cloud)
2. Cloudflare account with access to SSL/TLS settings

## Quick Start

### 1. Generate Certificate in Cloudflare

1. Go to **Cloudflare Dashboard** → Your domain → **SSL/TLS** → **Origin Server**
2. Click **Create Certificate**
3. Choose:
   - **Private key type**: RSA (2048)
   - **Hostnames**: `yourdomain.com` and `*.yourdomain.com`
   - **Certificate validity**: 15 years (recommended)
4. Click **Create**
5. **IMPORTANT**: Copy both the certificate AND private key immediately (key is only shown once!)

### 2. Add to Ansible Vault

Edit your `secrets.yml`:

```yaml
vault_cloudflare_origin_cert: |
  -----BEGIN CERTIFICATE-----
  MIIEojCCA4qgAwIBAgIUY...
  (paste full certificate here)
  -----END CERTIFICATE-----

vault_cloudflare_origin_key: |
  -----BEGIN PRIVATE KEY-----
  MIIEvgIBADANBgkqhkiG...
  (paste full private key here)
  -----END PRIVATE KEY-----
```

### 3. Include Role in Playbook

```yaml
- hosts: wordpress_servers
  roles:
    - role: cloudflare_origin_ssl
    - role: nginx_wordpress
```

The `cloudflare_origin_ssl` role automatically sets:
- `nginx_wordpress_ssl_enabled: true`
- `nginx_wordpress_ssl_cert_path: /etc/ssl/cloudflare/origin.pem`
- `nginx_wordpress_ssl_key_path: /etc/ssl/cloudflare/origin.key`

### 4. Configure Cloudflare SSL Mode

In Cloudflare Dashboard → SSL/TLS → Overview:
- Set to **Full (strict)**

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `cloudflare_origin_ssl_enabled` | `true` | Enable/disable the role |
| `cloudflare_origin_ssl_cert_dir` | `/etc/ssl/cloudflare` | Directory for certificates |
| `cloudflare_origin_ssl_cert_path` | `{cert_dir}/origin.pem` | Certificate file path |
| `cloudflare_origin_ssl_key_path` | `{cert_dir}/origin.key` | Private key file path |
| `cloudflare_origin_ssl_nginx_reload` | `true` | Reload Nginx after deploying |

## Required Vault Variables

| Variable | Description |
|----------|-------------|
| `vault_cloudflare_origin_cert` | Full PEM certificate from Cloudflare |
| `vault_cloudflare_origin_key` | Private key (shown only once when creating!) |

## File Permissions

- Certificate: `0644` (readable by Nginx)
- Private key: `0600` (root only)
- Directory: `0755`

## Troubleshooting

### Error 521 (Web server is down)

Cloudflare can't connect to your origin. Check:
1. Nginx is running: `systemctl status nginx`
2. Port 443 is open: `ss -tlnp | grep 443`
3. Certificate is valid: `openssl x509 -in /etc/ssl/cloudflare/origin.pem -noout -dates`

### Error 526 (Invalid SSL certificate)

Certificate issue. Check:
1. Certificate matches your domain
2. Certificate hasn't expired
3. Full certificate chain is included

### SSL Handshake Failure

Verify certificate and key match:
```bash
openssl x509 -noout -modulus -in /etc/ssl/cloudflare/origin.pem | md5sum
openssl rsa -noout -modulus -in /etc/ssl/cloudflare/origin.key | md5sum
# Both should output the same hash
```

## Architecture

```
[User] → HTTPS → [Cloudflare Edge] → HTTPS → [Origin Server]
                  (Universal SSL)    (Origin Certificate)
```

- **Edge Certificate**: Cloudflare Universal SSL (automatic)
- **Origin Certificate**: This role deploys it

## Security Notes

- Origin certificates are ONLY trusted by Cloudflare
- Direct access to origin IP will show certificate warning (expected)
- Keep private key in Ansible Vault, never commit unencrypted
- Certificate can be revoked from Cloudflare Dashboard if compromised
