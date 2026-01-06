# Obtener Hetzner Cloud API Token

## 🔑 Paso a Paso

### 1. Accede a Hetzner Cloud Console

**URL**: <https://console.hetzner.cloud/>

- Usuario: Tu email de Hetzner
- Password: Tu contraseña
- 2FA: Si lo tienes configurado

---

### 2. Selecciona o Crea un Proyecto

Una vez dentro:

```
┌────────────────────────────────────────────┐
│ 📁 Proyectos                               │
├────────────────────────────────────────────┤
│ > Default Project                          │
│ > WordPress Infrastructure                 │
│ + Nuevo Proyecto                           │
└────────────────────────────────────────────┘
```

**Opciones**:

#### A) Usar proyecto existente

- Click en el proyecto que quieres usar
- Ej: "Default Project" o "WordPress Infrastructure"

#### B) Crear proyecto nuevo (recomendado para testing)

1. Click **"+ Nuevo Proyecto"**
2. Nombre: `Staging Testing`
3. Click **"Crear Proyecto"**

---

### 3. Ir a Security → API Tokens

En el panel izquierdo:

```
┌────────────────────────────────┐
│ 🏠 Dashboard                   │
│ 💻 Servers                     │
│ 💾 Volumes                     │
│ 🌐 Networks                    │
│ 🔥 Firewalls                   │
│ 📊 Load Balancers              │
│ 🔒 Security         ←─ CLICK   │
│   ├─ SSH Keys                  │
│   └─ API Tokens    ←─ AQUÍ     │
│ ⚙️  Settings                   │
└────────────────────────────────┘
```

1. Click en **"Security"** (candado)
2. Click en **"API Tokens"**

---

### 4. Generar Nuevo Token

```
┌────────────────────────────────────────────────────┐
│ API Tokens                                         │
├────────────────────────────────────────────────────┤
│                                                    │
│ No API tokens yet                                  │
│                                                    │
│ [ + Generate API Token ]  ←─ CLICK                │
└────────────────────────────────────────────────────┘
```

Click **"+ Generate API Token"**

---

### 5. Configurar Token

Se abre modal:

```
┌─────────────────────────────────────────┐
│ Generate API Token                      │
├─────────────────────────────────────────┤
│                                         │
│ Name: [terraform-staging        ]      │
│       ^─ Descripción/nombre            │
│                                         │
│ Permissions:                            │
│   ○ Read                                │
│   ● Read & Write        ←─ SELECCIONA  │
│                                         │
│ [ Cancel ]  [ Generate Token ]         │
└─────────────────────────────────────────┘
```

**Configuración recomendada**:

- **Name**: `terraform-staging` o `terraform-production`
- **Permissions**: ✅ **Read & Write**

Click **"Generate Token"**

---

### 6. ⚠️ COPIAR TOKEN (IMPORTANTE)

El token se muestra **UNA SOLA VEZ**:

```
┌─────────────────────────────────────────────────────────┐
│ API Token Created                                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ⚠️  Copy this token now. It won't be shown again!      │
│                                                         │
│ Token:                                                  │
│ ┌─────────────────────────────────────────────────┐   │
│ │ ABC123def456GHI789jkl012MNO345pqr678STU901vwx  │   │
│ │ [📋 Copy to Clipboard]                          │   │
│ └─────────────────────────────────────────────────┘   │
│                                                         │
│ [ Done ]                                                │
└─────────────────────────────────────────────────────────┘
```

**IMPORTANTE**:

1. Click **"📋 Copy to Clipboard"**
2. Guarda el token en un lugar seguro **AHORA**
3. No podrás verlo de nuevo después de cerrar

**Guardar token temporalmente**:

```bash
# En WSL2, crear archivo temporal
echo "ABC123def456GHI789jkl012MNO345pqr678STU901vwx" > ~/hetzner-token.txt
chmod 600 ~/hetzner-token.txt
```

---

### 7. Verificar Token Creado

Después de cerrar el modal:

```
┌────────────────────────────────────────────────────────────┐
│ API Tokens                                                 │
├────────────────────────────────────────────────────────────┤
│ Name                Created          Permissions  Actions  │
│ ──────────────────  ──────────────  ───────────  ────────  │
│ terraform-staging   29 Dec 2025     Read & Write  [Delete] │
└────────────────────────────────────────────────────────────┘
```

Token creado ✅

---

## 🔐 Usar el Token

### Opción 1: Variable de Entorno (Recomendado)

```bash
# Exportar en sesión actual
export HCLOUD_TOKEN="ABC123def456GHI789jkl012MNO345pqr678STU901vwx"

# Verificar
echo $HCLOUD_TOKEN

# Para que persista (añadir a ~/.bashrc)
echo 'export HCLOUD_TOKEN="TU_TOKEN_AQUI"' >> ~/.bashrc
source ~/.bashrc
```

### Opción 2: Terraform tfvars

```bash
cd ~/repos/hetzner-secure-infrastructure/terraform
nano terraform.staging.tfvars
```

**Editar línea**:

```hcl
# ANTES:
hcloud_token = "YOUR_HCLOUD_TOKEN_HERE"

# DESPUÉS:
hcloud_token = "ABC123def456GHI789jkl012MNO345pqr678STU901vwx"
```

**IMPORTANTE**: No hagas commit de este archivo con el token real.

---

## ✅ Verificar Token Funciona

### Con Hetzner CLI (opcional)

```bash
# Instalar CLI
wget https://github.com/hetznercloud/cli/releases/download/v1.42.0/hcloud-linux-amd64.tar.gz
tar xzf hcloud-linux-amd64.tar.gz
sudo mv hcloud /usr/local/bin/
rm hcloud-linux-amd64.tar.gz

# Configurar token
hcloud context create staging
# Pega el token cuando lo pida

# Probar
hcloud server list
# Debe mostrar: No servers found (si no has creado ninguno aún)
```

### Con Terraform

```bash
cd terraform

# Inicializar
terraform init

# Validar (usa el token del tfvars)
terraform validate

# Ver qué creará (requiere token válido)
terraform plan -var-file="terraform.staging.tfvars"

# Si funciona, el token es correcto ✅
```

### Con curl

```bash
# Test directo a API de Hetzner
curl -H "Authorization: Bearer ABC123def456..." \
  https://api.hetzner.cloud/v1/servers

# Respuesta esperada:
# {"servers":[],"meta":{"pagination":{"page":1,...}}}
```

---

## 🔒 Permisos del Token

Tu token con **Read & Write** puede:

### ✅ Puede hacer

- ✅ Crear/eliminar servidores
- ✅ Crear/eliminar SSH keys
- ✅ Crear/eliminar firewalls
- ✅ Crear/eliminar volumes
- ✅ Listar/modificar recursos
- ✅ Todo lo que Terraform necesita

### ❌ NO puede hacer

- ❌ Cambiar billing/facturación
- ❌ Eliminar el proyecto
- ❌ Modificar permisos de usuarios
- ❌ Cambiar configuración de cuenta

---

## 🗑️ Revocar/Eliminar Token

Si comprometes el token o ya no lo necesitas:

1. Ve a **Security → API Tokens**
2. Encuentra el token: `terraform-staging`
3. Click **"Delete"**
4. Confirma eliminación

**⚠️ El token deja de funcionar inmediatamente**

---

## 🎯 Resumen - Checklist Completo

- [ ] 1. Acceder a <https://console.hetzner.cloud/>
- [ ] 2. Seleccionar/crear proyecto
- [ ] 3. Ir a Security → API Tokens
- [ ] 4. Click "Generate API Token"
- [ ] 5. Nombre: `terraform-staging`
- [ ] 6. Permisos: **Read & Write**
- [ ] 7. **Copiar token** (solo se muestra una vez)
- [ ] 8. Guardar en lugar seguro
- [ ] 9. Exportar: `export HCLOUD_TOKEN="..."`
- [ ] 10. Añadir a `terraform.staging.tfvars`
- [ ] 11. Verificar: `terraform plan -var-file="terraform.staging.tfvars"`

---

## 💡 Mejores Prácticas

### 🔐 Seguridad

1. **Diferentes tokens para diferentes usos**:
   - `terraform-staging` → Solo staging
   - `terraform-production` → Solo producción
   - `ansible-dynamic-inventory` → Solo read

2. **Rotación regular**:
   - Rota tokens cada 3-6 meses
   - Elimina tokens viejos

3. **Nunca commits tokens**:

   ```bash
   # Verifica .gitignore
   cat .gitignore | grep tfvars
   # Debe contener: *.tfvars (excepto *.example)
   ```

4. **Variables de entorno mejor que archivos**:
   - ✅ `export HCLOUD_TOKEN="..."`
   - ❌ Hardcoded en scripts
   - ❌ Commiteado en git

### 📊 Monitoreo

Revisa uso del token en Hetzner Console:

- **Settings → Audit Log**
- Verás todas las operaciones hechas con el token

---

## ❓ Troubleshooting

### "Invalid authentication credentials"

```bash
# Token incorrecto o revocado
# Solución: Genera nuevo token
```

### "Insufficient permissions"

```bash
# Token con permisos "Read" solamente
# Solución: Genera nuevo con "Read & Write"
```

### "Token not found in tfvars"

```bash
# Verificar que lo añadiste
grep hcloud_token terraform/terraform.staging.tfvars

# No debe mostrar "YOUR_HCLOUD_TOKEN_HERE"
```

---

**Última actualización**: 29 Diciembre 2025
**Documentación oficial**: <https://docs.hetzner.cloud/#authentication>
