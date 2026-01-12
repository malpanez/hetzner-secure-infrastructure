# OpenBao Post-Deployment Guide

**Última actualización:** 2026-01-11
**Estado:** Opcional (puede desplegarse en servidor WordPress o servidor dedicado)

---

## 📋 Tabla de Contenidos

1. [¿Qué es OpenBao?](#qué-es-openbao)
2. [¿Cuándo usar OpenBao?](#cuándo-usar-openbao)
3. [Arquitectura de Deployment](#arquitectura-de-deployment)
4. [Inicialización Post-Deployment](#inicialización-post-deployment)
5. [Casos de Uso](#casos-de-uso)
6. [Desactivar OpenBao](#desactivar-openbao)

---

## ¿Qué es OpenBao?

OpenBao es un fork open-source de HashiCorp Vault mantenido por la Linux Foundation. Proporciona:

- ✅ **Gestión de secretos** - Almacenamiento seguro de passwords, API keys, certificates
- ✅ **Rotación automática** - Cambio periódico de credenciales
- ✅ **Auditoría** - Logs de acceso a secretos
- ✅ **Cifrado** - Datos encriptados en reposo y tránsito

---

## ¿Cuándo usar OpenBao?

### ✅ USAR OpenBao cuando:

1. **Múltiples servicios necesitan secretos** (ej: WordPress, API externa, backups)
2. **Rotación automática de passwords** (ej: MySQL, Valkey)
3. **Compliance o auditoría** requerida
4. **Múltiples administradores** necesitan acceso controlado

### ⚠️ NO USAR OpenBao cuando:

1. **Infraestructura simple** (1 servidor, 1 WordPress)
2. **Pocos secretos** (solo root password de DB)
3. **No hay requisitos de auditoría**
4. **Presupuesto ajustado** (OpenBao añade complejidad)

**Recomendación para este proyecto**: Empezar SIN OpenBao. Añadirlo cuando la infraestructura crezca.

---

## Arquitectura de Deployment

### Opción 1: OpenBao en Servidor WordPress (DEFAULT)

```
┌─────────────────────────────────┐
│ CAX11 ARM64 (€4.66/mes)        │
│ ├── WordPress + MariaDB         │
│ ├── Nginx + PHP 8.4             │
│ ├── Valkey 8.0                  │
│ ├── Prometheus + Grafana        │
│ └── OpenBao OSS (opcional)      │
└─────────────────────────────────┘
```

**Pros:**
- Sin coste adicional
- Configuración simplificada
- Suficiente para 1-2 servicios

**Contras:**
- Recursos compartidos con WordPress
- Menos aislamiento de seguridad

### Opción 2: OpenBao en Servidor Dedicado

```
┌──────────────┐  ┌──────────────────────┐
│  WordPress   │  │  Monitoring+Secrets  │
│  + Database  │  │  Prometheus+Grafana  │
│  CAX11 €4.66 │  │  OpenBao OSS         │
│  (ARM64)     │  │  CAX11 €4.66         │
└──────────────┘  │  (ARM64)             │
                  └──────────────────────┘
```

**Pros:**
- Mejor aislamiento
- No afecta performance de WordPress
- Escalable para múltiples servicios

**Contras:**
- Coste adicional: +€4.66/mes
- Mayor complejidad de red

**Recomendación**: Solo cuando tengas +3 servicios usando secretos.

---

## Inicialización Post-Deployment

### 1. Verificar que OpenBao está instalado

```bash
# SSH al servidor
ssh malpanez@YOUR_SERVER_IP

# Verificar servicio
sudo systemctl status openbao

# Debe mostrar: active (running)
```

### 2. Inicializar OpenBao (SOLO PRIMERA VEZ)

```bash
# Inicializar vault
sudo bao operator init -key-shares=5 -key-threshold=3

# IMPORTANTE: Guardar output en lugar SEGURO (Password manager)
# Output ejemplo:
# Unseal Key 1: <KEY_1>
# Unseal Key 2: <KEY_2>
# Unseal Key 3: <KEY_3>
# Unseal Key 4: <KEY_4>
# Unseal Key 5: <KEY_5>
# Initial Root Token: <ROOT_TOKEN>
```

⚠️ **CRÍTICO**: Guarda las 5 unseal keys y el root token en tu password manager. Sin ellas, NO podrás acceder a OpenBao nunca más.

### 3. Unseal OpenBao

```bash
# Unseal con 3 de las 5 keys (threshold=3)
sudo bao operator unseal <KEY_1>
sudo bao operator unseal <KEY_2>
sudo bao operator unseal <KEY_3>

# Verificar estado
sudo bao status
# Debe mostrar: Sealed: false
```

### 4. Login con Root Token

```bash
# Exportar token
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='<ROOT_TOKEN>'

# Login
bao login $VAULT_TOKEN
```

---

## Casos de Uso

### Ejemplo 1: Almacenar Password de MySQL

```bash
# Habilitar secrets engine
bao secrets enable -path=wordpress kv-v2

# Guardar password
bao kv put wordpress/mysql \
  root_password="tu_password_mysql_seguro" \
  wp_user="wordpress" \
  wp_password="tu_password_wordpress"

# Leer password
bao kv get wordpress/mysql
```

### Ejemplo 2: Rotación Automática de MySQL Password

```bash
# Habilitar database secrets engine
bao secrets enable database

# Configurar conexión MySQL
bao write database/config/wordpress \
  plugin_name=mysql-database-plugin \
  connection_url="{{username}}:{{password}}@tcp(localhost:3306)/" \
  allowed_roles="wordpress-app" \
  username="root" \
  password="$MYSQL_ROOT_PASSWORD"

# Crear rol con rotación cada 24h
bao write database/roles/wordpress-app \
  db_name=wordpress \
  creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON wordpress.* TO '{{name}}'@'%';" \
  default_ttl="24h" \
  max_ttl="24h"

# Obtener credenciales temporales (válidas 24h)
bao read database/creds/wordpress-app
```

### Ejemplo 3: API Keys para WordPress Plugins

```bash
# Guardar API keys
bao kv put wordpress/api_keys \
  cloudflare_token="tu_token" \
  smtp_password="tu_smtp_pass" \
  stripe_api_key="tu_stripe_key"

# WordPress puede leer desde CLI
bao kv get -field=cloudflare_token wordpress/api_keys
```

---

## Desactivar OpenBao

Si decides NO usar OpenBao:

### Método 1: Deshabilitar servicio (recomendado)

```bash
# Detener servicio
sudo systemctl stop openbao
sudo systemctl disable openbao

# Libera ~100MB RAM
```

### Método 2: No desplegar OpenBao desde inicio

En `ansible/inventory/production.yml`:

```yaml
secrets_servers:
  hosts:
    openbao-prod:
      ansible_host: ""  # Dejar vacío = no desplegar
      deploy_openbao: false
```

---

## Comandos Útiles

### Verificar Estado

```bash
# Estado del servicio
sudo systemctl status openbao

# Estado del vault
bao status

# Listar secretos
bao kv list wordpress/
```

### Backup de OpenBao

```bash
# Backup manual
sudo systemctl stop openbao
sudo tar czf /backup/openbao-$(date +%Y%m%d).tar.gz /opt/openbao/data/
sudo systemctl start openbao
```

### Troubleshooting

```bash
# Ver logs
sudo journalctl -u openbao -f

# Reiniciar servicio
sudo systemctl restart openbao

# Unseal después de reinicio
bao operator unseal <KEY_1>
bao operator unseal <KEY_2>
bao operator unseal <KEY_3>
```

---

## Recursos

- **Documentación oficial**: https://openbao.org/docs/
- **GitHub**: https://github.com/openbao/openbao
- **Tutorial Vault (compatible)**: https://developer.hashicorp.com/vault/tutorials

---

## Decisión Recomendada

Para un sitio WordPress pequeño-mediano:

1. **Inicialmente**: NO usar OpenBao (demasiada complejidad)
2. **Secretos básicos**: Ansible Vault es suficiente
3. **Cuando escalar**: Añadir OpenBao si tienes +3 servicios o requisitos de compliance

**Regla práctica**: Si no sabes si necesitas OpenBao, probablemente NO lo necesitas (todavía).
