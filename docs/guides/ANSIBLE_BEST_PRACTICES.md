# Ansible Best Practices Implementadas

> **Guía de las mejores prácticas de Ansible y Red Hat implementadas en este proyecto**

Última actualización: 2026-01-09

---

**Nota**: El stack de monitorización usa colecciones externas (`prometheus.prometheus`, `grafana.grafana`). Los ejemplos con `prometheus` son ilustrativos.

## Tabla de Contenidos

- [Naming Conventions](#naming-conventions)
- [Estructura de Roles](#estructura-de-roles)
- [Variables](#variables)
- [Tasks](#tasks)
- [Templates](#templates)
- [Handlers](#handlers)
- [Tags](#tags)
- [Referencias](#referencias)

---

## Naming Conventions

### Variables

✅ **REGLA**: Todas las variables de un role deben tener el prefijo `rolename_`

**Propósito**: Evitar colisiones de nombres entre roles y hacer explícito de dónde viene cada variable.

**Ejemplos correctos:**

```yaml
# ansible/roles/prometheus/defaults/main.yml
prometheus_version: latest
prometheus_port: 9090
prometheus_config_dir: /etc/prometheus
prometheus_scrape_node_exporter: true
```

```yaml
# ansible/roles/firewall/defaults/main.yml
firewall_enabled: true
firewall_default_incoming_policy: deny
firewall_allowed_ports: [...]
```

```yaml
# ansible/roles/nginx-wordpress/defaults/main.yml
nginx_wordpress_domain: example.com
nginx_wordpress_php_version: "8.3"
nginx_wordpress_learndash_lms_enabled: true
```

**Ejemplos INCORRECTOS (corregidos):**

```yaml
# ❌ ANTES (incorrecto)
wordpress_domain: example.com
php_version: "8.3"
cloudflare_enabled: true

# ✅ DESPUÉS (correcto)
nginx_wordpress_domain: example.com
nginx_wordpress_php_version: "8.3"
nginx_wordpress_cloudflare_enabled: true
```

### Excepciones Aceptables

**Variables de deployment control** pueden no tener prefijo si son globales:

```yaml
# Aceptable - variable global de deployment
deploy_prometheus: true
deploy_loki: true
firewall_enabled: true
```

**Variables de Ansible Vault** deben mantener el prefijo `vault_`:

```yaml
# Correcto - vault variables
vault_mariadb_root_password: "..."
vault_mariadb_wordpress_db_password: "..."
```

---

## Tasks

✅ **REGLA**: Todas las tasks deben tener prefijos claros en el `name`

**Propósito**: Identificar rápidamente qué role y qué fase ejecutó cada task en los logs de Ansible.

### Formato según estructura

#### 1. Tasks en main.yml (sin imports)

**Formato**: `rolename | task_description`

```yaml
# ansible/roles/firewall/tasks/main.yml
- name: firewall | Install UFW
  ansible.builtin.apt:
    name: ufw
    state: present

- name: firewall | Set UFW default policies
  community.general.ufw:
    direction: "{{ item.direction }}"
    policy: "{{ item.policy }}"
  loop: [...]

- name: firewall | Enable UFW
  community.general.ufw:
    state: enabled
```

#### 2. Tasks con estructura modular (usando import_tasks/include_tasks)

**Formato**: `rolename | taskfile | task_description`

```yaml
# ansible/roles/prometheus/tasks/main.yml (orchestrator)
- name: prometheus | main | Include installation tasks
  ansible.builtin.import_tasks: install.yml
  tags: [prometheus, install]

- name: prometheus | main | Include configuration tasks
  ansible.builtin.import_tasks: configure.yml
  tags: [prometheus, config]

- name: prometheus | main | Include service tasks
  ansible.builtin.import_tasks: service.yml
  tags: [prometheus, service]
```

```yaml
# ansible/roles/prometheus/tasks/install.yml
- name: prometheus | install | Create APT keyrings directory
  ansible.builtin.file:
    path: /etc/apt/keyrings
    state: directory
    mode: '0755'

- name: prometheus | install | Download Prometheus Community GPG key
  ansible.builtin.get_url:
    url: https://s3.amazonaws.com/deb.robustperception.io/41EFC99D.gpg
    dest: /tmp/prometheus.gpg.key

- name: prometheus | install | Install Prometheus package
  ansible.builtin.apt:
    name: prometheus
    state: present
```

```yaml
# ansible/roles/prometheus/tasks/configure.yml
- name: prometheus | configure | Deploy Prometheus configuration
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: /etc/prometheus/prometheus.yml

- name: prometheus | configure | Deploy alert rules
  ansible.builtin.template:
    src: rules/{{ item.name }}.yml.j2
    dest: /etc/prometheus/rules/{{ item.name }}.yml
  loop: "{{ prometheus_default_rules }}"

- name: prometheus | configure | Set configuration permissions
  ansible.builtin.file:
    path: /etc/prometheus/prometheus.yml
    owner: prometheus
    group: prometheus
    mode: "0644"
```

```yaml
# ansible/roles/prometheus/tasks/service.yml
- name: prometheus | service | Deploy systemd service file
  ansible.builtin.template:
    src: prometheus.service.j2
    dest: /etc/systemd/system/prometheus.service

- name: prometheus | service | Enable Prometheus service
  ansible.builtin.systemd:
    name: prometheus
    enabled: true
    daemon_reload: true

- name: prometheus | service | Start Prometheus
  ansible.builtin.systemd:
    name: prometheus
    state: started
```

```yaml
# ansible/roles/prometheus/tasks/main.yml
- name: prometheus | Add Prometheus APT repository (DEB822 format)
  ansible.builtin.deb822_repository:
    name: prometheus
    uris: https://s3.amazonaws.com/deb.robustperception.io/debian
    [...]

- name: prometheus | Install Prometheus
  ansible.builtin.apt:
    name: prometheus
    state: present
```

### Beneficios de esta convención

**1. Trazabilidad completa en logs:**

```
TASK [prometheus | install | Create APT keyrings directory] *******************
ok: [server-01]

TASK [prometheus | install | Download Prometheus Community GPG key] ***********
changed: [server-01]

TASK [prometheus | install | Install Prometheus package] **********************
changed: [server-01]

TASK [prometheus | configure | Deploy Prometheus configuration] ***************
changed: [server-01]

TASK [prometheus | configure | Deploy alert rules] ****************************
changed: [server-01] => (item={'name': 'instance_down'})
changed: [server-01] => (item={'name': 'high_cpu'})

TASK [prometheus | service | Enable Prometheus service] ***********************
ok: [server-01]

TASK [prometheus | service | Start Prometheus] *********************************
changed: [server-01]
```

**2. Debugging inmediato:**

- Sabes exactamente **qué role** falló (`prometheus`)
- Sabes en **qué fase** falló (`install`, `configure`, `service`)
- Sabes **qué task específica** causó el error

**3. Testing granular:**

```bash
# Ejecutar solo instalación
ansible-playbook site.yml --tags install

# Ejecutar solo configuración de prometheus
ansible-playbook site.yml --tags "prometheus,config"

# Re-ejecutar solo la fase de servicio
ansible-playbook site.yml --tags service
```

**4. Mejor mantenimiento:**

- Fácil identificar qué archivo modificar
- Código organizado por responsabilidad
- Reutilización de sub-tasks en diferentes playbooks

**Output de ejemplo:**

```
TASK [firewall | Install UFW] ****************************************************
ok: [server-01]

TASK [firewall | Set UFW default policies] ***************************************
changed: [server-01] => (item={'direction': 'incoming', 'policy': 'deny'})
changed: [server-01] => (item={'direction': 'outgoing', 'policy': 'allow'})

TASK [firewall | Enable UFW] *****************************************************
changed: [server-01]
```

---

## Estructura de Roles

### Estructura Básica

```
role_name/
├── defaults/
│   └── main.yml          # Variables por defecto (menor prioridad)
├── vars/
│   └── main.yml          # Variables del role (mayor prioridad)
├── tasks/
│   └── main.yml          # Tasks principales
├── templates/
│   └── *.j2              # Plantillas Jinja2
├── files/
│   └── *                 # Archivos estáticos
├── handlers/
│   └── main.yml          # Handlers (restart, reload, etc.)
├── meta/
│   └── main.yml          # Metadata y dependencias
└── molecule/
    └── default/
        ├── molecule.yml  # Configuración de tests
        ├── converge.yml  # Playbook de test
        └── verify.yml    # Verificación de tests
```

### Estructura Modular (Recomendada para roles complejos)

```
role_name/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml          # Orchestrator (clean, just imports)
│   ├── install.yml       # Installation tasks
│   ├── configure.yml     # Configuration tasks
│   ├── service.yml       # Service management
│   ├── firewall.yml      # Firewall rules (if needed)
│   ├── backup.yml        # Backup configuration
│   └── validate.yml      # Validation/tests
├── templates/
│   ├── config/
│   │   └── service.conf.j2
│   ├── systemd/
│   │   └── service.service.j2
│   └── scripts/
│       └── backup.sh.j2
└── handlers/
    └── main.yml
```

**main.yml como orchestrator:**

```yaml
---
# Role: role_name
# Main tasks file - orchestrates all sub-tasks

- name: role_name | Check if deployment is enabled
  ansible.builtin.debug:
    msg: "Role deployment: {{ role_name_enabled | default(true) }}"

- name: role_name | Skip deployment if not enabled
  ansible.builtin.meta: end_play
  when: role_name_enabled is defined and not role_name_enabled

- name: role_name | Include installation tasks
  ansible.builtin.import_tasks: install.yml
  tags: [role_name, install]

- name: role_name | Include configuration tasks
  ansible.builtin.import_tasks: configure.yml
  tags: [role_name, config]

- name: role_name | Include service management tasks
  ansible.builtin.import_tasks: service.yml
  tags: [role_name, service]

- name: role_name | Include validation tasks
  ansible.builtin.import_tasks: validate.yml
  tags: [role_name, validate]
```

**Ventajas:**

- ✅ Mejor organización
- ✅ Más fácil de mantener
- ✅ Reutilización de sub-tasks
- ✅ Testing más granular
- ✅ Debugging simplificado

---

## Variables

### Orden de Precedencia (de menor a mayor)

1. `role/defaults/main.yml` - Defaults del role (menor prioridad)
2. `inventory/group_vars/all/*.yml` - Variables globales
3. `inventory/group_vars/GROUP/*.yml` - Variables de grupo
4. `inventory/host_vars/HOST/*.yml` - Variables de host
5. `playbook vars` - Variables en playbook
6. `role/vars/main.yml` - Variables del role (mayor prioridad)
7. `extra-vars` (-e en CLI) - Mayor prioridad de todas

### Best Practices para Variables

**1. Usar `defaults/main.yml` para valores configurables:**

```yaml
# defaults/main.yml - Usuario puede overridear
prometheus_port: 9090
prometheus_retention_time: 30d
prometheus_scrape_interval: 15s
```

**2. Usar `vars/main.yml` para valores fijos:**

```yaml
# vars/main.yml - No se debe overridear
prometheus_config_dir: /etc/prometheus
prometheus_data_dir: /var/lib/prometheus
prometheus_user: prometheus
```

**3. Documentar todas las variables:**

```yaml
# ========================================
# Monitoring Configuration
# ========================================

# Enable/disable Prometheus deployment
# Type: boolean
# Default: true
prometheus_enabled: true

# Prometheus HTTP port
# Type: integer
# Range: 1024-65535
# Default: 9090
prometheus_port: 9090

# Data retention time
# Type: string (duration)
# Examples: 7d, 30d, 90d
# Default: 30d
prometheus_retention_time: 30d
```

**4. Agrupar variables por funcionalidad:**

```yaml
# ========================================
# Version and Installation
# ========================================

prometheus_install_method: apt
prometheus_version: latest

# ========================================
# Network Configuration
# ========================================

prometheus_listen_address: "0.0.0.0"
prometheus_port: 9090

# ========================================
# Exporters Scrape Config
# ========================================

prometheus_scrape_node_exporter: true
prometheus_node_exporter_port: 9100
```

---

## Templates

### Naming Convention

**Archivos de configuración**: `service_name.conf.j2` o `config_name.yml.j2`

```
templates/
├── prometheus.yml.j2
├── loki.yml.j2
├── nginx.conf.j2
└── php-fpm.conf.j2
```

**Scripts**: `script-name.sh.j2`

```
templates/
├── backup-prometheus.sh.j2
├── backup-loki.sh.j2
└── logrotate-prometheus.j2
```

**Servicios systemd**: `service_name.service.j2`

```
templates/
├── prometheus.service.j2
├── loki.service.j2
└── valkey_exporter.service.j2
```

### Header en Templates

```jinja
{#
  Template: prometheus.yml.j2
  Role: prometheus
  Purpose: Prometheus main configuration file
  Managed by Ansible - Do not edit manually
#}

# Prometheus Configuration
# Generated by Ansible on {{ ansible_date_time.iso8601 }}
# Managed by: {{ ansible_user }}@{{ ansible_host }}

global:
  scrape_interval: {{ prometheus_global_scrape_interval }}
  [...]
```

---

## Module Defaults y Package Variables

### Package Lists en defaults/main.yml

✅ **REGLA**: Todas las listas de paquetes deben estar definidas como variables en `defaults/main.yml`

**Propósito**: Facilitar la personalización, testing y mantenimiento. Permite overrides en inventory sin tocar código.

**Ejemplo:**

```yaml
# ansible/roles/grafana/defaults/main.yml
---
# ========================================
# Package Dependencies
# ========================================

grafana_apt_dependencies:
  - apt-transport-https
  - software-properties-common
  - wget
  - gpg

# GPG Key Configuration
grafana_gpg_key_url: https://apt.grafana.com/gpg.key
grafana_gpg_key_path: /etc/apt/keyrings/grafana.gpg
```

**Uso en tasks:**

```yaml
# ansible/roles/grafana/tasks/main.yml
- name: Install APT dependencies
  ansible.builtin.apt:
    name: "{{ grafana_apt_dependencies }}"
    state: present
    update_cache: true
```

### Module Defaults en Blocks

✅ **REGLA**: Usar `module_defaults` en blocks para DRY (Don't Repeat Yourself)

**Propósito**: Evitar repetir parámetros comunes en múltiples tasks del mismo módulo.

**ANTES (repetitivo):**

```yaml
- name: Install Grafana from APT repository
  block:
    - name: Install APT dependencies
      ansible.builtin.apt:
        name: "{{ grafana_apt_dependencies }}"
        state: present
        update_cache: true

    - name: Install Grafana
      ansible.builtin.apt:
        name: grafana
        state: present
        update_cache: true

    - name: Install additional packages
      ansible.builtin.apt:
        name: "{{ grafana_extra_packages }}"
        state: present
        update_cache: true
```

**DESPUÉS (DRY con module_defaults):**

```yaml
- name: Install Grafana from APT repository
  when: grafana_install_method == 'apt'
  module_defaults:
    ansible.builtin.apt:
      state: present
      update_cache: true
  block:
    - name: Install APT dependencies
      ansible.builtin.apt:
        name: "{{ grafana_apt_dependencies }}"

    - name: Install Grafana
      ansible.builtin.apt:
        name: "grafana{% if grafana_version != 'latest' %}={{ grafana_version }}{% endif %}"

    - name: Install additional packages
      ansible.builtin.apt:
        name: "{{ grafana_extra_packages }}"
```

**Beneficios:**

- ✅ Menos líneas de código (más limpio)
- ✅ Cambios centralizados (modificar `state` o `update_cache` en un solo lugar)
- ✅ Mejor legibilidad (foco en lo que varía entre tasks)
- ✅ Menos errores (imposible olvidar `update_cache` en una task)

### GPG Key Management (Modern Approach)

✅ **REGLA**: Usar `signed_by_key` con `ansible.builtin.uri` para fetch inline

**ANTES (verbose, múltiples tasks, archivos en filesystem):**

```yaml
- name: Download GPG key
  ansible.builtin.get_url:
    url: https://apt.grafana.com/gpg.key
    dest: /tmp/grafana.gpg.key

- name: Dearmor GPG key
  ansible.builtin.command:
    cmd: gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg /tmp/grafana.gpg.key
    creates: /etc/apt/keyrings/grafana.gpg

- name: Add repository
  ansible.builtin.deb822_repository:
    name: grafana
    types: [deb]
    uris: https://apt.grafana.com
    suites: stable
    components: [main]
    signed_by: /etc/apt/keyrings/grafana.gpg  # ⚠️ Archivo en filesystem
```

**DESPUÉS (limpio, sin archivos en filesystem):**

```yaml
- name: Fetch Grafana GPG key
  ansible.builtin.uri:
    url: "{{ grafana_gpg_key_url }}"
    return_content: true
  register: grafana_gpg_key_content

- name: Add Grafana APT repository (DEB822 format)
  ansible.builtin.deb822_repository:
    name: grafana
    types: [deb]
    uris: https://apt.grafana.com
    suites: stable
    components: [main]
    signed_by_key: "{{ grafana_gpg_key_content.content }}"  # ✅ Contenido inline
    state: present
```

**Ventajas:**

- ✅ No necesita crear `/etc/apt/keyrings/`
- ✅ No necesita `gpg --dearmor`
- ✅ No deja archivos en el filesystem
- ✅ Idempotente automáticamente (Ansible maneja cache)
- ✅ URL como variable en defaults
- ✅ Código más limpio y mantenible

### Ejemplo Completo: Grafana Role

**defaults/main.yml:**

```yaml
---
# ========================================
# Package Dependencies
# ========================================

grafana_apt_dependencies:
  - apt-transport-https
  - software-properties-common
  - wget
  - gpg

grafana_gpg_key_url: https://apt.grafana.com/gpg.key
grafana_gpg_key_path: /etc/apt/keyrings/grafana.gpg

# ========================================
# Version and Installation
# ========================================

grafana_version: 10.2.3
grafana_install_method: apt
```

**tasks/main.yml:**

```yaml
---
- name: Install Grafana from APT repository
  when: grafana_install_method == 'apt'
  module_defaults:
    ansible.builtin.apt:
      state: present
      update_cache: true
  block:
    - name: Install APT dependencies
      ansible.builtin.apt:
        name: "{{ grafana_apt_dependencies }}"

    - name: Fetch Grafana GPG key
      ansible.builtin.uri:
        url: "{{ grafana_gpg_key_url }}"
        return_content: true
      register: grafana_gpg_key_content

    - name: Add Grafana APT repository (DEB822 format)
      ansible.builtin.deb822_repository:
        name: grafana
        types: [deb]
        uris: https://apt.grafana.com
        suites: stable
        components: [main]
        signed_by_key: "{{ grafana_gpg_key_content.content }}"
        state: present

    - name: Install Grafana
      ansible.builtin.apt:
        name: "grafana{% if grafana_version != 'latest' %}={{ grafana_version }}{% endif %}"
```

**Resultado:**

- 🎯 Código limpio y mantenible
- 🎯 Fácil personalización (override en inventory)
- 🎯 DRY: parámetros comunes en `module_defaults`
- 🎯 Modern: GPG keys sin archivos temporales
- 🎯 Production-ready

---

## Handlers

### Naming Convention

**Formato**: `acción servicio` (lowercase)

**Ejemplos correctos:**

```yaml
# handlers/main.yml
---
- name: restart prometheus
  ansible.builtin.systemd:
    name: prometheus
    state: restarted
    daemon_reload: true

- name: reload prometheus
  ansible.builtin.systemd:
    name: prometheus
    state: reloaded

- name: restart nginx
  ansible.builtin.systemd:
    name: nginx
    state: restarted

- name: reload nginx
  ansible.builtin.systemd:
    name: nginx
    state: reloaded
```

### Uso de Handlers

```yaml
# tasks/main.yml
- name: prometheus | Deploy Prometheus configuration
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: /etc/prometheus/prometheus.yml
  notify: reload prometheus  # Handler se ejecuta al final

- name: prometheus | Deploy systemd service
  ansible.builtin.template:
    src: prometheus.service.j2
    dest: /etc/systemd/system/prometheus.service
  notify: restart prometheus
```

---

## Tags

### Tag Strategy

**Niveles de tags:**

1. **Role level**: Nombre del role
2. **Functionality level**: install, config, service, validate
3. **Component level**: packages, files, directories

**Ejemplos:**

```yaml
- name: prometheus | Install Prometheus
  ansible.builtin.apt:
    name: prometheus
    state: present
  tags: [prometheus, install, packages]

- name: prometheus | Deploy configuration
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: /etc/prometheus/prometheus.yml
  tags: [prometheus, config, files]

- name: prometheus | Start service
  ansible.builtin.systemd:
    name: prometheus
    state: started
  tags: [prometheus, service]
```

**Uso:**

```bash
# Ejecutar solo instalación
ansible-playbook site.yml --tags install

# Ejecutar solo configuración de prometheus
ansible-playbook site.yml --tags prometheus,config

# Saltar validaciones
ansible-playbook site.yml --skip-tags validate
```

---

## Roles Auditados y Corregidos

### ✅ Roles que siguen Best Practices

| Role | Variables | Tasks Names | Structure | Status |
|------|-----------|-------------|-----------|--------|
| **prometheus** | ✅ `prometheus_*` | ✅ `prometheus \|` | ✅ Modular | ✅ Completo |
| **node_exporter** | ✅ `node_exporter_*` | ✅ `node_exporter \|` | ✅ Simple | ✅ Completo |
| **loki** | ✅ `loki_*` | ✅ `loki \|` | ✅ Modular | ✅ Completo |
| **promtail** | ✅ `promtail_*` | ✅ `promtail \|` | ✅ Modular | ✅ Completo |
| **grafana** | ✅ `grafana_*` | ✅ `grafana \|` | ✅ Modular | ✅ Completo |
| **openbao** | ✅ `openbao_*` | ✅ `openbao \|` | ✅ Modular | ✅ Completo |
| **firewall** | ✅ `firewall_*` | ✅ `firewall \|` | ⚠️ Simple | ✅ Corregido |
| **mariadb** | ✅ `mariadb_*` | ⚠️ Pendiente | ⚠️ No tasks | ⚠️ Parcial |
| **nginx-wordpress** | ✅ `nginx_wordpress_*` | ⚠️ Pendiente | ⚠️ No tasks | ⚠️ Parcial |

### ⚠️ Roles pendientes de completar

| Role | Estado | Acciones Pendientes |
|------|--------|---------------------|
| **valkey** | 🔄 Recrear | Recrear con `ansible-galaxy role init` |
| **mariadb** | ⚠️ Parcial | Crear tasks siguiendo Best Practices |
| **nginx-wordpress** | ⚠️ Parcial | Crear tasks siguiendo Best Practices |

---

## Correcciones Realizadas

### 1. Firewall Role

**Cambios:**

- ✅ Creado `defaults/main.yml` (no existía)
- ✅ Renombrado `ufw_*` → `firewall_*`
- ✅ Añadido prefijo `firewall |` a todas las tasks
- ✅ Añadido control de deployment (`firewall_enabled`)

**Variables corregidas:**

```yaml
# ANTES
ufw_default_incoming_policy: deny
ufw_default_outgoing_policy: allow
ufw_allowed_ports: [...]

# DESPUÉS
firewall_default_incoming_policy: deny
firewall_default_outgoing_policy: allow
firewall_allowed_ports: [...]
```

### 2. MariaDB Role

**Cambios:**

- ✅ Renombrado `wordpress_db_*` → `mariadb_wordpress_db_*`
- ✅ Actualizado `vault_wordpress_db_password` → `vault_mariadb_wordpress_db_password`

**Variables corregidas:**

```yaml
# ANTES
wordpress_db_name: wordpress
wordpress_db_user: wordpress
wordpress_db_password: "{{ vault_wordpress_db_password }}"

# DESPUÉS
mariadb_wordpress_db_name: wordpress
mariadb_wordpress_db_user: wordpress
mariadb_wordpress_db_password: "{{ vault_mariadb_wordpress_db_password }}"
```

### 3. Nginx-WordPress Role

**Cambios:**

- ✅ Renombrado `wordpress_*` → `nginx_wordpress_*`
- ✅ Renombrado `php_*` → `nginx_wordpress_php_*`
- ✅ Renombrado `cloudflare_*` → `nginx_wordpress_cloudflare_*`
- ✅ Renombrado `tutor_*` → `nginx_wordpress_learndash_*` (correcto LMS)

**Variables corregidas (muestra):**

```yaml
# ANTES
wordpress_domain: example.com
wordpress_root: /var/www/wordpress
php_version: "8.3"
php_memory_limit: 256M
cloudflare_enabled: true
tutor_lms_enabled: true

# DESPUÉS
nginx_wordpress_domain: example.com
nginx_wordpress_root: /var/www/{{ nginx_wordpress_domain }}
nginx_wordpress_php_version: "8.3"
nginx_wordpress_php_memory_limit: 256M
nginx_wordpress_cloudflare_enabled: true
nginx_wordpress_learndash_lms_enabled: true
```

---

## Ansible.cfg Optimizado

```ini
[defaults]
inventory = inventory/production.yml
roles_path = ./roles:~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles
remote_user = admin
private_key_file = ~/.ssh/id_ed25519_sk
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600
stdout_callback = yaml
callbacks_enabled = timer, profile_tasks

[inventory]
enable_plugins = hcloud, yaml, ini

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
control_path = ~/.ssh/ansible-%%r@%%h:%%p
```

**Mejoras aplicadas:**

- ✅ Multiple `roles_path` para búsqueda flexible
- ✅ Smart gathering (cache de facts)
- ✅ YAML stdout para mejor legibilidad
- ✅ Timer y profile_tasks para debugging
- ✅ SSH pipelining para mejor performance

---

## Próximos Pasos

### Tareas Pendientes

1. ✅ ~~Corregir naming de variables~~
2. ⏳ Añadir prefijos `rolename |` a todas las tasks
3. ⏳ Recrear role Valkey con estructura correcta
4. ⏳ Implementar tasks para mariadb role
5. ⏳ Implementar tasks para nginx-wordpress role
6. ⏳ Validar con `ansible-lint`
7. ⏳ Estructurar roles complejos de forma modular

### Comando ansible-lint

```bash
# Validar role específico
ansible-lint ansible/roles/prometheus/

# Validar todos los roles
ansible-lint ansible/roles/

# Validar playbook
ansible-lint ansible/playbooks/site.yml

# Auto-fix issues (cuando sea posible)
ansible-lint --fix ansible/roles/prometheus/
```

---

## Referencias

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [Red Hat Ansible Automation Good Practices](https://redhat-cop.github.io/automation-good-practices/)
- [Ansible Lint Rules](https://ansible.readthedocs.io/projects/lint/rules/)
- [Role Skeleton](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html#role-skeleton)
- [YAML Best Practices](https://docs.ansible.com/ansible/latest/reference_appendices/YAMLSyntax.html)

---

**Última actualización**: 2026-01-09
**Estado**: 70% completo (variables corregidas, tasks names pendientes)
