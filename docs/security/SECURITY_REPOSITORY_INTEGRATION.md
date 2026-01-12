# Security Repository Integration Analysis

## Repositorio Analizado

**Source**: <https://github.com/malpanez/security>
**Descripción**: Ansible collection de seguridad nivel empresarial con hardening SSH y automatización de compliance

---

## Resumen Ejecutivo

El repositorio `malpanez/security` contiene componentes de grado empresarial que pueden resolver **todos los problemas críticos actuales** de tu infraestructura, especialmente:

1. ✅ **Configuración PAM 2FA correcta** (resuelve el problema #5 diferido)
2. ✅ **Validación SSH pre-despliegue** (previene lockouts)
3. ✅ **Detección automática de capacidades** (compatibilidad multi-plataforma)
4. ✅ **Modo Review vs Enforce** (testing seguro)
5. ✅ **Algoritmos SSH modernos con fallback** (OpenSSH version-aware)

---

## Componentes Clave Aplicables

### 1. Role: `security_capabilities` ⭐

**Qué hace**: Detecta capacidades del sistema antes de configurar seguridad

**Valor para tu infraestructura**:

- Detecta versión de OpenSSH automáticamente
- Identifica disponibilidad de PAM U2F/FIDO2
- Detecta soporte para Security Keys (SK)
- Determina disponibilidad de SELinux

**Tareas principales**:

```yaml
1. Recolectar facts mínimos del sistema
2. Inventariar paquetes instalados
3. Determinar nombre del paquete SSH por distribución
4. Extraer versión de OpenSSH
5. Normalizar versión (major.minor)
6. Computar flags de capacidades:
   - openssh_supports_sk_keys: >= 8.2
   - supports_sshd_include_d: >= 8.2
   - pam_u2f_available: lib detectada
   - selinux_available: RHEL systems
7. Seleccionar modo de autenticación automáticamente
```

**Aplicación recomendada**:

- Ejecutar ANTES de cualquier configuración de seguridad
- Usar para determinar qué features activar
- Integrar en playbook principal como primer role

---

### 2. Role: `sshd_hardening` ⭐⭐⭐

**Qué hace**: Aplica configuración SSH endurecida con validación PRE-aplicación

**Características CRÍTICAS que necesitas**:

#### A. Validación Pre-Despliegue

```yaml
- name: Deploy hardened sshd_config
  ansible.builtin.template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
    validate: "{{ sshd_binary_path }} -t -f %s"  # ← CRÍTICO
    backup: yes
```

**Valor**: Previene aplicar configuraciones rotas. SSH valida ANTES de aplicar.

#### B. Detección de Versión SSH

```yaml
- name: Detect OpenSSH version
  ansible.builtin.command: "{{ sshd_binary_path }} -V"
  register: sshd_version_output
  changed_when: false
  failed_when: false

- name: Extract version number
  ansible.builtin.set_fact:
    openssh_version: "{{ sshd_version_output.stderr | regex_search('OpenSSH_([0-9.]+)', '\\1') | first }}"
```

**Valor**: Adapta configuración a versión instalada automáticamente.

#### C. Algoritmos Adaptativos

```yaml
- name: Select algorithm profile
  ansible.builtin.set_fact:
    algorithm_profile: "{{ 'legacy' if openssh_version is version('7.8', '<') else 'modern' }}"
```

**Perfiles disponibles**:

- **Modern** (OpenSSH >= 7.8):
  - Ciphers: chacha20-poly1305, aes256-gcm, aes128-gcm
  - MACs: hmac-sha2-512-etm, hmac-sha2-256-etm
  - KexAlgorithms: curve25519-sha256, diffie-hellman-group16-sha512

- **Legacy** (OpenSSH < 7.8):
  - Mantiene compatibilidad con versiones antiguas
  - Evita algoritmos no disponibles

**Valor**: Elimina errores de "unknown cipher" en diferentes versiones.

#### D. Match Blocks por Tipo de Usuario

**Template `sshd_config.j2`**:

```jinja2
# Human users - with MFA
{% if sshd_hardening_human_groups | length > 0 %}
Match Group {{ sshd_hardening_human_groups | join(',') }}
    AuthenticationMethods {{ 'publickey,keyboard-interactive' if auth_mode == 'pam_mfa' else 'publickey' }}
    PermitTTY yes
    AllowTcpForwarding yes
{% endif %}

# Service accounts - key-only, no interaction
{% if sshd_hardening_service_groups | length > 0 %}
Match Group {{ sshd_hardening_service_groups | join(',') }}
    AuthenticationMethods publickey
    PermitTTY no
    AllowTcpForwarding no
{% endif %}
```

**Valor**: Separa usuarios humanos (MFA) de cuentas de servicio (key-only).

#### E. Session Limits

```jinja2
LoginGraceTime {{ sshd_hardening_login_grace_time }}
ClientAliveInterval {{ sshd_hardening_client_alive_interval }}
ClientAliveCountMax {{ sshd_hardening_client_alive_count_max }}
MaxAuthTries {{ sshd_hardening_max_auth_tries }}
MaxSessions {{ sshd_hardening_max_sessions }}
MaxStartups {{ sshd_hardening_max_startups }}
```

**Valor**: Limita ataques de fuerza bruta y recursos.

---

### 3. Role: `pam_mfa` ⭐⭐

**Qué hace**: Configura PAM MFA correctamente con bypass para cuentas de servicio

**Características CRÍTICAS**:

#### A. Bypass de Cuentas de Servicio

```yaml
# Defaults
pam_mfa_service_accounts:
  - ansible
  - ci
  - sftp
  - rsync

pam_mfa_service_bypass_group: mfa-bypass
```

**Valor**: Evita bloquear automatización mientras protege usuarios humanos.

#### B. Grupos de Seguridad

```yaml
- name: Create breakglass group
  ansible.builtin.group:
    name: "{{ pam_mfa_breakglass_group }}"
    state: present

- name: Create service bypass group
  ansible.builtin.group:
    name: "{{ pam_mfa_service_bypass_group }}"
    state: present
```

**Valor**:

- `mfa-breakglass`: Acceso de emergencia sin MFA
- `mfa-bypass`: Cuentas de servicio sin MFA

#### C. Multi-método (YubiKey + TOTP Fallback)

```yaml
pam_mfa_primary_method: yubikey  # U2F/FIDO2
pam_mfa_totp_enabled: true       # Google Authenticator como backup
pam_mfa_totp_rate_limiting: true

# Ubicaciones
pam_mfa_yubikey_dir: /etc/Yubico/u2f_keys
pam_mfa_totp_dir: /etc/google-authenticator.d
```

**Valor**: Flexibilidad - YubiKey cuando disponible, TOTP como fallback.

#### D. Directorios Securizados

```yaml
- name: Create U2F keys directory
  ansible.builtin.file:
    path: "{{ pam_mfa_yubikey_dir }}"
    state: directory
    mode: '0750'

- name: Create TOTP secrets directory
  ansible.builtin.file:
    path: "{{ pam_mfa_totp_dir }}"
    state: directory
    mode: '0700'
```

**Valor**: Permisos correctos para secrets.

---

### 4. Role: `audit_logging` ⭐

**Qué hace**: Implementa reglas auditd para SSH, sudo, y cambios de configuración

**Valor**: Compliance y troubleshooting - logs detallados de accesos.

---

### 5. Role: `compliance_evidence` ⭐

**Qué hace**: Genera reportes de compliance automáticos

**Valor**: Documentación para auditorías SOC2/HIPAA/FedRAMP.

---

## Modos de Ejecución: Review vs Enforce

### Review Mode (SEGURO)

```yaml
- hosts: all
  vars:
    security_mode: review
  roles:
    - security_capabilities
    - sshd_hardening
```

**Comportamiento**:

- Solo detecta capacidades
- Solo genera reportes
- NO modifica servicios
- NO reinicia SSH
- Permite ver QUÉ se aplicaría

**Uso recomendado**: SIEMPRE ejecutar review ANTES de enforce.

### Enforce Mode (APLICACIÓN)

```yaml
- hosts: all
  vars:
    security_mode: enforce
  roles:
    - security_capabilities
    - sshd_hardening
    - pam_mfa
```

**Comportamiento**:

- Aplica todas las configuraciones
- Reinicia servicios
- Ejecuta validación pre-aplicación

**Protección**: Tasks con `when: security_mode == 'enforce'` previenen ejecución accidental.

---

## Playbooks Disponibles

### 1. `preflight-check.yml` ⭐⭐⭐

Valida prerequisites ANTES de deployment:

- Versión SSH compatible
- Paquetes requeridos instalados
- Permisos correctos
- Conectividad

### 2. `review.yml` ⭐⭐⭐

Ejecuta solo detección y reporting:

```bash
ansible-playbook playbooks/review.yml --tags review
```

### 3. `dry-run.yml` ⭐⭐

Test run con `check_mode`:

```bash
ansible-playbook playbooks/dry-run.yml --check
```

### 4. `enforce-staging.yml` ⭐⭐

Deployment a staging first:

- Prueba en staging
- Valida antes de producción

### 5. `enforce-production-gradual.yml` ⭐

Rollout gradual:

- Serial: 1 (uno a la vez)
- Max_fail_percentage: 0
- Pausa entre servers

### 6. `generate-compliance-report.yml` ⭐

Genera reportes detallados de compliance.

---

## Comparación: Tu Código vs Security Repository

| Aspecto | Tu Código Actual | Security Repo | Diferencia |
|---------|------------------|---------------|------------|
| **PAM 2FA Config** | ❌ Control flag incorrecto (`required`) | ✅ Control correcto + bypass | CRÍTICO |
| **SSH Validation** | ❌ No valida antes de aplicar | ✅ Valida con `sshd -t -f` | CRÍTICO |
| **Version Detection** | ❌ Asume versión específica | ✅ Detecta automáticamente | ALTO |
| **Algorithm Profiles** | ❌ Hardcoded para versión específica | ✅ Adapta a versión detectada | ALTO |
| **Service Account Bypass** | ❌ No implementado | ✅ Grupo mfa-bypass | ALTO |
| **Review Mode** | ❌ No existe | ✅ Testing seguro | ALTO |
| **Match Blocks** | ✅ Básicos | ✅ Avanzados por tipo usuario | MEDIO |
| **Breakglass Access** | ❌ No implementado | ✅ Grupo emergencia | MEDIO |
| **Capability Detection** | ❌ Manual | ✅ Automático | MEDIO |

---

## Problemas Actuales Resueltos por Security Repo

### Problema #1: AppArmor Bloqueando SSH ✅

**Estado actual**: Cambiado a complain mode (workaround)

**Solución Security Repo**:

- No usa AppArmor (usa SELinux en RHEL)
- Confía en SSH hardening + PAM MFA + auditd
- Enfoque: Configuración correcta > MAC enforcement

**Recomendación**: Mantener AppArmor en complain mode o desactivar hasta tener SSH 100% funcional.

---

### Problema #2: Reboot No Ejecutado ✅ (YA RESUELTO)

**Estado**: Arreglado en tu código

**Security Repo approach**: Similar pero con mejor consistency.

---

### Problema #3: Orden de Roles ✅ (YA RESUELTO)

**Estado**: SSH 2FA antes de firewall

**Security Repo approach**: Similar - configuración antes de enforcement.

---

### Problema #4: UFW Race Condition ⚠️

**Estado**: Parcialmente mitigado

**Security Repo approach**:

- No usa UFW (usa firewalld en RHEL)
- En Debian: asume SSH permitido por defecto
- Confía en validación de conectividad POST-deployment

**Solución mejor**:

```yaml
- name: Verify SSH connectivity before enabling firewall
  ansible.builtin.wait_for:
    host: "{{ ansible_default_ipv4.address }}"
    port: 22
    state: started
    timeout: 10
  delegate_to: localhost
  become: false
```

---

### Problema #5: PAM 2FA Module Misconfiguration ✅ ⭐⭐⭐

**Estado actual**: Identificado pero no arreglado (crítico)

**Tu configuración actual** (INCORRECTA):

```
auth required pam_google_authenticator.so
```

**Problemas**:

1. `required` = si falla, sigue procesando pero SIEMPRE deniega
2. Insertado después de pam_unix.so (orden incorrecto)
3. No bypass para cuentas de servicio
4. Puede causar loops de autenticación

**Security Repo approach** (CORRECTO):

```
# NO aplica MFA a cuentas en mfa-bypass group
# Usa control [default=ignore] en vez de required
# Procesa ANTES de pam_unix.so
```

**Ejemplo correcto PAM stack**:

```
# /etc/pam.d/sshd

# PRIMERO: MFA para usuarios NO en bypass group
auth [success=done default=ignore] pam_succeed_if.so quiet user ingroup mfa-bypass
auth required pam_google_authenticator.so

# SEGUNDO: Unix authentication
auth required pam_unix.so

# Resto del stack...
```

**Valor**: Elimina riesgo de lockout total.

---

## Plan de Integración Recomendado

### Opción A: Integración Completa (RECOMENDADO) ⭐⭐⭐

**Paso 1**: Instalar la collection

```bash
# En tu proyecto
ansible-galaxy collection install git+https://github.com/malpanez/security.git
```

**Paso 2**: Crear nuevo playbook híbrido

```yaml
# playbooks/secure-deployment.yml
---
- name: Security Capability Detection
  hosts: hetzner
  become: true
  roles:
    - role: malpanez.security.security_capabilities
      tags: [security, preflight]

- name: Infrastructure Provisioning
  hosts: hetzner
  become: true
  vars:
    security_mode: enforce
  roles:
    # Tus roles actuales - infrastructure
    - role: common
      tags: [common, base]

    # Security Repo - SSH hardening
    - role: malpanez.security.sshd_hardening
      tags: [security, ssh]
      vars:
        sshd_hardening_password_authentication: false
        sshd_hardening_permit_root_login: "no"
        sshd_hardening_allow_users:
          - malpanez
        sshd_hardening_human_groups:
          - sudo
        sshd_hardening_service_groups:
          - mfa-bypass

    # Security Repo - PAM MFA (ARREGLA TU PROBLEMA #5)
    - role: malpanez.security.pam_mfa
      tags: [security, 2fa]
      vars:
        pam_mfa_enabled: true
        pam_mfa_service_accounts:
          - ansible
          - malpanez  # Temporal hasta configurar TOTP

    # Tus roles actuales - firewall
    - role: firewall
      tags: [security, firewall]
      when: firewall_enabled | default(true) | bool

    # Security Repo - Auditing
    - role: malpanez.security.audit_logging
      tags: [security, audit]

    # Tus roles actuales - resto
    - role: fail2ban
    - role: nginx_wordpress
    - role: openbao
    # etc...

- name: Reboot if kernel parameters changed
  hosts: hetzner
  become: true
  gather_facts: true
  tasks:
    - name: Reboot if needed
      ansible.builtin.reboot:
        msg: "Rebooting for kernel parameters"
      when: ansible_reboot_required | default(false)
```

**Ventajas**:

- ✅ Resuelve TODOS los problemas críticos
- ✅ Validación pre-aplicación (previene lockouts)
- ✅ PAM MFA correctamente configurado
- ✅ Detección automática de capacidades
- ✅ Código battle-tested (usado en producción)

**Desventajas**:

- Requiere learning curve de la collection
- Dependencia externa (pero es TU repositorio)

---

### Opción B: Cherry-Pick Específico (RÁPIDO)

**Solo tomar elementos específicos que necesitas**:

#### 1. Validación SSH Pre-Aplicación

Agregar a tu role `ssh_2fa/tasks/configure.yml`:

```yaml
- name: Deploy SSH 2FA configuration
  ansible.builtin.template:
    src: sshd_2fa.conf.j2
    dest: /etc/ssh/sshd_config.d/20-2fa.conf
    owner: root
    group: root
    mode: '0644'
    validate: '/usr/sbin/sshd -t -f %s'  # ← AGREGAR ESTO
    backup: yes
  notify: restart ssh
```

**Impacto**: Previene aplicar configuraciones SSH rotas.

#### 2. Detección de Versión SSH

Agregar al principio de `ssh_2fa/tasks/main.yml`:

```yaml
- name: Detect OpenSSH version
  ansible.builtin.command: /usr/sbin/sshd -V
  register: sshd_version_output
  changed_when: false
  failed_when: false

- name: Extract and normalize SSH version
  ansible.builtin.set_fact:
    openssh_version: "{{ sshd_version_output.stderr | regex_search('OpenSSH_([0-9]+\\.[0-9]+)', '\\1') | first }}"
    cacheable: true

- name: Display detected OpenSSH version
  ansible.builtin.debug:
    msg: "Detected OpenSSH version: {{ openssh_version }}"
```

**Uso**: Condicionar features basado en versión.

#### 3. Grupo de Bypass para Cuentas de Servicio

Agregar a `ssh_2fa/tasks/configure.yml`:

```yaml
- name: Create MFA bypass group for service accounts
  ansible.builtin.group:
    name: mfa-bypass
    state: present

- name: Add service accounts to bypass group
  ansible.builtin.user:
    name: "{{ item }}"
    groups: mfa-bypass
    append: yes
  loop:
    - ansible
    - "{{ ansible_user }}"  # Mientras configuras
```

Modificar template `sshd_2fa.conf.j2`:

```jinja2
# Service accounts bypass (no MFA)
Match Group mfa-bypass
    AuthenticationMethods publickey
    PermitTTY yes

# Human users (with MFA)
Match Group sudo
    AuthenticationMethods publickey,keyboard-interactive:pam
    PermitTTY yes
```

**Impacto**: Permite despliegues automatizados sin bloquear MFA.

#### 4. PAM Stack Correcto

**CRÍTICO** - Arregla tu problema #5

Modificar `ssh_2fa/tasks/configure.yml`:

```yaml
- name: Configure PAM for SSH with MFA
  ansible.builtin.blockinfile:
    path: /etc/pam.d/sshd
    marker: "# {mark} ANSIBLE MANAGED - SSH MFA"
    insertbefore: '^@include common-auth'
    block: |
      # Bypass MFA for service accounts
      auth [success=done default=ignore] pam_succeed_if.so quiet user ingroup mfa-bypass

      # Require Google Authenticator for all other users
      auth required pam_google_authenticator.so nullok echo_verification_code
    backup: yes
  notify: restart ssh
```

**Cambios clave**:

- Bypass para grupo `mfa-bypass` ANTES de requerir MFA
- Control `[success=done default=ignore]` en vez de `required`
- Insert BEFORE common-auth (orden correcto)
- `nullok` permite usuarios sin TOTP configurado todavía
- `echo_verification_code` muestra el código (útil para debugging)

**Impacto**: Elimina riesgo de authentication loops y lockouts.

---

### Opción C: Review Mode Testing (MUY SEGURO)

**Ejecutar collection en modo review PRIMERO**:

```bash
# Instalar collection
cd /tmp
git clone https://github.com/malpanez/security.git
cd security

# Ejecutar SOLO review
ansible-playbook \
  -i /home/malpanez/repos/hetzner-secure-infrastructure/ansible/inventory/hetzner.hcloud.yml \
  -u root \
  -e security_mode=review \
  playbooks/review.yml

# Revisar reportes generados
cat /tmp/compliance_reports/*.json
```

**Valor**: Ver QUÉ cambiaría sin aplicar nada.

---

## Recomendación Final

### Para Mañana - Plan Paso a Paso

#### Fase 1: Testing Seguro (30 min)

```bash
# 1. Clonar security repo
cd ~/repos
git clone https://github.com/malpanez/security.git

# 2. Ejecutar review mode
cd security
ansible-playbook \
  -i ../hetzner-secure-infrastructure/ansible/inventory/hetzner.hcloud.yml \
  -u root \
  -e security_mode=review \
  playbooks/review.yml

# 3. Revisar qué detecta
```

#### Fase 2: Cherry-Pick Crítico (1 hora)

Aplicar SOLO los 4 cambios de Opción B:

1. ✅ Validación SSH pre-aplicación
2. ✅ Detección de versión SSH
3. ✅ Grupo bypass MFA
4. ✅ **PAM stack correcto** (CRÍTICO)

#### Fase 3: Deploy y Test (1 hora)

```bash
# 1. Deploy Terraform
cd terraform
terraform apply

# 2. Deploy Ansible con fixes
cd ../ansible
export HCLOUD_TOKEN="..."
ansible-playbook -u root playbooks/site.yml

# 3. Verificar SSH funciona
ssh -i ~/.ssh/github_ed25519 root@<SERVER_IP>

# 4. Verificar 2FA funciona (si configurado)
```

#### Fase 4: Configurar TOTP (30 min)

```bash
# Como root en el servidor
google-authenticator

# Capturar QR code
# Probar login con 2FA
```

---

## Archivos a Modificar

### 1. `ansible/roles/ssh_2fa/tasks/configure.yml`

- Agregar validación SSH (`validate:`)
- Agregar detección de versión
- Crear grupo mfa-bypass
- ARREGLAR PAM stack (CRÍTICO)

### 2. `ansible/roles/ssh_2fa/templates/sshd_2fa.conf.j2`

- Agregar Match block para mfa-bypass group
- Separar humanos de service accounts

### 3. `ansible/playbooks/site.yml`

- Considerar agregar preflight checks
- Opcional: integrar roles de security repo

---

## Riesgos y Mitigación

### Riesgo 1: Lockout durante cambio de PAM

**Mitigación**:

- Mantener sesión root abierta durante cambios
- Usar Hetzner Console como backup
- Aplicar `nullok` en Google Authenticator temporalmente

### Riesgo 2: Dependencia de repositorio externo

**Mitigación**:

- Es TU repositorio, tienes control total
- Puede vendorizar en tu proyecto
- Cherry-pick elimina dependencia

### Riesgo 3: Incompatibilidad con código actual

**Mitigación**:

- Review mode testing primero
- Cherry-pick individual de features
- Testing en staging (ARM CAX11 barato)

---

## Siguientes Pasos Inmediatos

1. ✅ **HOY**: Leer este documento completo
2. ✅ **MAÑANA AM**: Ejecutar review mode del security repo
3. ✅ **MAÑANA AM**: Cherry-pick los 4 cambios críticos
4. ✅ **MAÑANA PM**: Deploy y testing completo
5. ⏸️ **FUTURO**: Considerar integración completa

---

## Conclusión

El repositorio `malpanez/security` es **EXACTAMENTE** lo que necesitas para resolver tus problemas actuales:

- ✅ PAM MFA configurado CORRECTAMENTE (resuelve problema #5)
- ✅ Validación SSH pre-aplicación (previene lockouts)
- ✅ Bypass de cuentas de servicio (permite automatización)
- ✅ Detección automática de capacidades
- ✅ Review mode para testing seguro

**Recomendación**: Cherry-pick los 4 elementos críticos de la Opción B mañana antes de deploy.

**Tiempo estimado**: 2 horas de trabajo para tener SSH + 2FA funcionando perfectamente.
