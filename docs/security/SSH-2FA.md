# SSH Two-Factor Authentication (2FA) - Explicación Completa

## ¿Qué es PAM 2FA?

**PAM** (Pluggable Authentication Modules) es el sistema de autenticación de Linux. El módulo `pam_google_authenticator` añade un segundo factor de autenticación basado en TOTP (Time-based One-Time Password) al proceso de login SSH.

---

## Cómo Funciona SSH 2FA con SSH Keys

### Concepto Importante

Cuando tienes **SSH key authentication** habilitada Y **PAM 2FA** habilitada, ambas se ejecutan:

```
┌─────────────────────────────────────────────────────────────┐
│                  SSH LOGIN PROCESS                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
         ┌──────────────────────────────────────┐
         │  1. SSH Key Authentication           │
         │     - Cliente presenta clave privada │
         │     - Servidor valida firma          │
         │     - Yubikey: Touch required        │
         └──────────────┬───────────────────────┘
                        │
                ✅ SSH key válida
                        │
                        ▼
         ┌──────────────────────────────────────┐
         │  2. PAM 2FA Challenge                │
         │     - "Verification code:"           │
         │     - Usuario ingresa código TOTP    │
         │     - Google Authenticator valida    │
         └──────────────┬───────────────────────┘
                        │
                ✅ Código correcto
                        │
                        ▼
         ┌──────────────────────────────────────┐
         │  ✅ LOGIN SUCCESSFUL                 │
         └──────────────────────────────────────┘
```

**Ambos factores son necesarios**:
1. **Algo que tienes**: SSH private key (Yubikey)
2. **Algo que sabes**: TOTP code (Google Authenticator)

---

## Configuración Actual

### SSH Server (`/etc/ssh/sshd_config`)

```bash
# Authentication methods
PubkeyAuthentication yes           # SSH keys habilitadas
PasswordAuthentication no          # Passwords deshabilitadas
ChallengeResponseAuthentication yes # PAM 2FA habilitado

# PAM configuration
UsePAM yes
```

### PAM Configuration (`/etc/pam.d/sshd`)

```bash
# 2FA con Google Authenticator
auth required pam_google_authenticator.so nullok

# El resto de la config PAM...
```

**Parámetros importantes**:
- `required`: El módulo DEBE pasar (sin código = sin acceso)
- `nullok`: Permite login si el usuario NO tiene 2FA configurado (temporal)

---

## Setup Para Usuario

### 1. Configurar Google Authenticator (Primera Vez)

Como usuario `malpanez` en el servidor:

```bash
# Iniciar configuración
google-authenticator

# Preguntas:
# Do you want authentication tokens to be time-based? YES
# --> Se muestra QR code en terminal

# Escanear QR con app móvil:
# - Google Authenticator (Android/iOS)
# - Authy
# - Microsoft Authenticator
# - FreeOTP

# ¿Actualizar ~/.google_authenticator? YES
# ¿Disallow multiple uses? YES
# ¿Increase window? NO (mantener ventana de 30s)
# ¿Enable rate-limiting? YES
```

### 2. Backup de Códigos de Emergencia

El comando anterior genera códigos de emergencia (scratch codes). **GUÁRDALOS**:

```
Your emergency scratch codes are:
  12345678
  87654321
  11223344
  44332211
  99887766

Save these in a secure location!
```

Estos códigos:
- Solo funcionan UNA vez cada uno
- Útiles si pierdes el móvil
- Deberías guardarlos en tu password manager

### 3. Testing

Abre una **NUEVA** sesión SSH (NO cierres la actual):

```bash
ssh malpanez@server-ip

# Proceso:
# 1. Yubikey touch prompt (SSH key)
# 2. "Verification code:" (ingresa código de app)
# 3. Welcome message (login exitoso)
```

---

## Ejemplo Real de Login

```bash
$ ssh malpanez@46.224.156.140

# 1. SSH Key challenge (Yubikey)
Confirm user presence for key ED25519-SK SHA256:abc...
# [Tocas la Yubikey física - LED parpadea]

# 2. PAM 2FA challenge
Verification code: 123456
# [Ingresas código de Google Authenticator app]

# 3. Success
Linux staging-wordpress 6.x.x-amd64 #1 SMP Debian GNU/Linux
malpanez@staging-wordpress:~$
```

---

## ¿Qué Pasa Si...?

### No tienes la app móvil a mano?
- Usa un **scratch code** (código de emergencia)
- Solo funciona 1 vez, luego se invalida

### Pierdes el móvil?
- Usa **scratch codes**
- O conecta desde una sesión existente y reconfigura:
  ```bash
  google-authenticator
  # Genera nuevo QR code
  ```

### Se desincroniza el reloj (código siempre incorrecto)?
- La app usa TOTP (time-based)
- Verifica que la hora del móvil esté sincronizada
- Alternativa: `google-authenticator -t -w 3` (ventana más grande)

### Quieres deshabilitar 2FA temporalmente?
```bash
# Como root, editar PAM config
sudo nano /etc/pam.d/sshd

# Cambiar:
auth required pam_google_authenticator.so nullok
# Por:
auth sufficient pam_google_authenticator.so nullok

# Recargar SSH
sudo systemctl restart ssh
```

---

## Múltiples Usuarios

Cada usuario configura su propio 2FA:

```bash
# Usuario 1 (malpanez)
su - malpanez
google-authenticator
# --> Genera su propio QR + códigos

# Usuario 2 (deploy)
su - deploy
google-authenticator
# --> Genera QR diferente + códigos diferentes
```

Cada uno escanea su propio QR en su app móvil.

---

## Apps Recomendadas

### Google Authenticator
- **Plataforma**: Android, iOS
- **Backup**: Local (no cloud)
- **Pros**: Simple, confiable
- **Contras**: No sincroniza entre dispositivos

### Authy
- **Plataforma**: Android, iOS, Desktop
- **Backup**: Cloud (encrypted)
- **Pros**: Multi-device, backup cloud
- **Contras**: Requiere cuenta Twilio

### Microsoft Authenticator
- **Plataforma**: Android, iOS
- **Backup**: Cloud (Microsoft account)
- **Pros**: Backup automático, multi-device

### Bitwarden Authenticator (Recomendado)
- **Plataforma**: Dentro de Bitwarden password manager
- **Backup**: Vault sincronizado
- **Pros**: Todo en un solo lugar, backup automático
- **Contras**: Requiere Bitwarden Premium

---

## Security Best Practices

### ✅ DO
- **Backup scratch codes** en password manager
- **Test 2FA** antes de cerrar sesión original
- **Configura 2FA en múltiples dispositivos** (Authy permite multi-device)
- **Mantén reloj sincronizado** (NTP en móvil)
- **Usa apps con backup** (Authy, Microsoft Auth)

### ❌ DON'T
- **No desactives 2FA** una vez configurado
- **No compartas scratch codes**
- **No uses la misma configuración** para múltiples servidores (genera nueva cada vez)
- **No confíes solo en un dispositivo** (backup!)

---

## Troubleshooting

### Código siempre incorrecto

```bash
# 1. Verificar hora del servidor
date
timedatectl

# 2. Verificar sincronización NTP
timedatectl show-timesync --all

# 3. Aumentar ventana de tiempo (permite ±3 códigos)
google-authenticator -t -w 3
```

### No puedes acceder (perdiste móvil y scratch codes)

**Opción 1**: Acceso vía consola Hetzner (no requiere SSH):
```bash
# En Hetzner Cloud Console:
# Server → Console → Root login

# Como root:
rm /home/malpanez/.google_authenticator
# Ahora el usuario puede entrar sin 2FA (nullok)

# Reconfigurar:
su - malpanez
google-authenticator
```

**Opción 2**: Si tienes otra sesión SSH abierta:
```bash
# En sesión existente:
rm ~/.google_authenticator
google-authenticator
# Escanear nuevo QR code
```

---

## Configuración Avanzada

### Rate Limiting (anti-brute force)

Ya configurado por defecto:
- **Max intentos**: 3 cada 30 segundos
- **Lockout**: Temporal (no permanente)

### Window Size (ventana de tiempo)

```bash
# Reconfigurar con ventana más amplia
google-authenticator -t -w 5

# -w 1: Solo acepta código actual (±30s)
# -w 3: Acepta código anterior/actual/siguiente (±90s)
# -w 5: Mayor tolerancia (±150s) - útil si reloj se desincroniza
```

### Secret Key Storage

El archivo `~/.google_authenticator` contiene:
```
SECRET_KEY_BASE32
" RATE_LIMIT 3 30
" WINDOW_SIZE 17
" DISALLOW_REUSE
" TOTP_AUTH
12345678  # Scratch code 1
87654321  # Scratch code 2
...
```

**Permisos** (muy importante):
```bash
chmod 400 ~/.google_authenticator
# Solo el propietario puede leer
```

---

## Referencias

- Google Authenticator PAM: https://github.com/google/google-authenticator-libpam
- RFC 6238 (TOTP): https://tools.ietf.org/html/rfc6238
- Debian Wiki SSH 2FA: https://wiki.debian.org/google-authenticator
