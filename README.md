# WHS Portal - Deployment & Infrastructure

**Infrastructure repository for the Cook Shire Council Workplace Health and Safety Portal**

This repository contains deployment scripts, configuration files, and documentation for managing the WHS Portal infrastructure and addon deployments.

---

## Purpose

This repository centralizes the deployment tooling and infrastructure configuration for the WHS Portal project. It provides:

- **Automated deployment scripts** for building and deploying Plone addons
- **Service configuration files** for systemd and nginx
- **Utility scripts** for maintenance and upgrades
- **Comprehensive documentation** of implementation and architecture decisions

---

## Repository Structure

### 🚀 Deployment Scripts

| File | Purpose |
|------|---------|
| `deploy-systemd.sh` | Main deployment script - builds wheels, deploys to server, restarts service, clears nginx cache |
| `deploy.sh` | Legacy deployment script for manual deployments |
| `setup-systemd.sh` | Initial setup utility for configuring systemd service |

**Usage:**
```bash
# Deploy individual addons
./deploy-systemd.sh csc          # Deploy csc.whs addon
./deploy-systemd.sh theme        # Deploy cook.whs.barceloneta theme
./deploy-systemd.sh both         # Deploy both addons

# Deploy without restarting Plone
./deploy-systemd.sh csc --no-restart
```

### ⚙️ Service & Configuration Files

| File | Purpose |
|------|---------|
| `plone.service` | Systemd service definition for Plone instance |
| `sudoers.d-plone` | Passwordless sudo configuration for deployment user |
| `whsportal.cook.qld.gov.au` | Nginx reverse proxy configuration with caching rules |

**Deployment Location:**
- Service file: `/etc/systemd/system/plone.service`
- Sudoers config: `/etc/sudoers.d/plone`
- Nginx config: `/etc/nginx/sites-available/whsportal.cook.qld.gov.au`

### 🔧 Utility Scripts

| File | Purpose |
|------|---------|
| `run_upgrade.py` | Execute GenericSetup profile upgrades programmatically |
| `fix_ldap_mappings.py` | Configure LDAP attribute mappings for user properties |
| `restore_ldap_mappings.py` | Restore LDAP mappings from backup |
| `add_ldap_fields.py` | Add custom LDAP fields (job_title, manager) |

### 📚 Documentation

| File | Description |
|------|-------------|
| `PROJECT_STATUS.md` | Overall project status, version history, features (v0.9.20) |
| `.claude_instructions` | Development workflow and project structure guide |
| `HAZARD_IMPLEMENTATION_STATUS.md` | Hazard reporting system implementation details |
| `DEPLOYMENT_OPTIONS.md` | Comparison of deployment methods |
| `SYSTEMD_MIGRATION.md` | Migration guide from screen to systemd |
| `Content_import_implementation_plan.md` | Content migration strategy and implementation |
| `form_update_implementation.md` | Form enhancement implementation notes |

### 🎨 Assets

| File | Purpose |
|------|---------|
| `CSC_logo_Intranet.png` | Cook Shire Council intranet logo (16KB) |
| `CSC_logo_WHSPortal.png` | WHS Portal branded logo (19KB) |

---

## Related Repositories

The WHS Portal project consists of 5 independent repositories:

1. **[csc.whs](https://github.com/Cook-Shire-Council/csc.whs)** (v0.9.20)
   Core WHS incident and hazard management addon

2. **[csc.whstheme](https://github.com/Cook-Shire-Council/csc.whstheme)** (v1.0.27)
   Custom Barceloneta theme with button-grid navigation

3. **[csc.teams](https://github.com/Cook-Shire-Council/csc.teams)** (v1.0.x)
   Team listing addon with LDAP integration

4. **[whs-content-import-tools](https://github.com/Cook-Shire-Council/whs-content-import-tools)**
   Content migration utilities with AI metadata extraction

5. **whsportal-deployment** (this repository)
   Infrastructure and deployment tooling

---

## Environment Details

### Development Server
- **Hostname:** whsportaldev
- **OS:** Ubuntu 24.04
- **Plone Path:** `/opt/plone`
- **Virtual Environment:** `/opt/plone/venv`
- **Public URL:** https://whsportal.cook.qld.gov.au

### Architecture
- **Plone Version:** 6.1 (Classic site)
- **Service Management:** systemd
- **Reverse Proxy:** nginx with caching
- **Authentication:** LDAP/Active Directory integration
- **Deployment Model:** Wheel-based installation with automated service restart

---

## Deployment Workflow

### Standard Deployment Process

1. **Develop addon locally** in `/home/ceo/Development/WHSPortal/`
2. **Build wheel** from `pyproject.toml`
3. **Deploy to server** via SSH using `deploy-systemd.sh`
4. **Install with pip** (`--force-reinstall --no-deps`)
5. **Restart Plone service** via systemd
6. **Clear nginx cache** for static resources
7. **Verify installation** and service status

### Automated Deployment

The `deploy-systemd.sh` script handles the complete deployment pipeline:

```bash
./deploy-systemd.sh csc
```

**Steps performed:**
1. ✅ Clean previous builds
2. ✅ Build wheel package
3. ✅ Copy to development server via SSH
4. ✅ Install wheel with pip
5. ✅ Restart Plone systemd service
6. ✅ Clear nginx cache
7. ✅ Display verification information

---

## Security Considerations

### Excluded from Repository

This repository **does not contain**:

- ❌ API keys or credentials (`.env` file)
- ❌ Plone admin passwords (`instance.yaml`)
- ❌ Network configuration files
- ❌ Build artifacts (`.whl`, `.zip` files)
- ❌ Sensitive organizational documents
- ❌ Session logs or temporary files
- ❌ Addon source code (separate repositories)

### What's Included

- ✅ Deployment automation scripts
- ✅ Service configuration templates
- ✅ Public nginx configuration
- ✅ Utility scripts for LDAP and upgrades
- ✅ Documentation and implementation notes
- ✅ Public logos and assets

The `.gitignore` file uses a whitelist approach - everything is ignored by default, and only safe files are explicitly included.

---

## Key Features of WHS Portal

### Incident Management System
- Anonymous and authenticated incident reporting
- 5×5 risk assessment matrix
- GPS/map-based location selection
- LDAP integration for user identification
- Email notifications for workflow transitions
- Custom folder listing views

### Hazard Management System
- Comprehensive hazard reporting forms
- Risk rating auto-calculation
- Progressive mobile-optimized forms
- Photo attachment support
- Suggested controls and corrective actions
- Custom risk-focused folder listings

### Technical Features
- Plone 6.1 Classic site architecture
- LDAP/Active Directory authentication
- Custom Barceloneta theme
- Button-grid folder navigation
- Automated content migration with AI metadata extraction
- Professional deployment pipeline

---

## Quick Start

### Prerequisites
- SSH access to whsportaldev server as `cscadmin`
- Python 3.11+ with pip
- Build tools: `setuptools`, `wheel`

### Deploy an Addon

```bash
# Navigate to project root
cd /home/ceo/Development/WHSPortal

# Deploy the core addon
./deploy-systemd.sh csc

# Deploy the theme
./deploy-systemd.sh theme

# Deploy both
./deploy-systemd.sh both
```

### Service Management

```bash
# Check service status
sudo systemctl status plone

# View logs
sudo journalctl -u plone -f

# Manual restart (if needed)
sudo systemctl restart plone
```

---

## Development Team

- **Organization:** Cook Shire Council
- **Team Size:** 5 IT staff supporting 180 organizational staff
- **Stakeholder:** WHS Office
- **Development Environment:** Local Ubuntu VM → whsportaldev server

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| v0.9.20 | 2025-10-12 | Complete hazard system + custom folder listings |
| v0.9.17 | 2025-10-11 | Hazard workflow and permissions complete |
| v0.7.7.2 | 2025-10-09 | Enhanced incident forms with progressive sections |

See `PROJECT_STATUS.md` for complete version history.

---

## Support

For questions or issues:
- Review documentation in this repository
- Check addon-specific repositories for feature details
- Contact WHS Portal development team

---

## License

**Internal use only** - Cook Shire Council

---

**Last Updated:** 2025-10-13
**Repository:** https://github.com/Cook-Shire-Council/whsportal-deployment
**Project Phase:** Demo-ready
