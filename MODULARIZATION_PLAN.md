# Plan de Modularización - Ansible Roles Best Practices

**Fecha**: 2025-12-28
**Objetivo**: Aplicar Ansible y Red Hat CoP Best Practices a todos los roles
**Estado**: En progreso

---

## ✅ Roles Completados (100%)

### 1. Grafana
- ✅ Package variables en defaults/main.yml
- ✅ Module_defaults en blocks
- ✅ GPG key con `signed_by_key` (sin archivos filesystem)
- ✅ Código limpio y DRY

### 2. Prometheus
- ✅ Package variables en defaults/main.yml
- ✅ Module_defaults en blocks
- ✅ GPG key con `signed_by_key`
- ✅ Código limpio y DRY

### 3. Loki
- ✅ Package variables en defaults/main.yml
- ✅ Module_defaults en blocks
- ✅ GPG key con `signed_by_key`
- ✅ Código limpio y DRY

### 4. Node Exporter
- ✅ Package variables en defaults/main.yml
- ✅ Module_defaults en blocks
- ✅ GPG key con `signed_by_key`
- ✅ **Estructura modular**:
  - `main.yml` → Orchestrator
  - `install.yml` → Installation tasks
  - `configure.yml` → Configuration tasks
  - `service.yml` → Service management
  - `firewall.yml` → Firewall rules
  - `validate.yml` → Validation tasks
- ✅ Task naming: `rolename | taskfile | description`

---

## ⏳ Roles Pendientes de Modularizar

### 5. Promtail (224 líneas)
**Tareas a crear:**
- `install.yml` - APT installation, GPG key (signed_by_key), directories
- `configure.yml` - promtail.yml config, scrape configs
- `service.yml` - systemd service management
- `firewall.yml` - UFW rules
- `validate.yml` - Health checks

**Variables a añadir en defaults/main.yml:**
```yaml
promtail_apt_dependencies:
  - apt-transport-https
  - software-properties-common
  - wget
  - gpg

promtail_gpg_key_url: https://apt.grafana.com/gpg.key
```

**Main.yml orchestrator:**
```yaml
---
- name: promtail | main | Include installation tasks
  ansible.builtin.import_tasks: install.yml
  tags: [promtail, install]

- name: promtail | main | Include configuration tasks
  ansible.builtin.import_tasks: configure.yml
  tags: [promtail, config]

- name: promtail | main | Include service tasks
  ansible.builtin.import_tasks: service.yml
  tags: [promtail, service]

- name: promtail | main | Include firewall tasks
  ansible.builtin.import_tasks: firewall.yml
  tags: [promtail, firewall]

- name: promtail | main | Include validation tasks
  ansible.builtin.import_tasks: validate.yml
  tags: [promtail, validate]
```

### 6. OpenBao (210 líneas)
**Tareas a crear:**
- `install.yml` - Binary download, user creation, directories
- `configure.yml` - config.hcl, TLS certificates
- `service.yml` - systemd service
- `unseal.yml` - Vault unsealing logic
- `firewall.yml` - UFW rules
- `validate.yml` - Health checks

**Variables a añadir:**
```yaml
openbao_dependencies:
  - unzip
  - jq
  - curl
```

### 7. Firewall (58 líneas)
**Tareas a crear:**
- `install.yml` - Install UFW
- `configure.yml` - Default policies, logging
- `rules.yml` - Apply firewall rules
- `validate.yml` - Verify UFW status

**Ya tiene variables correctas** con prefijo `firewall_`

---

## 📋 Patrón de Modularización

### Estructura de Directorios
```
role_name/
├── defaults/
│   └── main.yml          # Package variables, GPG URLs
├── tasks/
│   ├── main.yml          # Orchestrator (import_tasks)
│   ├── install.yml       # Installation tasks
│   ├── configure.yml     # Configuration tasks
│   ├── service.yml       # Service management
│   ├── firewall.yml      # Firewall rules (if needed)
│   └── validate.yml      # Validation tasks
├── templates/
├── handlers/
│   └── main.yml
└── vars/
```

### Task Naming Convention
```yaml
# En main.yml (orchestrator)
- name: rolename | main | Include installation tasks

# En install.yml
- name: rolename | install | Install APT dependencies
- name: rolename | install | Fetch GPG key
- name: rolename | install | Add repository

# En configure.yml
- name: rolename | configure | Deploy configuration file
- name: rolename | configure | Set permissions

# En service.yml
- name: rolename | service | Enable and start service

# En firewall.yml
- name: rolename | firewall | Allow service port

# En validate.yml
- name: rolename | validate | Wait for service to be ready
- name: rolename | validate | Display status
```

### Package Variables Pattern
```yaml
# defaults/main.yml
---
# ========================================
# Package Dependencies
# ========================================

rolename_apt_dependencies:
  - apt-transport-https
  - software-properties-common
  - wget
  - gpg

# GPG Key Configuration
rolename_gpg_key_url: https://example.com/gpg.key
```

### Module Defaults Pattern
```yaml
# tasks/install.yml
- name: rolename | install | Install from APT repository
  when: rolename_install_method == 'apt'
  module_defaults:
    ansible.builtin.apt:
      state: present
      update_cache: true
  block:
    - name: rolename | install | Install APT dependencies
      ansible.builtin.apt:
        name: "{{ rolename_apt_dependencies }}"

    - name: rolename | install | Fetch GPG key
      ansible.builtin.uri:
        url: "{{ rolename_gpg_key_url }}"
        return_content: true
      register: rolename_gpg_key_content

    - name: rolename | install | Add repository
      ansible.builtin.deb822_repository:
        name: rolename
        types: [deb]
        uris: https://repository.url
        suites: stable
        components: [main]
        signed_by_key: "{{ rolename_gpg_key_content.content }}"
        state: present

    - name: rolename | install | Install package
      ansible.builtin.apt:
        name: "package{% if rolename_version != 'latest' %}={{ rolename_version }}{% endif %}"
```

---

## 🎯 Beneficios de la Modularización

### 1. DRY (Don't Repeat Yourself)
- ✅ Module_defaults evita repetir `state: present`, `update_cache: true`
- ✅ Package lists en defaults permite override fácil
- ✅ GPG key handling sin duplicar código

### 2. Separación de Responsabilidades
- ✅ Cada archivo hace UNA cosa
- ✅ Fácil encontrar dónde modificar
- ✅ Testing granular con tags

### 3. Mantenibilidad
- ✅ Código más limpio y legible
- ✅ Main.yml como índice claro
- ✅ Fácil añadir nuevas tareas

### 4. Testing Granular
```bash
# Ejecutar solo instalación
ansible-playbook site.yml --tags install

# Ejecutar solo configuración de un role
ansible-playbook site.yml --tags "promtail,config"

# Re-ejecutar solo validación
ansible-playbook site.yml --tags validate
```

### 5. Debugging Mejorado
```
TASK [promtail | install | Install APT dependencies] **************
TASK [promtail | configure | Deploy configuration] ****************
TASK [promtail | service | Enable service] ************************
```

Inmediatamente sabes:
- **Qué role**: promtail
- **Qué fase**: configure
- **Qué task**: Deploy configuration

---

## ✅ Checklist de Implementación

Para cada role:

- [ ] **Backup**: `cp tasks/main.yml tasks/main.yml.backup`
- [ ] **Defaults**: Añadir package variables y GPG URL
- [ ] **Install.yml**:
  - Module_defaults con ansible.builtin.apt
  - Fetch GPG con ansible.builtin.uri
  - signed_by_key (NO signed_by)
  - Install package
- [ ] **Configure.yml**: Deploy templates, set permissions
- [ ] **Service.yml**: Enable and start systemd service
- [ ] **Firewall.yml**: UFW rules (si aplica)
- [ ] **Validate.yml**: Health checks, display status
- [ ] **Main.yml**: Orchestrator con import_tasks
- [ ] **Syntax check**: `ansible-playbook site.yml --syntax-check`
- [ ] **Task naming**: Verificar formato `role | taskfile | description`

---

## 🚀 Próximos Pasos

1. **Completar Promtail** (prioridad alta)
   - Modularizar tasks siguiendo el patrón
   - Aplicar module_defaults
   - GPG key con signed_by_key

2. **Completar OpenBao** (prioridad alta)
   - Modularizar tasks
   - Unseal logic en archivo separado
   - Validación de vault status

3. **Completar Firewall** (prioridad media)
   - Ya tiene variables correctas
   - Solo modularizar estructura

4. **Validación Final**
   - Syntax check de todos los roles
   - ansible-lint en todos los roles
   - Documentar en ANSIBLE_BEST_PRACTICES.md

---

## 📊 Progreso

- **Roles completados**: 4/7 (57%)
- **Roles pendientes**: 3/7 (43%)
- **Líneas modularizadas**: ~600
- **Líneas pendientes**: ~500

**Fecha objetivo**: 31 Diciembre 2024 (antes del deployment del 2 Enero)

---

**Última actualización**: 2025-12-28 14:00 UTC
