# Terraform Architecture Selection (x86 vs ARM)

Terraform ahora soporta selección automática de tipo de servidor basado en arquitectura y tamaño.

---

## 🚀 Uso Rápido

### Método 1: Auto-selección por Arquitectura + Tamaño (Recomendado)

```hcl
# terraform.staging.tfvars
architecture = "arm"     # x86 o arm
server_size  = "medium"  # small, medium, large, xlarge
location     = "fsn1"    # ARM solo en: fsn1, hel1, ash
```

Terraform automáticamente selecciona el `server_type` correcto basado en estos valores.

### Método 2: Override Manual (Si necesitas tipo específico)

```hcl
# terraform.tfvars
server_type = "cax21"  # Override directo
location    = "fsn1"
```

---

## 📊 Mapeo de Tipos de Servidor

### x86 (AMD EPYC) - Disponible en TODOS los locations

| Size   | Server Type | vCPU | RAM  | Disk      | Precio/mes |
|--------|-------------|------|------|-----------|------------|
| small  | `cpx11`     | 2    | 2GB  | 40GB NVMe | €4.50      |
| medium | `cpx21`     | 3    | 4GB  | 80GB NVMe | €8.50      |
| large  | `cpx31`     | 4    | 8GB  | 160GB NVMe| €13.90     |
| xlarge | `cpx41`     | 8    | 16GB | 240GB NVMe| €26.90     |

### ARM (Ampere Altra) - Solo en: `fsn1`, `hel1`, `ash`

| Size   | Server Type | vCPU | RAM  | Disk      | Precio/mes | Ahorro vs x86 |
|--------|-------------|------|------|-----------|------------|---------------|
| small  | `cax11`     | 2    | 4GB  | 40GB NVMe | €4.15      | €0.35 (8%)    |
| medium | `cax21`     | 4    | 8GB  | 80GB NVMe | €8.30      | €5.60 (40%)⭐ |
| large  | `cax31`     | 8    | 16GB | 160GB NVMe| €16.60     | €10.30 (38%)  |
| xlarge | `cax41`     | 16   | 32GB | 320GB NVMe| €33.20     | €20.60 (38%)  |

**Nota importante**: ARM `small` y `medium` tienen **DOBLE de RAM** que x86 equivalente!

---

## 💰 Comparación de Costos

### Staging Environment

**Opción A: ARM medium** (Recomendado)
```hcl
architecture = "arm"
server_size  = "medium"  # cax21
location     = "fsn1"

Specs:  4 vCPU, 8GB RAM, 80GB NVMe
Precio: €8.30/mes = €99.60/año
```

**Opción B: x86 large**
```hcl
architecture = "x86"
server_size  = "large"   # cpx31
location     = "nbg1"

Specs:  4 vCPU, 8GB RAM, 160GB NVMe
Precio: €13.90/mes = €166.80/año
```

**Ahorro con ARM**: €5.60/mes = €67.20/año (40% más barato!)

---

## 🎯 Recomendaciones por Caso de Uso

### Staging / Development / Testing

**Recomendado: ARM medium**

```hcl
architecture = "arm"
server_size  = "medium"
location     = "fsn1"  # Falkenstein
```

**Razones:**
- ✅ 40% más barato que x86 equivalent
- ✅ Mismo RAM que CPX31 (8GB)
- ✅ Stack WordPress 100% compatible
- ✅ Perfecto para testing y validación

**Trade-off:**
- ⚠️ ~10% más lento en single-core (imperceptible con cache)

---

### Production (< 10k visitas/día)

**Recomendado: x86 large**

```hcl
architecture = "x86"
server_size  = "large"
location     = "nbg1"  # Nuremberg
```

**Razones:**
- ✅ Mejor performance single-core (PHP es single-threaded)
- ✅ Más barato que ARM large (€13.90 vs €16.60)
- ✅ Stack totalmente probado en producción
- ✅ Disponible en más locations

---

### Production (> 10k visitas/día)

**Recomendado: x86 xlarge**

```hcl
architecture = "x86"
server_size  = "xlarge"
location     = "nbg1"
```

**Razones:**
- ✅ 8 vCPUs para alto tráfico concurrente
- ✅ 16GB RAM para cache agresivo
- ✅ Mejor rendimiento MySQL bajo carga

**Alternativa: ARM xlarge** (si budget es crítico)
- Más cores (16 vs 8)
- Más RAM (32GB vs 16GB)
- 24% más caro (€33.20 vs €26.90)

---

## 📍 Locations Disponibles

| Location | Code   | x86 | ARM | Latencia Europa |
|----------|--------|-----|-----|-----------------|
| Falkenstein, DE | `fsn1` | ✅ | ✅ | ~10-20ms |
| Nuremberg, DE   | `nbg1` | ✅ | ❌ | ~10-20ms |
| Helsinki, FI    | `hel1` | ✅ | ✅ | ~30-40ms |
| Ashburn, US     | `ash`  | ✅ | ✅ | ~100ms   |
| Hillsboro, US   | `hil`  | ✅ | ❌ | ~150ms   |

**Recomendaciones de location:**
- Europa (audiencia española/EU): `fsn1` o `nbg1`
- Global: `fsn1` (ARM disponible) + Cloudflare CDN
- USA: `ash` (ARM disponible)

---

## ⚙️ Validaciones Automáticas

Terraform valida automáticamente:

1. **Architecture válida**: Solo `x86` o `arm`
2. **Server size válido**: Solo `small`, `medium`, `large`, `xlarge`
3. **Location compatible con ARM**: Si usas `arm`, location debe ser `fsn1`, `hel1`, o `ash`

### Ejemplo de Error

```hcl
architecture = "arm"
location     = "nbg1"  # ❌ Nuremberg no soporta ARM
```

**Error de Terraform:**
```
ERROR: ARM architecture requires location to be one of: fsn1, hel1, ash
Current location: nbg1
Current architecture: arm

Solutions:
  1. Change architecture to 'x86'
  2. Change location to 'fsn1' (Falkenstein - recommended)
```

---

## 📤 Outputs Mejorados

Terraform ahora muestra información detallada del servidor:

```bash
$ terraform apply

Outputs:

architecture = "arm"
server_size = "medium"
server_type = "cax21"

server_specs = {
  cpu   = "4 vCPUs"
  ram   = "8 GB"
  disk  = "80 GB NVMe"
  price = "€8.30/month"
}

cost_savings = {
  arm_monthly    = 8.30
  x86_equivalent = 13.90
  monthly_saving = 5.60
  yearly_saving  = 67.20
}

server_ipv4 = "X.X.X.X"
ssh_command = "ssh malpanez@X.X.X.X"
```

---

## 🔄 Migración de Configuración Existente

### Si tienes config antigua (server_type hardcoded):

**Antes:**
```hcl
server_type = "cpx31"
location    = "nbg1"
```

**Después (Método 1 - Auto-select):**
```hcl
architecture = "x86"
server_size  = "large"  # Auto-selecciona cpx31
location     = "nbg1"
```

**Después (Método 2 - Override):**
```hcl
server_type = "cpx31"  # Funciona igual que antes
location    = "nbg1"
```

Ambos métodos funcionan! El método de override existe para backward compatibility.

---

## 🧪 Testing con Diferentes Arquitecturas

### Test 1: Staging en ARM

```bash
# Crear terraform.staging.tfvars
cat > terraform.staging.tfvars <<EOF
hcloud_token = "YOUR_TOKEN"
ssh_public_key = "$(cat ~/.ssh/id_ed25519.pub)"

architecture = "arm"
server_size  = "medium"
location     = "fsn1"

server_name = "staging-wordpress"
environment = "staging"
allow_http  = true
allow_https = true
EOF

# Deploy
terraform apply -var-file=terraform.staging.tfvars
```

### Test 2: Cambiar de ARM a x86

```bash
# Solo cambiar 2 líneas!
sed -i 's/architecture = "arm"/architecture = "x86"/' terraform.staging.tfvars
sed -i 's/location     = "fsn1"/location     = "nbg1"/' terraform.staging.tfvars

# Re-deploy (destruye ARM, crea x86)
terraform apply -var-file=terraform.staging.tfvars
```

---

## 📚 Ejemplos Completos

### Ejemplo 1: Staging Minimal (ARM)

```hcl
# terraform.staging.tfvars
hcloud_token   = "YOUR_STAGING_TOKEN"
ssh_public_key = "ssh-ed25519 AAAA..."

architecture   = "arm"
server_size    = "medium"
location       = "fsn1"

server_name    = "staging-wordpress"
admin_username = "malpanez"
environment    = "staging"

allow_http     = true
allow_https    = true

prevent_destroy = false  # Permite destruir staging fácilmente
```

**Costo total:** €8.30/mes

---

### Ejemplo 2: Production (x86)

```hcl
# terraform.production.tfvars
hcloud_token   = "YOUR_PRODUCTION_TOKEN"
ssh_public_key = "ssh-ed25519 AAAA..."

architecture   = "x86"
server_size    = "large"
location       = "nbg1"

server_name    = "prod-wordpress"
admin_username = "malpanez"
environment    = "production"

allow_http     = true
allow_https    = true

# Backups (20% extra = €2.78/mo)
# Configurado en módulo hetzner-server

prevent_destroy = true  # Protege contra destrucción accidental

ssh_allowed_ips = ["YOUR_IP/32"]  # Restringir SSH
```

**Costo total:** €13.90/mes + €2.78 backups = €16.68/mes

---

## ❓ FAQ

### ¿Puedo cambiar de x86 a ARM sin perder datos?

Sí, pero requiere:
1. Backup completo (Hetzner snapshot)
2. `terraform apply` con nueva config (destruye x86, crea ARM)
3. Restaurar datos desde backup

**Mejor práctica:** Testea en staging primero.

---

### ¿ARM funciona con WordPress?

✅ Sí, 100% compatible:
- Debian 13 tiene imagen ARM64 nativa
- Nginx, PHP 8.4, MariaDB, Valkey: todos ARM-native
- WordPress, LearnDash: PHP puro (sin binarios)
- Ansible: 100% compatible

**Diferencia de performance:** < 10% en real-world con cache.

---

### ¿Qué pasa si uso ARM con location incompatible?

Terraform mostrará error **antes** de crear recursos:

```
ERROR: ARM architecture requires location to be one of: fsn1, hel1, ash
```

No gasta dinero ni crea recursos parciales.

---

### ¿Cuál es el mejor server_size para mi caso?

| Tráfico/día | Users concurrentes | Recomendación |
|-------------|-------------------|---------------|
| < 1,000     | < 10              | `small`       |
| 1k - 5k     | 10-50             | `medium`      |
| 5k - 20k    | 50-200            | `large`       |
| > 20k       | > 200             | `xlarge`      |

**Nota:** Con Cloudflare CDN + Nginx cache, puedes manejar 10x más tráfico.

---

## 🔗 Referencias

- [Hetzner CAX Series (ARM)](https://www.hetzner.com/news/arm64-cloud/)
- [ARM vs x86 Comparison](../docs/infrastructure/ARM_VS_X86_COMPARISON.md)
- [Deployment Checklist](../DEPLOYMENT_CHECKLIST.md)

---

## ✅ Checklist de Uso

```
Setup inicial:
☐ Decidir arquitectura (ARM para staging, x86 para prod)
☐ Elegir server_size basado en tráfico esperado
☐ Verificar location compatible con arquitectura
☐ Crear terraform.tfvars con valores

Deployment:
☐ terraform init
☐ terraform validate
☐ terraform plan -var-file=terraform.staging.tfvars
☐ Revisar outputs (server_type, specs, cost)
☐ terraform apply -var-file=terraform.staging.tfvars

Post-deployment:
☐ Verificar outputs (arquitectura correcta)
☐ SSH al servidor: ssh malpanez@IP
☐ Verificar arquitectura: uname -m (x86_64 o aarch64)
☐ Test WordPress deployment con Ansible
```

---

¡Disfruta del ahorro de 40% con ARM para staging! 🎉
