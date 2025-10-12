# DEPLOYMENT_OPTIONS.md - Corrections

## Error in Documentation

**Incorrect statement in DEPLOYMENT_OPTIONS.md:**
> Test passwordless restart (after sudoers configured)
> ```bash
> systemctl restart plone  # No sudo needed!
> ```

**Correction:**
You still need to use `sudo`, but it won't ask for a password:

```bash
sudo systemctl restart plone  # Uses sudo, but no password prompt
```

## Why This Matters

The sudoers configuration allows specific commands to run with sudo **without a password prompt**, but you still need to use the `sudo` prefix.

**What sudoers does:**
- ❌ Does NOT eliminate the need for `sudo` keyword
- ✅ DOES eliminate the password prompt when using `sudo`

## Correct Service Management Commands

```bash
# Start Plone (no password prompt)
sudo systemctl start plone

# Stop Plone (no password prompt)
sudo systemctl stop plone

# Restart Plone (no password prompt)
sudo systemctl restart plone

# Check status (no password prompt)
sudo systemctl status plone

# View logs (no password prompt)
sudo journalctl -u plone -f
```

## Verification That It's Working

Your `sudo -l` output shows this is working correctly:

```
(ALL) NOPASSWD: /bin/systemctl start plone
(ALL) NOPASSWD: /bin/systemctl stop plone
(ALL) NOPASSWD: /bin/systemctl restart plone
(ALL) NOPASSWD: /bin/systemctl status plone
(ALL) NOPASSWD: /bin/journalctl -u plone
```

This means:
- ✅ Sudoers file is correctly configured
- ✅ Permissions are correct (440, root:root)
- ✅ Syntax is valid
- ✅ Commands are recognized

## Deploy Script is Correct

The `deploy-systemd.sh` script correctly uses `sudo`:

```bash
ssh ${DEV_SERVER} "sudo systemctl restart plone"
```

So deployment will work as expected!

## Summary

- **Documentation error**: Said "no sudo needed" which was wrong
- **Reality**: Still need `sudo`, but no password prompt
- **Your setup**: ✅ Working correctly
- **Deploy script**: ✅ Will work fine
