# simplefullstackdeploy_v1
# 🚀 Full Stack Multi-App Docker Deployer

![Shell](https://img.shields.io/badge/script-bash-green)
![Docker](https://img.shields.io/badge/runtime-docker-blue)
![Laravel](https://img.shields.io/badge/framework-laravel-red)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

Automated **one-command deployment script** that provisions a complete multi-application web platform using containerized services.
Designed for DevOps labs, staging environments, and infrastructure testing scenarios.

---

# 📦 What This Project Does

This script automatically builds a full stack environment consisting of:

* Docker Engine + Compose
* Firewall + security hardening
* Multiple Laravel applications
* Isolated containers per app
* HTTPS configuration
* Database provisioning
* Runtime health validation

All deployed with:

```bash
sudo ./deploy_full_stackv1.sh
```

---

# 🏗 Architecture

Each domain is deployed as an independent stack:

```
app1.local → Nginx → PHP-FPM → MySQL
app2.local → Nginx → PHP-FPM → MySQL
app3.local → Nginx → PHP-FPM → MySQL
```

Ports are auto-assigned:

| App  | Port |
| ---- | ---- |
| app1 | 8443 |
| app2 | 8444 |
| app3 | 8445 |

Isolation ensures:

* independent scaling
* zero cross-app conflicts
* safe testing environments

---

# ⚙️ Stack Components

For every application the script creates:

| Container | Role                |
| --------- | ------------------- |
| Nginx     | HTTPS web server    |
| PHP-FPM   | Application runtime |
| MySQL     | Database            |
| Laravel   | Web application     |

Total containers deployed: **9**

---

# 🔐 Security Features

The script includes built-in system hardening:

* UFW firewall enabled
* Fail2Ban intrusion protection
* Docker log rotation
* Least-privilege file permissions
* Automatic service validation

---

# 🧠 Smart Deployment Logic

The script is designed with production-style reliability:

* retry logic for transient failures
* health checks
* automatic logging
* port conflict detection
* idempotent execution
* fail-fast error handling

---

# 📂 Directory Structure

```
/opt/webapps/
 ├── app1.local/
 ├── app2.local/
 └── app3.local/
```

Each folder contains its own:

* docker-compose.yml
* nginx config
* SSL cert
* Laravel codebase

---

# 🌐 Runtime Info Page

Each app includes a debug endpoint:

```
/app-id.php
```

Displays:

* domain name
* container hostname
* container IP
* PHP version
* server time

Useful for:

* load balancer testing
* container validation
* environment debugging

---

# 🎯 Use Cases

Ideal for:

* DevOps practice labs
* Infrastructure demos
* multi-tenant testing
* staging environments
* container learning platforms

---

# ⚠️ Production Notes

This script is **production-style**, but not fully production-ready yet.

Recommended additions for real production:

* global reverse proxy
* trusted SSL certificates
* secrets manager
* centralized logging
* monitoring stack
* automated backups
* resource limits

---

# ▶️ Requirements

* Ubuntu server
* root privileges
* internet access

---

# 🚀 Quick Start

```bash
git clone <repo>
cd <repo>
sudo bash deploy_full_stackv1.sh
```

Then access:

```
https://app1.local:8443
https://app2.local:8444
https://app3.local:8445
```

---

# 🧩 Design Philosophy

This project demonstrates how modern infrastructure can be:

* automated
* reproducible
* isolated
* portable
* scalable (architecture-ready)

---

# 📜 License

MIT License — free to use, modify, and distribute.

---

# 👨‍💻 Author Notes

This script is intentionally designed as a **learning-grade production simulator** that teaches:

* container orchestration concepts
* deployment automation
* system hardening
* multi-service architecture

---

⭐ If you find this useful, consider starring the repo.
