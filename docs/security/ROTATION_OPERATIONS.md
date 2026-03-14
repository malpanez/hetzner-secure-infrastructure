# Secret Rotation — Operations Guide

**What this covers**: How to set up and operate the monthly password rotation for
MariaDB root and WordPress admin passwords.

---

## How it works (big picture)

Every 1st of the month at 02:00, the server automatically:

1. Generates a new MariaDB root password
2. Generates a new WordPress admin password
3. Stores both new passwords in OpenBao
4. Leaves a notice on the SSH login screen (MOTD)

You do not need to do anything unless you need to log in to WordPress or MySQL as root.

---

## One-time setup (do this once after deploying the playbook)

### Step 1 — Run the playbook

```bash
ansible-playbook -i ansible/inventory/hetzner.hcloud.yml \
  ansible/playbooks/setup-openbao-rotation.yml
```

### Step 2 — SSH into the server

```bash
ssh -i ~/.ssh/github_ed25519 your-username@YOUR_SERVER_IP
```

### Step 3 — Log in to OpenBao

```bash
export VAULT_ADDR=http://127.0.0.1:8200
bao login -method=userpass username=admin
# Enter your OpenBao admin password when prompted
```

### Step 4 — Create the MariaDB rotator policy

Copy and paste this block exactly:

```bash
bao policy write mariadb-rotator - <<'EOF'
path "secret/data/mariadb"   { capabilities = ["read", "create", "update"] }
path "auth/token/renew-self" { capabilities = ["update"] }
EOF
```

Expected output: `Success! Uploaded policy: mariadb-rotator`

### Step 5 — Update the WordPress rotator policy

Copy and paste this block exactly:

```bash
bao policy write wordpress-rotator - <<'EOF'
path "database/creds/wordpress" { capabilities = ["read"] }
path "secret/data/wordpress"    { capabilities = ["create", "update"] }
path "auth/token/renew-self"    { capabilities = ["update"] }
EOF
```

Expected output: `Success! Uploaded policy: wordpress-rotator`

### Step 6 — Create the MariaDB rotator token

```bash
bao token create -orphan -period=2160h -policy=mariadb-rotator -format=json \
  | jq -r '.auth.client_token' | tee /root/.openbao-mariadb-token
chmod 600 /root/.openbao-mariadb-token
```

Expected output: a long token string starting with `hvs.` or `bao.`

### Step 7 — Store the current WordPress admin password in OpenBao

Replace `YOUR_CURRENT_WP_ADMIN_PASSWORD` with the actual password:

```bash
bao kv patch secret/wordpress admin_password='YOUR_CURRENT_WP_ADMIN_PASSWORD'
```

Expected output: `Success! Data written to: secret/wordpress`

### Step 8 — Verify everything works

Test MariaDB rotation (non-destructive, you can run this safely):

```bash
sudo /usr/local/bin/rotate-mariadb-root.sh
```

Test WordPress admin rotation:

```bash
sudo /usr/local/bin/rotate-wp-admin.sh
```

Check the MOTD notice appeared:

```bash
cat /etc/motd.d/90-rotation-notice
```

Check the timer is scheduled:

```bash
systemctl list-timers monthly-secret-rotate.timer
```

---

## Monthly cycle (what happens automatically)

You do not need to do anything. On the 1st of each month:

- Both passwords are rotated automatically at 02:00
- A notice appears on your SSH login screen

---

## When you need a password

### Get the WordPress admin password

```bash
export VAULT_ADDR=http://127.0.0.1:8200
bao login -method=userpass username=admin
bao kv get -field=admin_password secret/wordpress
```

### Get the MariaDB root password

```bash
export VAULT_ADDR=http://127.0.0.1:8200
bao login -method=userpass username=admin
bao kv get -field=root_password secret/mariadb
```

---

## When you see the rotation notice on SSH login

You will see something like:

```
=================================================================
  SECRET ROTATION NOTICE
=================================================================
  Last rotation : 2026-04-01 02:05:00

  Retrieve current credentials:
    MariaDB root : bao kv get -field=root_password secret/mariadb
    WP admin     : bao kv get -field=admin_password secret/wordpress

  Dismiss: rm /etc/motd.d/90-rotation-notice
=================================================================
```

To dismiss it after reading:

```bash
rm /etc/motd.d/90-rotation-notice
```

---

## Rotation log files

If something goes wrong, check these files on the server:

| Script | Log file |
|--------|----------|
| MariaDB root rotation | `/var/log/mariadb-root-rotation.log` |
| WordPress admin rotation | `/var/log/wp-admin-rotation.log` |
| WordPress DB rotation (daily) | `/var/log/wordpress-secret-rotation.log` |
