# Monitoring Architecture

> **Arquitectura completa de monitorización con Prometheus y Grafana**

## Table of Contents

- [Arquitectura General](#arquitectura-general)
- [Opciones de Despliegue](#opciones-de-despliegue)
- [Opción 1: Servidor Dedicado (Recomendado)](#opción-1-servidor-dedicado-recomendado)
- [Opción 2: Mismo Servidor (Dev/Testing)](#opción-2-mismo-servidor-devtesting)
- [Opción 3: Servicios Externos (Cloud)](#opción-3-servicios-externos-cloud)
- [Configuración Paso a Paso](#configuración-paso-a-paso)

---

## Arquitectura General

### ¿Dónde va Prometheus y Grafana?

**Tienes 3 opciones principales:**

#### Opción 1: Servidor Dedicado (Recomendado para Producción)

```mermaid
graph TB
    subgraph monitoring["🖥️ Monitoring Server (cx11)"]
        prom["📊 Prometheus<br/>:9090"]
        graf["📈 Grafana<br/>:3000"]
        alert["🔔 Alertmanager<br/>:9093"]
    end

    subgraph app1["🖥️ App Server 1"]
        node1["📡 Node Exporter<br/>:9100"]
        app_1["⚙️ Application"]
    end

    subgraph app2["🖥️ App Server 2"]
        node2["📡 Node Exporter<br/>:9100"]
        app_2["⚙️ Application"]
    end

    node1 -->|metrics| prom
    node2 -->|metrics| prom
    prom --> graf
    prom --> alert

    style monitoring fill:#e1f5e1
    style app1 fill:#e3f2fd
    style app2 fill:#e3f2fd
    style prom fill:#4caf50,color:#fff
    style graf fill:#ff9800,color:#fff
```

#### Opción 2: Mismo Servidor (Dev/Testing)

```mermaid
graph TB
    subgraph server["🖥️ Single Hetzner Server"]
        app["⚙️ Application<br/>:80, :443"]
        prom["📊 Prometheus<br/>:9090"]
        graf["📈 Grafana<br/>:3000"]
        node["📡 Node Exporter<br/>:9100"]
    end

    node -->|metrics| prom
    prom --> graf

    style server fill:#fff3e0
    style app fill:#2196f3,color:#fff
    style prom fill:#4caf50,color:#fff
    style graf fill:#ff9800,color:#fff
```

#### Opción 3: Grafana Cloud (Startups/MVP)

```mermaid
graph LR
    subgraph servers["🖥️ Hetzner Servers"]
        subgraph app1["App Server 1"]
            agent1["🔄 Grafana Agent<br/>(push mode)"]
            app_1["⚙️ Application"]
        end

        subgraph app2["App Server 2"]
            agent2["🔄 Grafana Agent<br/>(push mode)"]
            app_2["⚙️ Application"]
        end
    end

    subgraph cloud["☁️ Grafana Cloud<br/>(grafana.com)"]
        prom_cloud["📊 Prometheus"]
        graf_cloud["📈 Grafana"]
        loki_cloud["📝 Loki (Logs)"]
        alert_cloud["🔔 Alerting"]
    end

    agent1 -->|push| prom_cloud
    agent2 -->|push| prom_cloud
    agent1 -->|logs| loki_cloud
    agent2 -->|logs| loki_cloud
    prom_cloud --> graf_cloud
    prom_cloud --> alert_cloud

    style cloud fill:#e8f5e9
    style servers fill:#e3f2fd
    style prom_cloud fill:#4caf50,color:#fff
    style graf_cloud fill:#ff9800,color:#fff
```

---

## Opciones de Despliegue

### Comparación

| Aspecto | Opción 1: Dedicado | Opción 2: Mismo Server | Opción 3: Cloud |
|---------|-------------------|----------------------|----------------|
| **Costo** | ~€5/mes extra | €0 | €0 (free tier) |
| **Complejidad** | Media | Baja | Baja |
| **Escalabilidad** | Excelente | Limitada | Excelente |
| **Rendimiento** | Excelente | Puede afectar app | Excelente |
| **Seguridad** | Aislado | Compartido | Depende del proveedor |
| **Mantenimiento** | Manual | Manual | Gestionado |
| **Recomendado para** | Producción | Dev/Testing | Startups, MVP |

---

## Opción 1: Servidor Dedicado (Recomendado)

### Ventajas
- ✅ Aislamiento completo (monitoreo no afecta aplicaciones)
- ✅ Puede monitorear múltiples servidores
- ✅ Escalable (agrega más servidores monitoreados)
- ✅ Mejor seguridad (firewall dedicado)

### Desventajas
- ❌ Costo adicional (~€4.51/mes para cx11)
- ❌ Más infraestructura que gestionar

### Cuándo usar
- Producción con múltiples servidores
- Cuando el monitoreo es crítico
- Equipos profesionales

### Arquitectura Detallada

```mermaid
graph TB
    subgraph monitoring["🖥️ Monitoring Server (cx11 - €4.51/mes)"]
        direction TB
        prom["📊 Prometheus :9090<br/>━━━━━━━━━━━━━━━<br/>• Scrape: 15s<br/>• Retention: 15d<br/>• Storage: ~5GB"]
        graf["📈 Grafana :3000<br/>━━━━━━━━━━━━━━━<br/>• Dashboard 1860<br/>• Dashboard 11074<br/>• Custom alerts"]
        alert["🔔 Alertmanager :9093<br/>━━━━━━━━━━━━━━━<br/>• Email<br/>• Slack/Discord<br/>• PagerDuty"]
        loki["📝 Loki :3100<br/>━━━━━━━━━━━━━━━<br/>• Log aggregation<br/>• Optional"]

        prom --> graf
        prom --> alert
        prom -.-> loki
    end

    subgraph servers["🌐 Monitored Servers"]
        direction LR
        server1["🖥️ App Server 1<br/>Node Exporter :9100"]
        server2["🖥️ App Server 2<br/>Node Exporter :9100"]
        serverN["🖥️ App Server N<br/>Node Exporter :9100"]
    end

    server1 -->|metrics every 15s| prom
    server2 -->|metrics every 15s| prom
    serverN -->|metrics every 15s| prom

    style monitoring fill:#e8f5e9
    style servers fill:#e3f2fd
    style prom fill:#4caf50,color:#fff
    style graf fill:#ff9800,color:#fff
    style alert fill:#f44336,color:#fff
    style loki fill:#9c27b0,color:#fff
```

**Componentes del Monitoring Server:**

| Componente | Puerto | Descripción | Configuración |
|------------|--------|-------------|---------------|
| **Prometheus** | 9090 | Time-series database | Scrape: 15s, Retention: 15d |
| **Grafana** | 3000 | Visualization & dashboards | Dashboards: 1860, 11074 |
| **Alertmanager** | 9093 | Alert routing & notification | Email, Slack, PagerDuty |
| **Loki** | 3100 | Log aggregation (opcional) | Centralized logging |
| **Node Exporter** | 9100 | Self-monitoring | Monitors the monitoring server |

---

## Opción 2: Mismo Servidor (Dev/Testing)

### Ventajas
- ✅ Sin costo adicional
- ✅ Configuración simple
- ✅ Ideal para desarrollo y pruebas

### Desventajas
- ❌ Recursos compartidos con la aplicación
- ❌ Si el servidor cae, pierdes el monitoreo
- ❌ No escala para múltiples servidores

### Cuándo usar
- Entorno de desarrollo
- Proyectos pequeños (1 servidor)
- Aprendizaje y experimentación
- Presupuesto limitado

### Configuración

```yaml
# ansible/playbooks/monitoring-standalone.yml
---
- name: Setup monitoring on same server
  hosts: all
  become: yes

  roles:
    - monitoring      # Instala Node Exporter
    - prometheus      # Instala Prometheus
    - grafana         # Instala Grafana
```

---

## Opción 3: Servicios Externos (Cloud)

### Grafana Cloud (Recomendado para cloud)

**Free Tier incluye:**
- ✅ 10,000 series de métricas
- ✅ 50 GB de logs
- ✅ 50 GB de traces
- ✅ 14 días de retención
- ✅ Grafana alojado
- ✅ Prometheus alojado
- ✅ Loki (logs) alojado

**Ventajas:**
- ✅ Gratis hasta cierto límite
- ✅ Sin mantenimiento de infraestructura
- ✅ Escalado automático
- ✅ Backups incluidos
- ✅ Alerting avanzado

**Desventajas:**
- ❌ Dependencia de terceros
- ❌ Datos fuera de tu infraestructura
- ❌ Costo si superas free tier

### Alternativas Cloud

1. **Datadog** - Muy completo, caro ($15+/host/mes)
2. **New Relic** - Free tier generoso
3. **Netdata Cloud** - Free hasta 5 nodos
4. **Elastic Cloud** - Elastic Stack hosted

---

## Configuración Paso a Paso

### OPCIÓN 1: Servidor Dedicado de Monitoring

#### Paso 1: Crear servidor de monitoreo con Terraform

```hcl
# terraform/environments/production/monitoring-server.tf

module "monitoring_server" {
  source = "../../modules/hetzner-server"

  server_name    = "monitoring-01"
  server_type    = "cx11"  # Suficiente para ~10 servidores
  image          = "debian-12"
  location       = "nbg1"
  environment    = "production"
  admin_username = "admin"

  ssh_public_key = var.ssh_public_key

  # Firewall para monitoreo
  create_firewall = true
  ssh_allowed_ips = var.ssh_allowed_ips

  additional_ports = [
    {
      protocol   = "tcp"
      port       = "9090"  # Prometheus
      source_ips = var.monitoring_allowed_ips
    },
    {
      protocol   = "tcp"
      port       = "3000"  # Grafana
      source_ips = ["0.0.0.0/0", "::/0"]  # Acceso público a Grafana
    },
    {
      protocol   = "tcp"
      port       = "9093"  # Alertmanager
      source_ips = var.monitoring_allowed_ips
    }
  ]

  labels = {
    role    = "monitoring"
    project = "infrastructure"
  }

  prevent_destroy = true
}
```

#### Paso 2: Desplegar con Terraform

```bash
cd terraform/environments/production
tofu apply
```

#### Paso 3: Crear rol de Ansible para Prometheus/Grafana

```bash
# Crear estructura de roles
cd ansible/roles
mkdir -p prometheus/{tasks,templates,defaults}
mkdir -p grafana/{tasks,templates,defaults}
```

**ansible/roles/prometheus/tasks/main.yml:**

```yaml
---
- name: Install Prometheus
  ansible.builtin.apt:
    name: prometheus
    state: present
    update_cache: yes

- name: Configure Prometheus
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: /etc/prometheus/prometheus.yml
    owner: prometheus
    group: prometheus
    mode: '0644'
  notify: restart prometheus

- name: Ensure Prometheus is running
  ansible.builtin.systemd:
    name: prometheus
    state: started
    enabled: yes

- name: Allow Prometheus port
  community.general.ufw:
    rule: allow
    port: 9090
    proto: tcp
    from_ip: "{{ item }}"
  loop: "{{ prometheus_allowed_ips }}"
```

**ansible/roles/prometheus/templates/prometheus.yml.j2:**

```yaml
# Prometheus Configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'hetzner-monitoring'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Monitoring server
  - job_name: 'monitoring-server'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'monitoring-01'

  # Application servers
  - job_name: 'app-servers'
    static_configs:
{% for host in groups['hetzner'] %}
      - targets: ['{{ hostvars[host]['ansible_default_ipv4']['address'] }}:9100']
        labels:
          instance: '{{ host }}'
          environment: '{{ hostvars[host]['environment'] | default('production') }}'
{% endfor %}
```

**ansible/roles/grafana/tasks/main.yml:**

```yaml
---
- name: Add Grafana GPG key
  ansible.builtin.apt_key:
    url: https://apt.grafana.com/gpg.key
    state: present

- name: Add Grafana repository
  ansible.builtin.apt_repository:
    repo: deb https://apt.grafana.com stable main
    state: present
    filename: grafana

- name: Install Grafana
  ansible.builtin.apt:
    name: grafana
    state: present
    update_cache: yes

- name: Configure Grafana
  ansible.builtin.template:
    src: grafana.ini.j2
    dest: /etc/grafana/grafana.ini
    owner: root
    group: grafana
    mode: '0640'
  notify: restart grafana

- name: Ensure Grafana is running
  ansible.builtin.systemd:
    name: grafana-server
    state: started
    enabled: yes

- name: Allow Grafana port
  community.general.ufw:
    rule: allow
    port: 3000
    proto: tcp
```

#### Paso 4: Playbook de monitoring

**ansible/playbooks/setup-monitoring-server.yml:**

```yaml
---
- name: Setup dedicated monitoring server
  hosts: monitoring
  become: yes

  roles:
    - common
    - security-hardening
    - firewall
    - ssh-2fa
    - monitoring         # Node Exporter para self-monitoring
    - prometheus         # Prometheus server
    - grafana            # Grafana
    # - alertmanager     # Opcional
    # - loki             # Opcional
```

#### Paso 5: Inventario

**ansible/inventory/group_vars/monitoring.yml:**

```yaml
---
# Monitoring server configuration

prometheus_allowed_ips:
  - "10.0.0.0/8"      # Internal network
  - "YOUR_OFFICE_IP"  # Your office

grafana_admin_password: "{{ vault_grafana_password }}"  # Use ansible-vault

# Servidores a monitorear
monitored_servers:
  - name: app-server-1
    ip: 10.0.1.10
    port: 9100
  - name: app-server-2
    ip: 10.0.1.11
    port: 9100
```

#### Paso 6: Desplegar monitoring

```bash
cd ansible

# Configurar servidor de monitoreo
ansible-playbook -i inventory/hetzner.yml playbooks/setup-monitoring-server.yml

# Configurar Node Exporter en servidores de aplicación
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags monitoring
```

#### Paso 7: Acceder a Grafana

```bash
# Obtener IP del servidor de monitoreo
cd terraform/environments/production
tofu output monitoring_server_ip

# Acceder a Grafana
open http://MONITORING_IP:3000

# Login inicial:
# User: admin
# Password: admin (cambiar en primer login)
```

#### Paso 8: Configurar Grafana

1. **Add Data Source**
   - Go to Configuration → Data Sources
   - Click "Add data source"
   - Select "Prometheus"
   - URL: `http://localhost:9090`
   - Click "Save & Test"

2. **Import Dashboards**
   - Go to Dashboards → Import
   - Enter dashboard ID: `1860` (Node Exporter Full)
   - Select Prometheus data source
   - Click "Import"

3. **Create Alerts**
   - Go to Alerting → Alert rules
   - Create rules for:
     - High CPU usage
     - High memory usage
     - Disk space low
     - Server down

---

### OPCIÓN 2: Mismo Servidor (Simplificado)

```bash
cd ansible

# Instalar todo en el mismo servidor
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags monitoring,prometheus,grafana

# Acceder
open http://YOUR_SERVER_IP:3000
```

---

### OPCIÓN 3: Grafana Cloud

#### Paso 1: Crear cuenta en Grafana Cloud

1. Ir a https://grafana.com/auth/sign-up/create-user
2. Crear cuenta gratuita
3. Obtener API key y endpoint

#### Paso 2: Configurar Grafana Agent en servidores

**ansible/roles/grafana-agent/tasks/main.yml:**

```yaml
---
- name: Download Grafana Agent
  ansible.builtin.get_url:
    url: https://github.com/grafana/agent/releases/latest/download/grafana-agent-linux-amd64.zip
    dest: /tmp/grafana-agent.zip

- name: Install Grafana Agent
  ansible.builtin.unarchive:
    src: /tmp/grafana-agent.zip
    dest: /usr/local/bin
    remote_src: yes

- name: Configure Grafana Agent
  ansible.builtin.template:
    src: agent-config.yaml.j2
    dest: /etc/grafana-agent.yaml
    mode: '0644'

- name: Create systemd service
  ansible.builtin.copy:
    src: grafana-agent.service
    dest: /etc/systemd/system/grafana-agent.service
    mode: '0644'

- name: Start Grafana Agent
  ansible.builtin.systemd:
    name: grafana-agent
    state: started
    enabled: yes
```

**ansible/roles/grafana-agent/templates/agent-config.yaml.j2:**

```yaml
server:
  log_level: info

metrics:
  global:
    scrape_interval: 60s
    remote_write:
      - url: {{ grafana_cloud_prometheus_url }}
        basic_auth:
          username: {{ grafana_cloud_prometheus_username }}
          password: {{ grafana_cloud_api_key }}

  configs:
    - name: hosted-prometheus
      scrape_configs:
        - job_name: 'node'
          static_configs:
            - targets: ['localhost:9100']
              labels:
                instance: '{{ inventory_hostname }}'
                environment: '{{ environment }}'

integrations:
  node_exporter:
    enabled: true
```

---

## Costos Estimados

### Opción 1: Servidor Dedicado

```
Servidor monitoring (cx11):    €4.51/mes
Servidores aplicación (cx11):  €4.51/mes × N servers
─────────────────────────────────────────
Total (1 app + 1 monitoring):  €9.02/mes
Total (3 app + 1 monitoring):  €18.04/mes
```

### Opción 2: Mismo Servidor

```
Servidor único (cx11):         €4.51/mes
─────────────────────────────────────────
Total:                         €4.51/mes
```

### Opción 3: Grafana Cloud

```
Free tier:                     €0/mes (hasta 10k series)
Servidores aplicación (cx11):  €4.51/mes × N servers
─────────────────────────────────────────
Total (3 app servers):         €13.53/mes
```

---

## Recomendaciones

### Para Producción
✅ **Opción 1: Servidor Dedicado**
- Separa monitoreo de aplicaciones
- Escalable y confiable
- ~€5/mes extra bien invertidos

### Para Desarrollo/Testing
✅ **Opción 2: Mismo Servidor**
- Sin costo adicional
- Suficiente para pruebas

### Para Startups/MVP
✅ **Opción 3: Grafana Cloud**
- Sin infraestructura adicional
- Free tier generoso
- Upgradable cuando crezcas

---

## Próximos Pasos

1. **Decidir arquitectura** según tu caso de uso
2. **Desplegar infraestructura** con Terraform
3. **Configurar Ansible roles** para Prometheus/Grafana
4. **Importar dashboards** en Grafana
5. **Configurar alertas** para métricas críticas
6. **Documentar runbooks** de respuesta a alertas

---

**Recomendación Personal:** Empieza con **Opción 2** para desarrollo, y cuando tengas múltiples servidores en producción, migra a **Opción 1** (servidor dedicado).
