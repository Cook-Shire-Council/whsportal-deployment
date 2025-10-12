#!/usr/bin/env python3
"""Run the upgrade_1013_to_1014 function manually."""

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

# Get Plone site
site = app['Plone']

# Login as admin
user = app.acl_users.getUser('admin')
if user:
    user = user.__of__(app.acl_users)
    newSecurityManager(None, user)
    print("✓ Logged in as admin")
else:
    print("✗ Could not find admin user")
    sys.exit(1)

# Import and run the upgrade
from cook.whs.barceloneta.upgrades import upgrade_1013_to_1014

print("\n" + "="*60)
print("Running upgrade_1013_to_1014...")
print("="*60 + "\n")

try:
    upgrade_1013_to_1014(site)
    print("\n✓ Upgrade completed successfully!")
except Exception as e:
    print(f"\n✗ Upgrade failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

# Commit transaction
import transaction
transaction.commit()
print("✓ Transaction committed")

print("\nDone! Check ZMI → acl_users → pasldap → Properties → users → attrmap")
print("Should now contain: job_title → title, manager → manager")
