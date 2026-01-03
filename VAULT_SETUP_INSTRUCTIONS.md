# Ansible Vault Setup Instructions

**Date**: 2026-01-01
**Purpose**: Configure encrypted password storage for infrastructure
**Status**: ✅ VAULT CONFIGURED AND ENCRYPTED

---

## ✅ Completed Setup

The Ansible Vault has been successfully configured with the following:

1. **Vault File Created**: [ansible/inventory/group_vars/all/secrets.yml](ansible/inventory/group_vars/all/secrets.yml)
   - ✅ Encrypted with AES256
   - ✅ Contains all service passwords

2. **Vault Password**: Stored in `~/.ansible_vault_pass`
   - ✅ Vault password: `8ZpBU0IW4pWNKuXm4b7hQxF5e/jmfspQYzrSSLhuXu8=`
   - ⚠️ **IMPORTANT**: Save this password in your password manager

3. **Ansible Configuration**: [ansible/ansible.cfg](ansible/ansible.cfg)
   - ✅ Configured to use `~/.ansible_vault_pass` automatically
   - No need to use `--ask-vault-pass` anymore

4. **Variable References Updated**:
   - ✅ [ansible/inventory/group_vars/secrets_servers/openbao.yml](ansible/inventory/group_vars/secrets_servers/openbao.yml) - Added `openbao_mariadb_password`
   - ✅ All roles configured to reference vault variables

---

## Generated Passwords

Las siguientes contraseñas han sido generadas aleatoriamente (32 caracteres, alta entropía):

```yaml
---
# ========================================
# WordPress Passwords
# ========================================
vault_wordpress_admin_password: "nf0ZTtKYCd78NoY1EivkCT9Mi7aNrImR"
vault_wordpress_db_password: "2fr7Uce2V2ZEQP6PispswNsR6aJJigYj"

# ========================================
# MariaDB Passwords
# ========================================
vault_mariadb_root_password: "QA7gBLGdxFZg8m3J5C6s96hcZCuNpZ5l"
vault_mariadb_exporter_password: "vJMx7kQTtrabFtBwq4aWcYNWAwsi4HoG"
vault_openbao_mariadb_password: "ybAxmkmVYpKqxt1Yzw60SOEK6kvMmfaU"

# ========================================
# Grafana Passwords
# ========================================
vault_grafana_admin_password: "QiNzF3GvnyWp2URH3FXhKfiBt8CtR1vl"

# ========================================
# OpenBao Passwords
# ========================================
vault_openbao_admin_password: "tGUL57rBq85GQsDnHbtoRbonobe5Ld7H"
vault_openbao_wordpress_password: "vCzKkjZ11gDDcBA7uuHfBOTmrLmOfd43"
```

---

## Paso 1: Crear el Vault

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/ansible

# Crear el vault (te pedirá una contraseña para encriptar el vault)
ansible-vault create inventory/group_vars/all/secrets.yml
```

Cuando se abra el editor, pega el contenido de arriba (las contraseñas generadas).

**Contraseña del vault**: Elige una contraseña maestra segura (mínimo 16 caracteres)
- Guárdala en tu password manager
- Esta contraseña desencripta TODAS las contraseñas del vault
- **CRÍTICO**: Sin esta contraseña no podrás ejecutar playbooks

---

## Paso 2: Crear archivo de contraseña del vault (opcional)

Para no tener que escribir la contraseña cada vez:

```bash
# Crear archivo con la contraseña del vault
echo "TU_CONTRASEÑA_MAESTRA_AQUI" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Configurar ansible.cfg para usarlo
cat >> ansible.cfg << 'EOF'

[defaults]
vault_password_file = ~/.ansible_vault_pass
EOF
```

**Ventajas**: No necesitas `--ask-vault-pass` en cada comando
**Desventajas**: Contraseña en texto plano (asegúrate de tener el archivo protegido)

---

## Paso 3: Verificar el vault

```bash
# Ver contenido del vault
ansible-vault view inventory/group_vars/all/secrets.yml

# Editar el vault
ansible-vault edit inventory/group_vars/all/secrets.yml

# Cambiar contraseña del vault
ansible-vault rekey inventory/group_vars/all/secrets.yml
```

---

## Paso 4: Actualizar las contraseñas existentes

Ahora que tienes las contraseñas en el vault, necesitas actualizar las contraseñas actuales en los servicios:

### MariaDB Root Password

```bash
ssh -i ~/.ssh/github_ed25519 malpanez@46.224.156.140

# Cambiar contraseña de root de MariaDB
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'QA7gBLGdxFZg8m3J5C6s96hcZCuNpZ5l';"
```

### MariaDB WordPress Database Password

```bash
# Cambiar contraseña del usuario wordpress
sudo mysql -e "ALTER USER 'wordpress'@'localhost' IDENTIFIED BY '2fr7Uce2V2ZEQP6PispswNsR6aJJigYj';"

# Actualizar wp-config.php
sudo -u www-data wp --path=/var/www/wordpress config set DB_PASSWORD '2fr7Uce2V2ZEQP6PispswNsR6aJJigYj'
```

### MariaDB OpenBao User Password

```bash
# Cambiar contraseña del usuario openbao
sudo mysql -e "ALTER USER 'openbao'@'localhost' IDENTIFIED BY 'ybAxmkmVYpKqxt1Yzw60SOEK6kvMmfaU';"
```

### Grafana Admin Password

```bash
# Resetear contraseña de admin de Grafana
sudo grafana-cli admin reset-admin-password 'QiNzF3GvnyWp2URH3FXhKfiBt8CtR1vl'
```

---

## Paso 5: Ejecutar playbook con vault

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/ansible

# Con contraseña del vault en archivo
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml

# Sin archivo de contraseña (pedirá contraseña)
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml --ask-vault-pass
```

---

## Resumen de Contraseñas Generadas

| Servicio | Usuario | Contraseña | Variable |
|----------|---------|------------|----------|
| WordPress Admin | admin | `nf0ZTtKYCd78NoY1EivkCT9Mi7aNrImR` | `vault_wordpress_admin_password` |
| WordPress DB | wordpress | `2fr7Uce2V2ZEQP6PispswNsR6aJJigYj` | `vault_wordpress_db_password` |
| MariaDB Root | root | `QA7gBLGdxFZg8m3J5C6s96hcZCuNpZ5l` | `vault_mariadb_root_password` |
| MariaDB Exporter | exporter | `vJMx7kQTtrabFtBwq4aWcYNWAwsi4HoG` | `vault_mariadb_exporter_password` |
| MariaDB OpenBao | openbao | `ybAxmkmVYpKqxt1Yzw60SOEK6kvMmfaU` | `vault_openbao_mariadb_password` |
| Grafana Admin | admin | `QiNzF3GvnyWp2URH3FXhKfiBt8CtR1vl` | `vault_grafana_admin_password` |
| OpenBao Admin | admin | `tGUL57rBq85GQsDnHbtoRbonobe5Ld7H` | `vault_openbao_admin_password` |
| OpenBao WordPress | wordpress | `vCzKkjZ11gDDcBA7uuHfBOTmrLmOfd43` | `vault_openbao_wordpress_password` |

---

## URLs de Acceso

| Servicio | URL | Usuario | Contraseña |
|----------|-----|---------|------------|
| WordPress Admin | http://46.224.156.140/wp-admin | admin | `nf0ZTtKYCd78NoY1EivkCT9Mi7aNrImR` |
| Grafana | http://46.224.156.140:3000 | admin | `QiNzF3GvnyWp2URH3FXhKfiBt8CtR1vl` |

---

## Seguridad

### ✅ Buenas Prácticas

1. **Vault password en password manager** - No la pierdas
2. **No commitear secrets.yml sin encriptar** - Siempre usa `ansible-vault`
3. **Rotar contraseñas regularmente** - Cada 90 días mínimo
4. **Backup del vault** - Guarda copia segura del archivo encriptado
5. **Limitar acceso** - Solo personas autorizadas deben tener la contraseña del vault

### ⚠️ Qué NO hacer

1. ❌ No guardes la contraseña del vault en Git
2. ❌ No uses la misma contraseña para todos los servicios
3. ❌ No compartas la contraseña del vault por email/Slack
4. ❌ No desencriptes el vault y lo dejes sin encriptar
5. ❌ No uses contraseñas débiles tipo "admin123"

---

## Troubleshooting

### Error: "Decryption failed"

**Causa**: Contraseña del vault incorrecta

**Solución**: Verifica que estás usando la contraseña correcta del vault

### Error: "No vault password file found"

**Causa**: No configuraste el archivo de contraseña

**Solución**: Usa `--ask-vault-pass` o crea el archivo `~/.ansible_vault_pass`

### Olvidé la contraseña del vault

**Solución**:
1. Si tienes backup: Restaura el backup
2. Si no: Necesitas recrear el vault con nuevas contraseñas
3. Tendrás que actualizar todas las contraseñas en los servicios

---

**Importante**: Después de crear el vault, elimina este archivo (`VAULT_SETUP_INSTRUCTIONS.md`) ya que contiene las contraseñas en texto plano.

```bash
# Después de configurar el vault, elimina este archivo
rm /home/malpanez/repos/hetzner-secure-infrastructure/VAULT_SETUP_INSTRUCTIONS.md
```
