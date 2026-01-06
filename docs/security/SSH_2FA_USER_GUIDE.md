# SSH 2FA - Guía de Usuario y Configuración

## Resumen de Configuración

El sistema SSH está configurado con **autenticación de 2 factores (2FA) opcional** usando Google Authenticator, con bypass para usuarios y grupos específicos.

---

## Cómo Funciona la Autenticación

### Tipos de Usuarios

#### 1. Usuarios Break-glass (Sin 2FA) ⭐

**Quién**: Usuario `malpanez` (administrador principal)

**Autenticación**: Solo SSH key (sin 2FA)

**Configuración**:

```yaml
# ansible/roles/ssh_2fa/defaults/main.yml
ssh_2fa_break_glass_users:
  - malpanez
```

**Match block SSH generado**:

```
Match User malpanez
    AuthenticationMethods publickey
    PermitTTY yes
    AllowTcpForwarding yes
```

**Uso**:

```bash
# Conectar desde tu máquina
ssh -i ~/.ssh/github_ed25519 malpanez@<SERVER_IP>

# Desde Ansible
ansible-playbook playbooks/site.yml
# Usa automáticamente: user=malpanez + key=~/.ssh/github_ed25519
```

---

#### 2. Grupo ansible-automation (Sin 2FA)

**Quién**: Usuarios miembros del grupo `ansible-automation`

**Autenticación**: Solo SSH key (sin 2FA)

**Miembros automáticos**:

- Usuario `malpanez` (agregado automáticamente por role common)

**Match block SSH generado**:

```
Match Group ansible-automation
    AuthenticationMethods publickey
    PermitTTY yes
    AllowTcpForwarding yes
```

**Por qué**: Permite que Ansible y otras herramientas de automatización se conecten sin interacción manual.

---

#### 3. Usuarios normales (CON 2FA)

**Quién**: Cualquier otro usuario que no esté en break-glass ni en ansible-automation

**Autenticación**: SSH key + Google Authenticator (2FA)

**Match block SSH generado**:

```
Match All
    AuthenticationMethods publickey,keyboard-interactive
```

**Flujo de login**:

1. SSH key verificada
2. Prompt: "Verification code:" → Ingresar código de Google Authenticator
3. Acceso concedido

---

## Tu Configuración Actual (Usuario malpanez)

### ✅ Protección contra Lockout

Tienes **DOBLE protección** para evitar bloquearte:

1. **Match User malpanez** → SSH key only (sin 2FA)
2. **Match Group ansible-automation** → SSH key only (sin 2FA)

Si por alguna razón el Match User falla, el Match Group te cubrirá.

### ✅ Verificación de Configuración

Después del deployment, puedes verificar:

```bash
# Conectar SSH como siempre (sin 2FA)
ssh -i ~/.ssh/github_ed25519 malpanez@<SERVER_IP>

# Verificar que estás en el grupo ansible-automation
id malpanez
# Output esperado: uid=1000(malpanez) gid=1000(malpanez) groups=...,ansible-automation,...

# Ver configuración SSH activa
sudo sshd -T | grep -i authenticationmethods
# Output esperado: diferentes authenticationmethods por Match block

# Ver configuración SSH completa para tu usuario
sudo sshd -T -C user=malpanez | grep authenticationmethods
# Output esperado: authenticationmethods publickey
```

---

## Deployment Seguro

### Paso 1: Deploy Terraform

```bash
cd terraform
terraform apply
# Toma nota de la IP del servidor
```

### Paso 2: Deploy Ansible como root (Primera vez)

```bash
cd ../ansible
export HCLOUD_TOKEN="your-token"

# Primera conexión es como ROOT (creará usuario malpanez)
./deploy.sh -u root playbooks/site.yml
```

**Qué pasa durante este deploy**:

1. ✅ Crea usuario `malpanez`
2. ✅ Agrega `malpanez` a grupo `sudo`
3. ✅ Agrega `malpanez` a grupo `ansible-automation`
4. ✅ Copia tu SSH key a `/home/malpanez/.ssh/authorized_keys`
5. ✅ Configura SSH con Match blocks
6. ✅ **Root puede seguir conectándose** (permit-root-login con key)

### Paso 3: Verificar acceso como malpanez

```bash
# Probar conexión SSH como malpanez (SIN 2FA)
ssh -i ~/.ssh/github_ed25519 malpanez@<SERVER_IP>

# Si funciona → Perfecto, estás seguro
# Si falla → Usa root como backup
```

### Paso 4 (Opcional): Deployments subsiguientes

```bash
# Ahora puedes usar malpanez (ya configurado en ansible.cfg)
cd ansible
./deploy.sh playbooks/site.yml

# ansible.cfg tiene:
# remote_user = malpanez
# private_key_file = ~/.ssh/github_ed25519
```

---

## Configurar 2FA para Otros Usuarios (Futuro)

Si en el futuro quieres agregar otros usuarios CON 2FA:

### 1. Crear usuario (sin break-glass)

```yaml
# En tu playbook o inventario
new_users:
  - name: developer1
    groups:
      - sudo
    # NO agregarlo a ansible-automation
    # NO agregarlo a break-glass
```

### 2. Usuario configura Google Authenticator

```bash
# Como el nuevo usuario en el servidor
ssh developer1@<SERVER_IP>

# Configurar Google Authenticator
google-authenticator

# Responde:
# Do you want authentication tokens to be time-based (y/n) → y
# [Escanea QR code con app Google Authenticator]
# Do you want me to update your "~/.google_authenticator" file? → y
# Do you want to disallow multiple uses of the same token? → y
# Increase window of counter? → n
# Rate limiting? → y
```

### 3. Probar login con 2FA

```bash
# Desde tu máquina
ssh developer1@<SERVER_IP>

# Output:
# (user@<SERVER_IP>) Verification code: [ingresar código de app]
```

---

## Configuración de Google Authenticator (PAM)

### Opción `nullok` (Actualmente HABILITADA)

```yaml
# ansible/roles/ssh_2fa/defaults/main.yml
ssh_2fa_pam_google_authenticator_ssh_options: "nullok forward_pass"
```

**Qué significa `nullok`**:

- Usuarios SIN `~/.google_authenticator` configurado → Pueden entrar solo con SSH key
- Usuarios CON `~/.google_authenticator` configurado → Requieren SSH key + 2FA

**Por qué está habilitado**:

- Previene lockout durante setup inicial
- Permite deployment gradual de 2FA por usuario
- Usuarios break-glass (malpanez) no lo necesitan de todas formas

**Para producción estricta** (futuro):

```yaml
# Cambiar a:
ssh_2fa_pam_google_authenticator_ssh_options: "forward_pass"
# Elimina nullok → Requiere 2FA obligatorio para Match All
```

---

## Orden de Procesamiento de Match Blocks

SSH procesa Match blocks **en orden de arriba hacia abajo** y usa el **PRIMERO que coincida**.

**Orden actual** (correcto):

```
1. Match User malpanez          ← Procesa PRIMERO
2. Match Group ansible-automation
3. Match All                     ← Procesa ÚLTIMO (default)
```

**Por qué importa**:

- Si `Match All` estuviera primero, atraparía TODOS los usuarios (incluido malpanez)
- El orden específico→general es crítico

**Verificación**:

```bash
# Ver orden en archivo generado
ssh -i ~/.ssh/github_ed25519 malpanez@<SERVER_IP>
sudo cat /etc/ssh/sshd_config.d/50-2fa.conf
```

---

## Troubleshooting

### Problema: No puedo conectarme como malpanez

**Diagnóstico**:

```bash
# Ver logs SSH en el servidor (necesitas Hetzner Console)
sudo tail -f /var/log/auth.log

# Mientras tanto, intenta SSH desde tu máquina
ssh -vvv -i ~/.ssh/github_ed25519 malpanez@<SERVER_IP>
```

**Soluciones**:

1. **Usar root como backup**:

   ```bash
   ssh -i ~/.ssh/github_ed25519 root@<SERVER_IP>
   ```

2. **Verificar configuración SSH**:

   ```bash
   sudo sshd -T -C user=malpanez | grep authenticationmethods
   # Debe mostrar: authenticationmethods publickey
   ```

3. **Verificar grupo ansible-automation**:

   ```bash
   id malpanez
   # Debe listar: ansible-automation
   ```

4. **Verificar SSH key**:

   ```bash
   sudo cat /home/malpanez/.ssh/authorized_keys
   # Debe contener tu public key
   ```

---

### Problema: Me pide 2FA cuando no debería

**Causa**: Match User o Match Group no está funcionando

**Diagnóstico**:

```bash
# Ver qué Match block se está usando
sudo sshd -T -C user=malpanez | grep -A 5 -B 5 authenticationmethods
```

**Solución**:

```bash
# Verificar archivo de configuración generado
sudo cat /etc/ssh/sshd_config.d/50-2fa.conf

# Debe contener:
# Match User malpanez
#     AuthenticationMethods publickey
```

Si falta, volver a ejecutar Ansible:

```bash
cd ansible
./deploy.sh -u root playbooks/site.yml --tags ssh-2fa
```

---

### Problema: Ansible no puede conectar

**Error típico**: `Permission denied (publickey,keyboard-interactive)`

**Causa**: Ansible está usando usuario incorrecto o key incorrecta

**Solución**:

```bash
# Verificar ansible.cfg
cat ansible/ansible.cfg | grep -E "(remote_user|private_key)"

# Debe mostrar:
# remote_user = malpanez
# private_key_file = ~/.ssh/github_ed25519

# Verificar que la key existe
ls -la ~/.ssh/github_ed25519

# Probar conexión manual primero
ssh -i ~/.ssh/github_ed25519 malpanez@<SERVER_IP>
```

---

## Seguridad - Mejores Prácticas

### ✅ Estado Actual (Seguro)

- ✅ Root login permitido SOLO con SSH key (no password)
- ✅ Passwords SSH deshabilitados globalmente
- ✅ Admin (malpanez) puede conectar sin 2FA (necesario para automatización)
- ✅ Usuarios normales requerirán 2FA cuando se agreguen
- ✅ AppArmor en complain mode (no bloquea, solo logea)
- ✅ UFW firewall activo
- ✅ Fail2ban monitoreando intentos fallidos

### 🎯 Mejoras Futuras (Opcional)

1. **Deshabilitar root SSH completamente**:

   ```yaml
   # ansible/roles/ssh_2fa/defaults/main.yml
   ssh_2fa_permit_root_login: "no"
   ```

   ⚠️ Solo después de verificar que malpanez funciona perfecto

2. **Remover malpanez de break-glass**:

   ```yaml
   ssh_2fa_break_glass_users: []
   ```

   ⚠️ Solo después de configurar Google Authenticator para malpanez

3. **Eliminar `nullok` de PAM**:

   ```yaml
   ssh_2fa_pam_google_authenticator_ssh_options: "forward_pass"
   ```

   ⚠️ Solo cuando TODOS los usuarios tengan 2FA configurado

4. **AppArmor a enforce mode**:

   ```yaml
   # ansible/roles/apparmor/defaults/main.yml
   apparmor_enforce_mode: true
   ```

   ⚠️ Solo después de revisar logs en complain mode

---

## Resumen Ejecutivo

### Para Mañana (Deployment)

1. ✅ Terraform apply (crea servidor)
2. ✅ `./deploy.sh -u root playbooks/site.yml` (primera vez como root)
3. ✅ Probar SSH: `ssh -i ~/.ssh/github_ed25519 malpanez@<SERVER_IP>`
4. ✅ Deployments futuros: `./deploy.sh playbooks/site.yml` (ya usa malpanez)

### Tu Configuración SSH

- **Usuario**: malpanez
- **Autenticación**: Solo SSH key (SIN 2FA)
- **Razón**: Estás en `break-glass users` Y en grupo `ansible-automation`
- **Riesgo de lockout**: CERO (doble protección)

### Backups de Acceso

Si algo falla:

1. SSH como root: `ssh -i ~/.ssh/github_ed25519 root@<SERVER_IP>`
2. Hetzner Cloud Console (siempre disponible)

### Configuración de 2FA

- **Ahora**: NO necesitas configurar Google Authenticator
- **Futuro**: Si quieres 2FA para ti, ejecuta `google-authenticator` en el servidor
- **Otros usuarios**: Requerirán 2FA por defecto (Match All)

---

## Referencias

- Google Authenticator PAM: <https://github.com/google/google-authenticator-libpam>
- OpenSSH Match blocks: `man sshd_config` (sección PATTERNS)
- Configuración actual: [ansible/roles/ssh_2fa/templates/sshd_2fa.conf.j2](../../ansible/roles/ssh_2fa/templates/sshd_2fa.conf.j2)
