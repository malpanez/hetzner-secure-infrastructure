# SSH Key Strategy - Recomendaciones de Seguridad

## 🎯 Estrategia Recomendada

### Para Servidores de Producción: **Yubikey (FIDO2)** 🔐

**Key actual**: `~/.ssh/id_ed25519_sk`

```bash
# Para Hetzner, AWS, servidores críticos
Host hetzner-* *.homelabforge.dev
    IdentityFile ~/.ssh/id_ed25519_sk
    IdentitiesOnly yes
```

**Ventajas**:

- ✅ Requiere touch físico (no pueden SSH sin Yubikey)
- ✅ Protección contra robo de laptop
- ✅ Protección contra malware/keyloggers
- ✅ Auditoría física visible (LED parpadea)
- ✅ Ideal para producción/staging

**Usa para**:

- Hetzner Cloud servers (producción y staging)
- AWS/GCP servers críticos
- Bastion hosts
- Jump boxes
- Servidores con datos sensibles

---

### Para Desarrollo/Git: **Clave normal con passphrase** 🔑

**Crear nueva** (si no la tienes):

```bash
# Generar clave Ed25519 normal (más rápida que RSA)
ssh-keygen -t ed25519 -C "miguel@dev-workstation"

# Guardar en: ~/.ssh/id_ed25519 (default)
# Passphrase: SÍ, usa una (puedes usar ssh-agent después)
```

**Configuración**:

```bash
# Para GitHub, GitLab, Bitbucket
Host github.com gitlab.com bitbucket.org
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
    UseKeychain yes  # macOS only
```

**Ventajas**:

- ✅ No requiere touch físico para cada git push
- ✅ Compatible con ssh-agent (desbloqueas una vez)
- ✅ Funciona en CI/CD pipelines
- ✅ Más rápido para operaciones frecuentes

**Usa para**:

- GitHub/GitLab/Bitbucket
- git push/pull frecuentes
- Desarrollo local (docker, vagrant)
- Scripts automatizados
- Pre-commit hooks

---

## 📋 Configuración SSH Config Completa

### Archivo: `~/.ssh/config`

```bash
# ========================================
# Configuración Global
# ========================================
Host *
    AddKeysToAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes

# ========================================
# Servicios de Git (clave normal)
# ========================================
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

# ========================================
# Hetzner Cloud (Yubikey FIDO2)
# ========================================
Host hetzner-* staging-* prod-*
    IdentityFile ~/.ssh/id_ed25519_sk
    IdentitiesOnly yes
    User miguel

# Staging WordPress
Host staging-wordpress
    HostName %h  # Se resuelve dinámicamente por Terraform
    IdentityFile ~/.ssh/id_ed25519_sk
    User miguel

# Producción WordPress
Host prod-wordpress
    HostName %h
    IdentityFile ~/.ssh/id_ed25519_sk
    User miguel

# ========================================
# Servidores por IP (Yubikey)
# ========================================
Host 95.217.* 135.181.* 159.69.*  # Rangos de Hetzner
    IdentityFile ~/.ssh/id_ed25519_sk
    User miguel

# ========================================
# Desarrollo Local (clave normal)
# ========================================
Host localhost 127.0.0.1
    IdentityFile ~/.ssh/id_ed25519
    User vagrant
    StrictHostKeyChecking no  # Solo para localhost
    UserKnownHostsFile /dev/null

# Docker containers
Host docker-*
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# ========================================
# Bastion/Jump Host (Yubikey)
# ========================================
Host bastion
    HostName bastion.homelabforge.dev
    IdentityFile ~/.ssh/id_ed25519_sk
    User miguel
    ForwardAgent no  # Seguridad: no forwarding en bastion

# Servidores via bastion
Host *.internal
    ProxyJump bastion
    IdentityFile ~/.ssh/id_ed25519_sk
    User miguel
```

---

## 🔧 Setup Paso a Paso

### 1. Crear clave normal para Git (si no la tienes)

```bash
# Generar
ssh-keygen -t ed25519 -C "miguel@dev-workstation"

# Ubicación: ~/.ssh/id_ed25519 (default)
# Passphrase: Usa una segura

# Ver clave pública
cat ~/.ssh/id_ed25519.pub
```

### 2. Añadir a GitHub/GitLab

```bash
# Copiar clave
cat ~/.ssh/id_ed25519.pub | clip.exe  # WSL2
# O manualmente:
cat ~/.ssh/id_ed25519.pub

# GitHub: Settings → SSH and GPG keys → New SSH key
# GitLab: Preferences → SSH Keys → Add new key
```

### 3. Configurar ssh-agent (para no escribir passphrase siempre)

```bash
# Iniciar ssh-agent
eval $(ssh-agent -s)

# Añadir clave normal (con passphrase)
ssh-add ~/.ssh/id_ed25519

# NO añadir Yubikey a agent (queremos touch cada vez)
# ssh-add -K ~/.ssh/id_ed25519_sk  # ❌ NO HACER ESTO

# Verificar
ssh-add -l
```

### 4. Crear/actualizar ~/.ssh/config

```bash
# Backup actual
cp ~/.ssh/config ~/.ssh/config.backup 2>/dev/null || true

# Crear nuevo (usa contenido de arriba)
nano ~/.ssh/config
```

### 5. Permisos correctos

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519_sk
chmod 644 ~/.ssh/id_ed25519.pub
chmod 644 ~/.ssh/id_ed25519_sk.pub
chmod 600 ~/.ssh/config
```

---

## 🧪 Probar Configuración

### GitHub (debe usar clave normal)

```bash
ssh -T git@github.com
# Debe conectar SIN pedir touch de Yubikey
# Output esperado: "Hi username! You've successfully authenticated..."
```

### Hetzner (debe usar Yubikey)

```bash
# Después de desplegar con Terraform
ssh miguel@95.217.XXX.XXX
# Debe pedir touch en Yubikey (LED parpadea)
```

### Verificar qué clave usa

```bash
# Ver qué clave SSH usará
ssh -v git@github.com 2>&1 | grep "Offering public key"
# Debe mostrar: ~/.ssh/id_ed25519

ssh -v miguel@95.217.XXX.XXX 2>&1 | grep "Offering public key"
# Debe mostrar: ~/.ssh/id_ed25519_sk
```

---

## 🔒 Matriz de Seguridad

| Uso | Clave | Passphrase | ssh-agent | Touch Físico |
|-----|-------|-----------|-----------|--------------|
| **Hetzner Prod** | `id_ed25519_sk` | N/A | ❌ NO | ✅ Sí |
| **Hetzner Staging** | `id_ed25519_sk` | N/A | ❌ NO | ✅ Sí |
| **GitHub push** | `id_ed25519` | ✅ Sí | ✅ Sí | ❌ No |
| **GitLab push** | `id_ed25519` | ✅ Sí | ✅ Sí | ❌ No |
| **Vagrant local** | `id_ed25519` | Opcional | ✅ Sí | ❌ No |
| **Docker local** | `id_ed25519` | Opcional | ✅ Sí | ❌ No |
| **Bastion host** | `id_ed25519_sk` | N/A | ❌ NO | ✅ Sí |

---

## ⚠️ Reglas de Seguridad

### ✅ HACER

1. **Yubikey para producción**: Siempre usa FIDO2 para servidores críticos
2. **Passphrase en clave normal**: Protección si roban el archivo
3. **ssh-agent con timeout**: `ssh-add -t 3600` (1 hora)
4. **Different keys for different purposes**: Una para git, otra para servers
5. **Backup de claves**: Guarda `~/.ssh/id_ed25519` cifrado en lugar seguro
6. **Yubikey backup**: Compra segunda Yubikey con misma clave

### ❌ NO HACER

1. **No uses Yubikey para git**: Demasiados touches por día
2. **No uses clave normal para producción**: Sin protección física
3. **No añadas Yubikey a ssh-agent**: Anula el propósito del touch
4. **No compartas claves privadas**: Nunca, jamás
5. **No uses claves sin passphrase para servers remotos**: Excepto CI/CD controlado
6. **No hagas forward de ssh-agent a servers no confiables**: Risk de key theft

---

## 🔄 Rotación de Claves

### Clave normal (cada 1-2 años)

```bash
# Generar nueva
ssh-keygen -t ed25519 -C "miguel@dev-$(date +%Y)"

# Añadir a GitHub/GitLab
cat ~/.ssh/id_ed25519.pub

# Después de 1 mes, eliminar vieja de GitHub
# Renombrar vieja: mv ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.old
```

### Yubikey (solo si se pierde/compromete)

```bash
# Generar nueva resident key
ssh-keygen -t ed25519-sk -O resident -C "miguel@hetzner-$(date +%Y)"

# Actualizar en todos los servers
# Eliminar vieja de ~/.ssh/authorized_keys en servers
```

---

## 💡 Caso de Uso: Tu Situación Actual

**Tienes solo Yubikey key**, lo cual es muy seguro pero incómodo para git.

### Opción 1: Crear clave adicional para git (RECOMENDADO)

```bash
# Crear clave normal para desarrollo
ssh-keygen -t ed25519 -C "miguel@dev-workstation"

# Añadir a GitHub
cat ~/.ssh/id_ed25519.pub

# Configurar ssh config (ver arriba)
nano ~/.ssh/config

# Resultado:
# - GitHub: clave normal (rápido, sin touches)
# - Hetzner: Yubikey (seguro, con touch físico)
```

### Opción 2: Seguir solo con Yubikey (máxima seguridad)

```bash
# Usar Yubikey para TODO
# Pros: Máxima seguridad
# Cons: Touch físico para cada git push (incómodo)

# Añadir Yubikey a GitHub
cat ~/.ssh/id_ed25519_sk.pub
# Pegar en GitHub Settings → SSH keys
```

---

## 📖 Referencias

- SSH FIDO2: <https://developers.yubico.com/SSH/>
- GitHub SSH: <https://docs.github.com/en/authentication/connecting-to-github-with-ssh>
- OpenSSH Config: <https://man.openbsd.org/ssh_config>

---

**Mi recomendación para ti**:

1. **Mantén Yubikey para Hetzner** ✅ (máxima seguridad)
2. **Crea clave normal para GitHub/Git** ✅ (practicidad)
3. **Usa ssh-agent para clave normal** ✅ (comodidad)
4. **NO uses ssh-agent para Yubikey** ✅ (mantener touch físico)

**Última actualización**: 29 Diciembre 2025
