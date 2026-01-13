# Cloudflare API Token Setup

## 🔑 Crear Token con Permisos Correctos

### 1. Ir a Cloudflare Dashboard

https://dash.cloudflare.com/profile/api-tokens

### 2. Crear "Custom Token"

Haz clic en **"Create Token"** → **"Create Custom Token"**

### 3. Configurar Permisos (CRÍTICO)

El token necesita estos permisos **EXACTOS** (basados en homelabforge.dev working config):

| Resource | Permission | Scope |
|----------|------------|-------|
| **Account** | Account Rulesets:Edit | All accounts |
| **Zone** | DNS:Edit | Specific zone: `twomindstrading.com` |
| **Zone** | Zone:Edit | Specific zone: `twomindstrading.com` |
| **Zone** | Zone Settings:Edit | Specific zone: `twomindstrading.com` |
| **Zone** | Cache Rules:Edit | Specific zone: `twomindstrading.com` |
| **Zone** | Transform Rules:Edit | Specific zone: `twomindstrading.com` |
| **Zone** | Single Redirect:Edit | Specific zone: `twomindstrading.com` |

**NOTA**: ~~Page Rules~~ ya NO se usan (deprecated). Ahora usamos **Rulesets v5** (mejor y sin límites en Free plan).

**Permisos Específicos Necesarios**:
- **Account Rulesets:Edit**: Para crear/modificar rulesets a nivel de cuenta
- **Cache Rules:Edit**: Para configurar reglas de caché (wp-content, static assets)
- **Transform Rules:Edit**: Para security headers (CSP, HSTS, X-Frame-Options)
- **Single Redirect:Edit**: Para redirects www → apex

### 4. Template de Configuración

```yaml
Token Name: Terraform - twomindstrading.com

Permissions:
  Account:
    - Account Rulesets:Edit (All accounts)

  Zone (twomindstrading.com):
    - DNS:Edit
    - Zone:Edit
    - Zone Settings:Edit
    - Cache Rules:Edit
    - Transform Rules:Edit
    - Single Redirect:Edit

IP Filtering: Optional (restrict to your IP for security)

TTL: No expiration (or set to 1 year)
```

### 5. Guardar Token

```bash
export CLOUDFLARE_API_TOKEN="tu_token_aqui"
export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
```

---

## 🔧 Troubleshooting

### Error: "Unauthorized to access requested resource (9109)"

**Causa**: Token sin permisos suficientes

**Solución**:
1. Verifica que el token tenga **Page Rules:Edit** y **Account Rulesets:Edit**
2. Verifica que el scope sea la zona correcta (`twomindstrading.com`)
3. Si usas un token antiguo, créalo de nuevo con los permisos completos

### Error: "DNS record already exists"

**Causa**: El registro `www` ya existe en Cloudflare (creado manualmente)

**Solución 1: Importar registro existente** (Recomendado)

```bash
cd terraform/environments/production

# 1. Obtener ID del record existente
export CLOUDFLARE_API_TOKEN="tu_token"
export ZONE_ID="tu_zone_id"

curl -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=www.twomindstrading.com" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  | jq '.result[0].id'

# 2. Importar a Terraform
terraform import 'module.cloudflare[0].cloudflare_record.www' <ZONE_ID>/<RECORD_ID>
```

**Solución 2: Eliminar y recrear**

```bash
# Eliminar registro existente desde Cloudflare Dashboard
# Luego re-ejecutar terraform apply
```

### Error: "Invalid IPv6 address"

**Causa**: Regex de validación demasiado estricto (YA CORREGIDO)

**Estado**: ✅ Fixed en commit anterior

---

## 🚀 Deployment Limpio (Sin Cloudflare)

Si quieres desplegar solo Hetzner SIN Cloudflare:

```hcl
# terraform.prod.tfvars
enable_cloudflare = false
```

Luego configura DNS manualmente en Cloudflare Dashboard.

---

## 📋 Checklist Pre-Deployment

- [ ] Token creado con permisos completos (5 permisos: DNS, Zone Settings, Zone Read, Account Rulesets×2)
- [ ] Token guardado en variable de entorno
- [ ] Zona `twomindstrading.com` existe en Cloudflare
- [ ] DNS records existentes documentados

---

## ✅ Ventajas de Rulesets v5 (vs Page Rules deprecated)

**Page Rules (deprecated)**:
- ❌ Máximo 3 en Free plan
- ❌ Deprecated por Cloudflare
- ❌ Menos flexible

**Rulesets v5 (actual)**:
- ✅ **Ilimitados en Free plan**
- ✅ API moderna
- ✅ Más potente (expresiones complejas)
- ✅ Múltiples fases: cache, redirect, headers, WAF

**Nuestro código usa Rulesets v5** → Sin limitaciones del Free plan
