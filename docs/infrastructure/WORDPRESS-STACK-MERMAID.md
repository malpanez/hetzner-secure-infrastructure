# WordPress Stack Architecture (Diagramas Mermaid)

Este archivo complementa [WORDPRESS-STACK.md](WORDPRESS-STACK.md) con diagramas interactivos en Mermaid.

---

## 🏗️ Diagrama de Arquitectura Completa

```mermaid
graph TB
    subgraph Internet
        Users[👥 Users/Students]
    end

    subgraph Cloudflare["☁️ Cloudflare (Free Plan)"]
        DNS[🌐 DNS Management]
        CDN[📦 CDN & Cache]
        WAF[🛡️ WAF Rules]
        SSL[🔒 SSL/TLS]
        RateLimit[⏱️ Rate Limiting]
    end

    subgraph Hetzner["🖥️ Hetzner Cloud Server"]
        subgraph WebLayer["Web Layer"]
            Nginx[⚡ Nginx<br/>• FastCGI Cache<br/>• Gzip/Brotli<br/>• Security Headers]
        end

        subgraph AppLayer["Application Layer"]
            PHP[🐘 PHP 8.4-FPM<br/>• OPcache<br/>• APCu]
            WP[📝 WordPress 6.x]
            LD[🎓 LearnDash Pro]
            Plugins[🔌 Security Plugins<br/>• Wordfence<br/>• Sucuri<br/>• WP 2FA]
        end

        subgraph DataLayer["Data Layer"]
            MariaDB[(💾 MariaDB 10.11<br/>• InnoDB<br/>• UTF8MB4)]
            Valkey[(⚡ Valkey 8.0<br/>Redis-compatible<br/>Object Cache)]
        end

        subgraph SecurityLayer["🔒 Security Layer"]
            UFW[🧱 UFW Firewall<br/>Ports: 22,80,443]
            Fail2ban[🚫 Fail2ban IDS<br/>• SSH<br/>• Nginx<br/>• WordPress]
            AppArmor[🛡️ AppArmor<br/>• PHP-FPM<br/>• Nginx<br/>• SSH]
            SSH[🔑 SSH 2FA<br/>• Yubikey<br/>• Google Auth]
        end
    end

    subgraph Backups["💾 Backup Storage"]
        S3[☁️ Amazon S3<br/>or Google Drive]
        Hetzner Backup[📸 Hetzner Backups<br/>Daily Snapshots]
    end

    Users -->|HTTPS Request| Cloudflare
    Cloudflare -->|Filtered Request| UFW
    UFW --> Nginx
    Nginx -->|FastCGI| PHP
    PHP --> WP
    WP --> LD
    WP --> Plugins
    WP -->|SQL Queries| MariaDB
    WP -->|Get/Set Cache| Valkey
    PHP -->|Read Cache| Valkey

    WP -.->|Daily DB Backup| S3
    WP -.->|Weekly Files Backup| S3
    Hetzner -.->|Full Snapshots| HetznerBackup

    Fail2ban -.->|Monitor Logs| Nginx
    Fail2ban -.->|Ban IPs| UFW
    AppArmor -.->|Restrict Processes| PHP
    SSH -.->|2FA Auth| Hetzner

    style Users fill:#e1f5ff,stroke:#01579b
    style Cloudflare fill:#f9a825,stroke:#f57f17
    style Hetzner fill:#d84315,stroke:#bf360c
    style WebLayer fill:#4caf50,stroke:#2e7d32
    style AppLayer fill:#2196f3,stroke:#1565c0
    style DataLayer fill:#9c27b0,stroke:#6a1b9a
    style SecurityLayer fill:#f44336,stroke:#c62828
    style Backups fill:#607d8b,stroke:#37474f
```

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
    TF->>Hetzner: Create server (CPX31)
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
    Redis{Redis<br/>Cache Hit?}
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
    "Hetzner Server (CPX31)" : 13.90
    "Hetzner Backups (20%)" : 2.78
    "Cloudflare" : 0
    "Total: €16.68/month" : 0
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

## 🔗 Referencias

- [Mermaid Documentation](https://mermaid.js.org/)
- [Mermaid Live Editor](https://mermaid.live/)
- [Gitea Mermaid Support](https://docs.gitea.io/en-us/markdown/#diagrams)
