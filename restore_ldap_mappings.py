#!/usr/bin/env python3
"""Restore job_title and manager LDAP mappings."""

import sys
sys.path.insert(0, '/opt/plone/venv/lib/python3.12/site-packages')

from AccessControl.SecurityManagement import newSecurityManager
from Testing.makerequest import makerequest
from zope.globalrequest import setRequest
import Zope2

# Start Zope
app = Zope2.app()
app = makerequest(app)
setRequest(app.REQUEST)

# Get site
site = app['whsportal']

# Login as admin
user = app.acl_users.getUser('admin')
if not user:
    print("✗ Could not find admin user")
    sys.exit(1)

user = user.__of__(app.acl_users)
newSecurityManager(None, user)
print("✓ Logged in as admin")

# Get LDAP plugin
acl_users = site.acl_users
if 'pasldap' not in acl_users.objectIds():
    print("✗ LDAP plugin not found!")
    sys.exit(1)

ldap_plugin = acl_users['pasldap']
print("✓ Found LDAP plugin")

# Get current attribute map
attrmap = ldap_plugin.settings.get('users.attrmap')
if not attrmap:
    print("✗ Cannot access users.attrmap!")
    sys.exit(1)

print("\nCurrent LDAP attribute mappings:")
for key in sorted(attrmap.keys()):
    print(f"  {key} → {attrmap[key]}")

# Add job_title mapping
if 'job_title' not in attrmap:
    attrmap['job_title'] = 'title'
    print("\n✓ Added LDAP mapping: job_title → title")
else:
    print(f"\n  job_title already mapped to {attrmap['job_title']}")

# Add manager mapping
if 'manager' not in attrmap:
    attrmap['manager'] = 'manager'
    print("✓ Added LDAP mapping: manager → manager")
else:
    print(f"  manager already mapped to {attrmap['manager']}")

# Mark as changed
ldap_plugin._p_changed = True

print("\nUpdated LDAP attribute mappings:")
for key in sorted(attrmap.keys()):
    print(f"  {key} → {attrmap[key]}")

# Commit transaction
import transaction
transaction.commit()
print("\n✓ Transaction committed")
print("\nDone! Check ZMI → whsportal → acl_users → pasldap → Properties")
