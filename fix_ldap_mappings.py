#!/usr/bin/env python3
"""
Script to add job_title and manager LDAP attribute mappings.
Run this in the Plone zconsole:

    cd /opt/plone
    /opt/plone/venv/bin/zconsole debug instance/etc/zope.conf
    >>> exec(open('/tmp/whs_deploy/fix_ldap_mappings.py').read())
"""

from plone import api

print('=' * 60)
print('Adding job_title and manager LDAP attribute mappings')
print('=' * 60)

# Get LDAP plugin
acl_users = api.portal.get_tool('acl_users')
if 'pasldap' not in acl_users.objectIds():
    print('ERROR: LDAP plugin (pasldap) not found!')
    exit(1)

ldap_plugin = acl_users['pasldap']

# Get attrmap - settings is a FLAT OOBTree with dotted keys
attrmap = ldap_plugin.settings.get('users.attrmap')

if not attrmap:
    print('ERROR: Cannot access users.attrmap!')
    exit(1)

print('\nCurrent LDAP attribute mappings:')
for key in sorted(attrmap.keys()):
    print(f'  {key:20s} -> {attrmap[key]}')

# Add job_title mapping (maps to AD 'title' attribute for job position)
if 'job_title' not in attrmap:
    attrmap['job_title'] = 'title'
    print('\n✓ Added LDAP mapping: job_title → title (AD job position)')
else:
    print(f'\n  job_title already mapped to {attrmap["job_title"]}')

# Add manager mapping (for org chart)
if 'manager' not in attrmap:
    attrmap['manager'] = 'manager'
    print('✓ Added LDAP mapping: manager → manager (for org chart)')
else:
    print(f'  manager already mapped to {attrmap["manager"]}')

# Persist changes
ldap_plugin._p_changed = True
print('\n✓ Changes persisted to LDAP plugin')

# Clear cache
try:
    if hasattr(ldap_plugin, '_cache'):
        ldap_plugin._cache.clear()
        print('✓ Cache cleared')
except Exception as e:
    print(f'Warning: Could not clear cache: {e}')

# Commit transaction
import transaction
transaction.commit()
print('✓ Transaction committed')

print('\n' + '=' * 60)
print('Updated LDAP attribute mappings:')
for key in sorted(attrmap.keys()):
    print(f'  {key:20s} -> {attrmap[key]}')
print('=' * 60)
print('\nDONE! Restart Plone for changes to take effect.')
