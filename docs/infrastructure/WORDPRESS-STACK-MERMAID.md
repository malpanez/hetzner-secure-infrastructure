# WordPress Stack Architecture (Diagramas Mermaid)

Este archivo complementa [WORDPRESS-STACK.md](WORDPRESS-STACK.md) con diagramas interactivos en Mermaid.

---

## Arquitectura WordPress Stack

Esta sección muestra la arquitectura completa dividida en 3 diagramas simples para facilitar la comprensión.

### Diagrama 1: Edge Layer (Cloudflare a Servidor)

```mermaid
graph TB
    Users[Users]
    CF[Cloudflare Edge]
    Server[Hetzner Server]

    Users -->|HTTPS| CF
    CF -->|Filtered| Server

    style Users fill:#E8F4FD,stroke:#1565C0
    style CF fill:#FFF3E0,stroke:#E65100
    style Server fill:#E8F5E9,stroke:#2E7D32
```

#### Detalles Edge Layer

| Componente | Función | Características |
|------------|---------|-----------------|
| **Users** | Estudiantes y visitantes | Acceso global via HTTPS |
| **Cloudflare Edge** | CDN + Protección | DNS, WAF, Rate Limiting, SSL/TLS |
| **Hetzner Server** | Infraestructura | CAX11, Firewall UFW, 2 vCPU |

### Diagrama 2: Application Stack (Nginx a Base de Datos)

```mermaid
graph TB
    Nginx[Nginx]
    PHP[PHP-FPM 8.4]
    WP[WordPress 6.x]
    DB[(MariaDB)]
    Cache[(Valkey Cache)]

    Nginx -->|FastCGI| PHP
    PHP --> WP
    WP -->|Query| DB
    WP -->|Cache| Cache

    style Nginx fill:#E8F5E9,stroke:#2E7D32
    style PHP fill:#E8F4FD,stroke:#1565C0
    style WP fill:#E8F4FD,stroke:#1565C0
    style DB fill:#F3E5F5,stroke:#6A1B9A
    style Cache fill:#F3E5F5,stroke:#6A1B9A
```

#### Detalles Application Stack

| Componente | Versión | Función |
|------------|---------|---------|
| **Nginx** | Latest | Web server, FastCGI Cache |
| **PHP-FPM** | 8.4 | Application runtime, OPcache |
| **WordPress** | 6.x | CMS + LearnDash LMS |
| **MariaDB** | 10.11 | Base de datos, InnoDB |
| **Valkey** | 8.0 | Object cache, Redis-compatible |

#### Plugins Esenciales

| Plugin | Función |
|--------|---------|
| redis-cache | Integración con Valkey |
| nginx-helper | Purge FastCGI cache |
| wordfence-login-security | 2FA para admin |
| limit-login-attempts-reloaded | Rate limiting login |

### Diagrama 3: Security y Backups

```mermaid
graph TB
    UFW[UFW Firewall]
    Fail2ban[Fail2ban]
    SSH[SSH 2FA]
    Backup[Backup System]

    UFW -->|Protect| Fail2ban
    Fail2ban -->|Monitor| SSH
    SSH -->|Secure| Backup

    style UFW fill:#FCE4EC,stroke:#C2185B
    style Fail2ban fill:#FCE4EC,stroke:#C2185B
    style SSH fill:#FCE4EC,stroke:#C2185B
    style Backup fill:#FFF3E0,stroke:#E65100
```

#### Detalles Security Layer

| Componente | Protección | Configuración |
|------------|------------|---------------|
| **UFW Firewall** | Puertos | Solo 22, 80, 443 permitidos |
| **Fail2ban** | IDS | SSH, Nginx, WordPress protegidos |
| **AppArmor** | Process restriction | PHP-FPM, Nginx, SSH |
| **SSH 2FA** | Autenticación | TOTP + opcional Yubikey/FIDO2 |

#### Sistema de Backups

| Tipo | Frecuencia | Destino | Retención |
|------|-----------|---------|-----------|
| **Database** | Diaria | S3/Google Drive | 14 días |
| **Files** | Semanal | S3/Google Drive | 4 semanas |
| **Full Snapshot** | Diaria | Hetzner Backups | 7 días |

---

## 📊 Flujo de Deployment

```mermaid
sequenceDiagram
    autonumber
    participant Dev as 💻 Developer
    participant TF as Terraform
    participant Hetzner as Hetzner API
    participant Server as 🖥️ Server
    participant Ansible as Ansible
    participant CF as Cloudflare
    participant User as 👥 End User

    Note over Dev,CF: Phase 1: Infrastructure Provisioning
    Dev->>TF: terraform apply -var-file=staging.tfvars
    TF->>Hetzner: Create server (CAX11 ARM64)
    TF->>Hetzner: Configure firewall rules
    Hetzner->>Server: Provision server
    Server->>Server: Cloud-init<br/>(create user, SSH keys)
    TF-->>Dev: Server IP: 46.224.156.140
    TF->>TF: Generate Ansible inventory

    Note over Dev,Server: Phase 2: Configuration Management
    Dev->>Ansible: ansible-playbook wordpress-only.yml
    Ansible->>Server: 1️⃣ Common (timezone, packages)
    Ansible->>Server: 2️⃣ Security (UFW, Fail2ban, SSH 2FA)
    Ansible->>Server: 3️⃣ MariaDB (database)
    Ansible->>Server: 4️⃣ Valkey (Redis cache)
    Ansible->>Server: 5️⃣ Nginx (web server)
    Ansible->>Server: 6️⃣ WordPress + LearnDash
    Ansible-->>Dev: ✅ Deployment complete

    Note over Dev,User: Phase 3: DNS & SSL
    Dev->>CF: Update DNS A record
    CF->>Server: Point domain → IP
    Dev->>Server: certbot --nginx (Let's Encrypt)
    Server-->>Dev: ✅ SSL certificate obtained
    Dev->>CF: Enable WAF + Rate Limiting

    Note over User: Site live!
    User->>CF: https://twomindstrading.com
    CF->>Server: Proxied request
    Server-->>User: WordPress page
```

---

## 🔄 Estados del Deployment

```mermaid
stateDiagram-v2
    [*] --> Planning: Define requirements
    Planning --> Writing: Write Terraform + Ansible
    Writing --> Validation: Validate configs

    Validation --> Provisioning: terraform apply
    Provisioning --> CloudInit: Server created
    CloudInit --> AnsibleReady: User + SSH configured

    state AnsiblePlaybook {
        [*] --> Common
        Common --> Security
        Security --> Database
        Database --> Cache
        Cache --> WebServer
        WebServer --> WordPress
        WordPress --> [*]
    }

    AnsibleReady --> AnsiblePlaybook: ansible-playbook
    AnsiblePlaybook --> Testing: Playbook complete

    Testing --> DNS: Tests pass ✅
    Testing --> Debugging: Tests fail ❌
    Debugging --> AnsiblePlaybook: Fix and retry

    DNS --> SSL: Domain pointed
    SSL --> CloudflareConfig: Certificate obtained
    CloudflareConfig --> Production: WAF enabled
    Production --> Monitoring: Site live!
    Monitoring --> [*]

    Production --> Updates: Monthly maintenance
    Updates --> Testing: Apply updates
```

---

## 🌐 Request Flow (User → WordPress)

```mermaid
flowchart LR
    User[👤 User Browser]
    CF_DNS[Cloudflare DNS]
    CF_CDN[Cloudflare CDN]
    CF_WAF[Cloudflare WAF]

    UFW[UFW Firewall]
    Nginx[Nginx]
    Cache{FastCGI<br/>Cache Hit?}
    PHP[PHP-FPM]
    WP[WordPress]
    Redis{Valkey<br/>Cache Hit?}
    DB[(MariaDB)]

    User -->|1. DNS Query| CF_DNS
    CF_DNS -->|2. IP Address| User
    User -->|3. HTTPS Request| CF_CDN
    CF_CDN -->|4. Check Cache| CF_CDN
    CF_CDN -->|5. If miss| CF_WAF
    CF_WAF -->|6. If allowed| UFW
    UFW -->|7. Port 443| Nginx
    Nginx --> Cache

    Cache -->|Hit| User
    Cache -->|Miss| PHP

    PHP --> WP
    WP --> Redis
    Redis -->|Hit| WP
    Redis -->|Miss| DB
    DB --> WP
    WP --> PHP
    PHP --> Nginx
    Nginx -->|Response| User

    style User fill:#e1f5ff
    style CF_DNS fill:#f9a825
    style CF_CDN fill:#f9a825
    style CF_WAF fill:#f9a825
    style Cache fill:#4caf50
    style Redis fill:#9c27b0
    style DB fill:#9c27b0
```

---

## 💾 Backup Strategy

```mermaid
graph TB
    subgraph WordPress["WordPress Application"]
        Files[📁 WordPress Files<br/>• Themes<br/>• Plugins<br/>• Uploads]
        Database[(💾 MariaDB<br/>Database)]
    end

    subgraph UpdraftPlus["🔄 UpdraftPlus Backups"]
        DBBackup[📅 Database Backup<br/>Schedule: Daily<br/>Retain: 14 days]
        FileBackup[📁 Files Backup<br/>Schedule: Weekly<br/>Retain: 4 weeks]
    end

    subgraph RemoteStorage["☁️ Remote Storage"]
        S3[Amazon S3]
        GDrive[Google Drive]
        Dropbox[Dropbox]
    end

    subgraph HetznerBackup["📸 Hetzner Snapshots"]
        Snapshot[Full Server Snapshot<br/>Schedule: Daily<br/>Retain: 7 days]
    end

    Files --> FileBackup
    Database --> DBBackup

    DBBackup --> S3
    DBBackup --> GDrive
    DBBackup --> Dropbox
    FileBackup --> S3
    FileBackup --> GDrive
    FileBackup --> Dropbox

    WordPress -.->|Full System| Snapshot

    style UpdraftPlus fill:#4caf50
    style RemoteStorage fill:#2196f3
    style HetznerBackup fill:#ff9800
```

---

## 🔐 Security Layers

```mermaid
graph TD
    Request[🌐 Incoming Request]

    subgraph Layer1["Layer 1: Network Edge"]
        CF_DDoS[Cloudflare DDoS Protection]
        CF_WAF[Cloudflare WAF]
        CF_Rate[Rate Limiting]
    end

    subgraph Layer2["Layer 2: Server Firewall"]
        UFW_Rules[UFW Rules<br/>Allow: 22, 80, 443<br/>Deny: All others]
    end

    subgraph Layer3["Layer 3: Application"]
        Nginx_Limit[Nginx Rate Limiting<br/>wp-login.php: 10/5min]
        Fail2ban_Monitor[Fail2ban Monitoring<br/>Auto-ban: 5 failures]
    end

    subgraph Layer4["Layer 4: WordPress"]
        Wordfence[Wordfence WAF<br/>Malware Scanner]
        WP2FA[WP 2FA<br/>Admin Protection]
    end

    subgraph Layer5["Layer 5: System"]
        AppArmor_Profile[AppArmor Profiles<br/>Process Restriction]
        SSH_2FA[SSH 2FA<br/>Yubikey + TOTP]
    end

    Request --> CF_DDoS
    CF_DDoS --> CF_WAF
    CF_WAF --> CF_Rate
    CF_Rate --> UFW_Rules
    UFW_Rules --> Nginx_Limit
    Nginx_Limit --> Fail2ban_Monitor
    Fail2ban_Monitor --> Wordfence
    Wordfence --> WP2FA
    WP2FA --> AppArmor_Profile
    AppArmor_Profile --> SSH_2FA
    SSH_2FA --> Allowed[✅ Request Allowed]

    CF_DDoS -.->|Block| Blocked1[❌ Blocked]
    CF_WAF -.->|Block| Blocked2[❌ Blocked]
    UFW_Rules -.->|Block| Blocked3[❌ Blocked]
    Fail2ban_Monitor -.->|Ban IP| Blocked4[❌ Blocked]
    Wordfence -.->|Block| Blocked5[❌ Blocked]

    style Layer1 fill:#f9a825
    style Layer2 fill:#ff5722
    style Layer3 fill:#f44336
    style Layer4 fill:#e91e63
    style Layer5 fill:#9c27b0
    style Allowed fill:#4caf50
    style Blocked1 fill:#263238
    style Blocked2 fill:#263238
    style Blocked3 fill:#263238
    style Blocked4 fill:#263238
    style Blocked5 fill:#263238
```

---

## 📈 Performance Optimization Layers

```mermaid
graph LR
    Browser[👤 Browser]

    subgraph CF["Cloudflare Edge"]
        CF_Cache[Static Cache<br/>CSS, JS, Images]
    end

    subgraph Server["Hetzner Server"]
        Nginx_Cache[Nginx FastCGI<br/>HTML Pages]
        Redis_Cache[Valkey Cache<br/>Objects, Queries]
        OPcache[PHP OPcache<br/>Bytecode]
        DB[(MariaDB<br/>InnoDB Buffer)]
    end

    Browser -->|Request| CF_Cache
    CF_Cache -->|Hit: Serve| Browser
    CF_Cache -->|Miss| Nginx_Cache

    Nginx_Cache -->|Hit: Serve| Browser
    Nginx_Cache -->|Miss: Generate| Redis_Cache

    Redis_Cache -->|Hit: Return| Browser
    Redis_Cache -->|Miss: Query| OPcache

    OPcache -->|Execute PHP| DB
    DB -->|Return Data| Browser

    style CF_Cache fill:#f9a825
    style Nginx_Cache fill:#4caf50
    style Redis_Cache fill:#9c27b0
    style OPcache fill:#2196f3
    style DB fill:#607d8b
```

---

## 🎓 LearnDash Data Model

```mermaid
erDiagram
    USERS ||--o{ ENROLLMENTS : has
    COURSES ||--o{ LESSONS : contains
    COURSES ||--o{ ENROLLMENTS : has
    LESSONS ||--o{ TOPICS : contains
    LESSONS ||--o{ QUIZZES : has
    TOPICS ||--o{ QUIZZES : has
    QUIZZES ||--o{ QUESTIONS : contains
    USERS ||--o{ QUIZ_ATTEMPTS : takes
    QUIZ_ATTEMPTS ||--|| QUIZZES : for
    USERS ||--o{ CERTIFICATES : earns
    CERTIFICATES ||--|| COURSES : for
    COURSES ||--o{ GROUPS : organizes
    GROUPS ||--o{ USERS : contains

    USERS {
        int ID PK
        string username
        string email
        bool is_admin
    }

    COURSES {
        int ID PK
        string title
        string description
        decimal price
        string access_mode
        int prerequisite_course FK
    }

    LESSONS {
        int ID PK
        int course_id FK
        string title
        text content
        int order
        bool force_completion
    }

    TOPICS {
        int ID PK
        int lesson_id FK
        string title
        text content
        int order
    }

    QUIZZES {
        int ID PK
        string title
        int passing_score
        int time_limit
        bool randomize_questions
    }

    ENROLLMENTS {
        int ID PK
        int user_id FK
        int course_id FK
        datetime enrolled_date
        datetime completed_date
        int progress_percent
    }

    CERTIFICATES {
        int ID PK
        int user_id FK
        int course_id FK
        string certificate_link
        datetime awarded_date
    }
```

---

## 📊 Cost Breakdown

```mermaid
pie title Monthly Costs (Production)
    "Hetzner Server (CAX11)" : 4.05
    "Hetzner Backups (20%)" : 0.81
    "Cloudflare" : 0
    "Total: €4.86/month" : 0
```

```mermaid
pie title Service Distribution (By Component)
    "Compute (Hetzner)" : 83
    "Backups" : 17
    "CDN/DNS (Free)" : 0
```

---

## 🔄 Update & Maintenance Workflow

```mermaid
gitGraph
    commit id: "Initial Deploy"
    branch staging
    checkout staging
    commit id: "Test updates"
    commit id: "Validate"
    checkout main
    merge staging tag: "v1.1"
    commit id: "Deploy to production"

    branch hotfix
    checkout hotfix
    commit id: "Security patch"
    checkout main
    merge hotfix tag: "v1.1.1"

    checkout staging
    commit id: "New features"
    commit id: "Testing"
    checkout main
    merge staging tag: "v1.2"
```

---

## 📝 Notas Importantes

1. **Mermaid en Codeberg**: Estos diagramas se renderizan automáticamente en Codeberg (Gitea tiene soporte nativo).

2. **Editar diagramas**: Usa [Mermaid Live Editor](https://mermaid.live/) para previsualizar cambios.

3. **Sintaxis alternativa**: Si Codeberg no renderiza, usar:

   ````markdown
   ```mermaid
   graph TD
   ...
   ```
   ````

4. **Exportar**: Mermaid Live Editor permite exportar a SVG/PNG para usar en presentaciones.

---

**Última actualización:** 2026-01-09

## 🔗 Referencias

- [Mermaid Documentation](https://mermaid.js.org/)
- [Mermaid Live Editor](https://mermaid.live/)
- [Gitea Mermaid Support](https://docs.gitea.io/en-us/markdown/#diagrams)
