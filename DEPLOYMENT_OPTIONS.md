# WHS Portal Deployment Options

## Problem Statement

The current screen-based deployment has reliability issues:
- Screen sessions fail intermittently
- No process supervision (crashes aren't auto-recovered)
- Difficult to verify service state
- Manual intervention often required

## Solution 1: Systemd Service (RECOMMENDED)

### Why Systemd?

**Advantages:**
- ✅ Standard Linux service management
- ✅ Automatic startup on server boot
- ✅ Automatic restart on crash (`Restart=always`)
- ✅ Better logging (journalctl integration)
- ✅ No password required (with sudoers config)
- ✅ Reliable status checking
- ✅ Process supervision built-in
- ✅ Integration with system monitoring tools

**Disadvantages:**
- Requires one-time setup
- Requires sudo access for initial installation

### Setup Steps

#### 1. One-Time Installation (on whsportaldev)

```bash
# From your local machine, copy files to server
cd /home/ceo/Development/WHSPortal
scp plone.service sudoers.d-plone setup-systemd.sh whsportaldev:~

# SSH to server and run setup
ssh whsportaldev
cd ~
chmod +x setup-systemd.sh
./setup-systemd.sh
```

#### 2. Verify Installation

```bash
# Check service status
sudo systemctl status plone

# View logs
sudo journalctl -u plone -f

# Test passwordless restart (after sudoers configured)
systemctl restart plone  # No sudo needed!
```

#### 3. Use New Deployment Script

```bash
# Back on your local machine
cd /home/ceo/Development/WHSPortal

# Deploy using systemd
./deploy-systemd.sh csc        # Deploy csc.whs
./deploy-systemd.sh theme      # Deploy theme
./deploy-systemd.sh both       # Deploy both
```

### Service Management Commands

```bash
# Start Plone
sudo systemctl start plone

# Stop Plone
sudo systemctl stop plone

# Restart Plone
sudo systemctl restart plone

# Check status
sudo systemctl status plone

# View logs (live)
sudo journalctl -u plone -f

# View last 100 log entries
sudo journalctl -u plone -n 100

# Check if service is running
systemctl is-active plone
```

### How It Works

1. **deploy-systemd.sh** builds and installs wheel (same as current deploy.sh)
2. Instead of screen, uses: `sudo systemctl restart plone`
3. Systemd:
   - Stops old process cleanly
   - Starts new process
   - Monitors it continuously
   - Restarts automatically if it crashes
   - Logs everything to journal

### Troubleshooting

**If service fails to start:**
```bash
# Check detailed logs
sudo journalctl -u plone -n 200 --no-pager

# Check service status
sudo systemctl status plone -l

# Try starting manually to see errors
sudo /opt/plone/venv/bin/runwsgi -v /opt/plone/instance/etc/zope.ini
```

**If sudoers not working:**
```bash
# Test sudoers file syntax
sudo visudo -c -f /etc/sudoers.d/plone

# Check file permissions
ls -la /etc/sudoers.d/plone  # Should be 440
```

---

## Solution 2: Ansible Deployment (Alternative)

### Why Ansible?

**Advantages:**
- ✅ Idempotent (can run multiple times safely)
- ✅ Better error handling and rollback
- ✅ Can manage multiple servers
- ✅ Built-in systemd module
- ✅ Structured logging
- ✅ Can be integrated into CI/CD

**Disadvantages:**
- Requires Ansible installation
- More complex setup
- Slower than direct bash script

### Setup Steps

#### 1. Install Ansible (on your local machine)

```bash
# Ubuntu/Debian
sudo apt install ansible

# Verify
ansible --version
```

#### 2. Test Connectivity

```bash
cd /home/ceo/Development/WHSPortal/ansible
ansible -i inventory.ini whsportaldev -m ping
```

#### 3. Deploy Using Ansible

```bash
cd /home/ceo/Development/WHSPortal/ansible

# Deploy csc.whs
ansible-playbook -i inventory.ini deploy-plone.yml -e "addon=csc"

# Deploy theme
ansible-playbook -i inventory.ini deploy-plone.yml -e "addon=theme"

# Deploy both
ansible-playbook -i inventory.ini deploy-plone.yml -e "addon=both"
```

### Ansible Output

Ansible provides detailed output:
- ✅ Clear success/failure per task
- ✅ Changed/unchanged status
- ✅ Timing information
- ✅ Idempotency checking

---

## Solution 3: Improved Screen Script (Fallback)

If you want to keep using screen but improve reliability:

### Issues with Current deploy.sh

1. **Doesn't check if screen session already exists** before creating new one
2. **Doesn't verify Plone actually started** after screen creation
3. **Race condition**: pkill might not finish before screen starts
4. **No status verification** reported to user

### Improvements Made (in current deploy.sh)

```bash
# 1. Explicitly kill screen session first
ssh ${DEV_SERVER} "screen -S plone -X quit 2>/dev/null || true"

# 2. Kill processes
ssh ${DEV_SERVER} "pkill -f 'runwsgi.*zope.ini' || true"

# 3. Wait longer for cleanup
sleep 3

# 4. Start new screen
ssh ${DEV_SERVER} "cd /opt/plone && screen -dmS plone ..."

# 5. Wait for startup
sleep 5

# 6. VERIFY it started
if ssh ${DEV_SERVER} "pgrep -f 'runwsgi.*zope.ini' > /dev/null"; then
    print_success "Plone instance restarted successfully"
else
    print_warning "Plone may not have started successfully"
fi
```

### Why Screen Still Fails Sometimes

- **SSH command timing**: Commands might timeout or be blocked
- **Screen session persistence**: Dead sessions might linger
- **Process cleanup**: pkill might not complete before screen starts
- **No supervision**: If Plone crashes after starting, nothing restarts it

---

## Comparison Matrix

| Feature | Screen | Systemd | Ansible |
|---------|--------|---------|---------|
| Auto-restart on crash | ❌ | ✅ | ✅ |
| Boot persistence | ❌ | ✅ | ✅ |
| Status verification | ⚠️ | ✅ | ✅ |
| Logging | ⚠️ | ✅ | ✅ |
| Setup complexity | Low | Medium | High |
| Reliability | Low | High | High |
| Speed | Fast | Fast | Slow |
| Multi-server | ❌ | ❌ | ✅ |
| Process supervision | ❌ | ✅ | ✅ |
| Passwordless restart | N/A | ✅ | ✅ |

---

## Recommendations

### For Immediate Use: Systemd (Option 1)

**Reasoning:**
1. Most reliable solution
2. Standard Linux practice
3. Built-in supervision
4. Easy to manage
5. Works with Claude's workflow (can verify status)

**Migration Path:**
1. Run `setup-systemd.sh` once on whsportaldev
2. Switch to `deploy-systemd.sh` for future deployments
3. Keep old `deploy.sh` as backup

### For Future: Consider Ansible (Option 2)

**When to use:**
- If you add more servers
- If you want to automate other configuration tasks
- If you integrate with CI/CD pipeline
- If you need audit trail of deployments

---

## Why Current System Fails

After analyzing the issue, the problem isn't the deploy.sh script itself - it's that:

1. **I can't reliably verify state** via SSH from Claude
   - Some commands work, some are blocked
   - Makes it impossible for me to confirm Plone is running

2. **Screen sessions are unreliable**
   - Dead sessions accumulate
   - Hard to detect if session is actually working
   - No automatic recovery

3. **No process supervision**
   - If Plone crashes 30 seconds after deploy, no one knows
   - Requires manual intervention to restart

**Systemd solves all three problems:**
- Standard, reliable status API (`systemctl is-active`)
- Automatic crash recovery
- Built-in process supervision

---

## Files Created

### Systemd Setup
- `plone.service` - Systemd service definition
- `sudoers.d-plone` - Passwordless sudo configuration
- `setup-systemd.sh` - One-time installation script
- `deploy-systemd.sh` - New deployment script using systemd

### Ansible Setup
- `ansible/deploy-plone.yml` - Ansible playbook
- `ansible/inventory.ini` - Server inventory

### Documentation
- `DEPLOYMENT_OPTIONS.md` - This file

---

## Next Steps

1. **Review these options** and choose which approach fits your workflow
2. **Test systemd setup** on whsportaldev (recommended)
3. **If systemd works well**, deprecate screen-based deployment
4. **Update .claude_instructions** with new deployment method

Would you like me to:
- Create a migration checklist?
- Add more error handling to any of these scripts?
- Create systemd setup for csc.teams as well?
