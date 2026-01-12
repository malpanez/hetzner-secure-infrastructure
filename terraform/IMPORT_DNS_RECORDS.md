# Importar Registros DNS Existentes

## Problema

Terraform intenta crear registros DNS que ya existen en Cloudflare, causando error:

```
Error: expected DNS record to not already be present but already exists
with module.cloudflare[0].cloudflare_record.www
```

## Solución: Importar Registros Existentes

### Paso 1: Configurar Token

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform/environments/production

export CLOUDFLARE_API_TOKEN="tu_token_aqui"
export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
export ZONE_ID="00b35219c140d12c739f52a894ba91e2"
```

### Paso 2: Listar Registros Existentes

```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[] | "\(.type)\t\(.name)\t\(.id)"'
```

**Output esperado**:
```
A       twomindstrading.com         <ROOT_ID>
CNAME   www.twomindstrading.com     <WWW_ID>
A       grafana.twomindstrading.com <GRAFANA_ID>
A       prometheus.twomindstrading.com <PROMETHEUS_ID>
```

### Paso 3: Importar Registros

Copia los IDs del paso anterior y ejecuta:

```bash
# Importar root (@)
terraform import 'module.cloudflare[0].cloudflare_record.root' ${ZONE_ID}/<ROOT_ID>

# Importar www
terraform import 'module.cloudflare[0].cloudflare_record.www' ${ZONE_ID}/<WWW_ID>

# Importar grafana
terraform import 'module.cloudflare[0].cloudflare_record.grafana' ${ZONE_ID}/<GRAFANA_ID>

# Importar prometheus
terraform import 'module.cloudflare[0].cloudflare_record.prometheus' ${ZONE_ID}/<PROMETHEUS_ID>
```

**Ejemplo completo**:
```bash
terraform import 'module.cloudflare[0].cloudflare_record.root' 00b35219c140d12c739f52a894ba91e2/81af5b8a737ac1938a9385de45e7447a
terraform import 'module.cloudflare[0].cloudflare_record.www' 00b35219c140d12c739f52a894ba91e2/54c4b9daf22889c39e1addd04e9208c8
terraform import 'module.cloudflare[0].cloudflare_record.grafana' 00b35219c140d12c739f52a894ba91e2/d32291e7e34674b12302538f0d0f26f1
terraform import 'module.cloudflare[0].cloudflare_record.prometheus' 00b35219c140d12c739f52a894ba91e2/f1e2d3c4b5a69780c1d2e3f4a5b6c7d8
```

### Paso 4: Verificar Import

```bash
terraform plan -var-file=../../terraform.prod.tfvars
```

**Resultado esperado**:
```
No changes. Your infrastructure matches the configuration.
```

Si hay cambios, son solo updates menores (content, proxied, etc).

### Paso 5: Aplicar Cambios (si hay)

```bash
terraform apply -var-file=../../terraform.prod.tfvars
```

---

## Alternativa: Eliminar y Recrear

Si prefieres eliminar los registros existentes:

1. Ir a: https://dash.cloudflare.com/
2. Seleccionar zona: twomindstrading.com
3. DNS → Records
4. Eliminar: www, grafana, prometheus (NO eliminar root @)
5. Re-run `terraform apply`

**⚠️ CUIDADO**: Esto causará downtime DNS durante unos minutos.

---

## Troubleshooting

### Error: "Missing X-Auth-Key, X-Auth-Email or Authorization headers"

**Causa**: Token no configurado o sintaxis incorrecta

**Solución**:
```bash
# Verificar token
echo "Token: ${CLOUDFLARE_API_TOKEN:0:10}..."

# Re-exportar si es necesario
export CLOUDFLARE_API_TOKEN="tu_token_aqui"
```

### Error: "Could not route to /client/v4/zones/dns_records"

**Causa**: ZONE_ID incorrecto o falta en URL

**Solución**: Verificar que ZONE_ID esté en la URL:
```bash
# Correcto
curl "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records"

# Incorrecto
curl "https://api.cloudflare.com/client/v4/zones/dns_records"
```

### Error: "Unauthorized to access requested resource (9109)"

**Causa**: Token sin permisos de DNS:Edit

**Solución**: Crear nuevo token con permisos correctos (ver CLOUDFLARE_TOKEN_SETUP.md)

---

## Resumen Rápido

```bash
# 1. Configurar
cd terraform/environments/production
export CLOUDFLARE_API_TOKEN="tu_token"
export ZONE_ID="00b35219c140d12c739f52a894ba91e2"

# 2. Listar IDs
curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result[] | "\(.name) \(.id)"'

# 3. Importar (reemplazar <ID> con IDs reales)
terraform import 'module.cloudflare[0].cloudflare_record.www' ${ZONE_ID}/<WWW_ID>
terraform import 'module.cloudflare[0].cloudflare_record.grafana' ${ZONE_ID}/<GRAFANA_ID>
terraform import 'module.cloudflare[0].cloudflare_record.prometheus' ${ZONE_ID}/<PROMETHEUS_ID>

# 4. Verificar
terraform plan -var-file=../../terraform.prod.tfvars
```

¡Listo! Ahora Terraform manejará los registros existentes sin errores.
