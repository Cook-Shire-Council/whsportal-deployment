# Systemd Migration Checklist

## Pre-Migration

- [ ] Review DEPLOYMENT_OPTIONS.md
- [ ] Verify SSH access to whsportaldev works
- [ ] Backup current deployment (optional - just note current version)
- [ ] Current version: **v0.9.10**

## Migration Steps

### 1. Copy Files to Server

```bash
cd /home/ceo/Development/WHSPortal
scp plone.service sudoers.d-plone setup-systemd.sh whsportaldev:~
```

- [ ] Files copied successfully

### 2. Run Setup Script

```bash
ssh whsportaldev
cd ~
chmod +x setup-systemd.sh
./setup-systemd.sh
```

**Expected output:**
- Service file installed
- Sudoers configured
- Systemd reloaded
- Plone service started
- Status shows "active (running)"

- [ ] Setup completed without errors
- [ ] Plone service status shows "active"

### 3. Verify Service

```bash
# Check status
sudo systemctl status plone

# Should show:
#   Active: active (running)
#   Main PID: [number]
```

- [ ] Service is active
- [ ] Can view logs with `sudo journalctl -u plone -f`

### 4. Test Passwordless Restart

```bash
# This should work WITHOUT sudo after sudoers is configured
systemctl restart plone

# If it asks for password, sudoers didn't install correctly
```

- [ ] Can restart without password
- [ ] Service comes back up after restart

### 5. Test Website

```bash
# Wait 30 seconds after restart, then:
curl -I https://whsportal.cook.qld.gov.au
```

- [ ] Website is accessible
- [ ] Returns HTTP 200 OK (or redirect to login)

### 6. Test New Deployment Script

```bash
cd /home/ceo/Development/WHSPortal

# Make a trivial change to test deployment
# (or just re-deploy current version)
./deploy-systemd.sh csc
```

**Expected output:**
- Wheel builds successfully
- Copies to server
- Installs via pip
- Restarts via systemd
- Status shows "active" after restart

- [ ] Deployment script works
- [ ] Plone restarts correctly
- [ ] Website accessible after deployment

## Post-Migration

### 7. Update Documentation

- [ ] Update .claude_instructions to mention systemd deployment
- [ ] Note that deploy-systemd.sh is now primary deployment method
- [ ] Keep deploy.sh as backup

### 8. Test Failure Recovery

```bash
# Kill Plone process manually to test auto-restart
ssh whsportaldev
sudo pkill -9 -f runwsgi

# Wait 10 seconds
sleep 10

# Check if systemd restarted it
sudo systemctl status plone
# Should show: active (running) with new PID
```

- [ ] Systemd automatically restarted Plone after crash

## Rollback Plan (if needed)

If systemd doesn't work, rollback:

```bash
# Stop and disable systemd service
sudo systemctl stop plone
sudo systemctl disable plone

# Remove service file
sudo rm /etc/systemd/system/plone.service
sudo systemctl daemon-reload

# Start using old method
cd /opt/plone
screen -dmS plone /opt/plone/venv/bin/runwsgi -v /opt/plone/instance/etc/zope.ini

# Use old deploy.sh script
cd /home/ceo/Development/WHSPortal
./deploy.sh csc
```

## Troubleshooting

### Issue: Service fails to start

```bash
# Check detailed logs
sudo journalctl -u plone -n 200 --no-pager

# Common issues:
# - Port 8080 already in use (kill old process)
# - Permissions issue (check /opt/plone ownership)
# - Python environment issue (verify venv)
```

### Issue: Sudoers not working

```bash
# Verify sudoers file syntax
sudo visudo -c -f /etc/sudoers.d/plone

# Should output: "parsed OK"

# Check permissions
ls -la /etc/sudoers.d/plone
# Should be: -r--r----- 1 root root ... plone

# If wrong permissions:
sudo chmod 440 /etc/sudoers.d/plone
```

### Issue: Website not accessible

```bash
# Check if Plone is actually listening
ssh whsportaldev 'sudo netstat -tlnp | grep 8080'

# Check nginx status
ssh whsportaldev 'sudo systemctl status nginx'

# Check Plone logs for errors
ssh whsportaldev 'sudo journalctl -u plone -n 100'
```

## Success Criteria

Migration is successful when:

- ✅ Plone runs as systemd service
- ✅ Can restart without password (`systemctl restart plone`)
- ✅ Service auto-starts on server boot
- ✅ Service auto-restarts on crash
- ✅ `deploy-systemd.sh` works reliably
- ✅ Website accessible and functional
- ✅ Can view logs with `journalctl`

## Time Estimate

- **Setup**: 15 minutes
- **Testing**: 15 minutes
- **Total**: 30 minutes

## Benefits After Migration

1. **Reliability**: No more "Plone not running" mysteries
2. **Observability**: Clear logs via journalctl
3. **Automation**: Auto-restart on crash
4. **Simplicity**: Standard Linux service management
5. **CI/CD Ready**: Can integrate with automated pipelines

## Notes

- Keep `deploy.sh` as backup for 1-2 weeks
- After successful migration, update all documentation
- Consider similar setup for any other services
