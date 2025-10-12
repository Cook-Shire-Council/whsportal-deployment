#!/usr/bin/env python
"""
Script to manually add job_title and manager LDAP mappings.
Run this in ZMI → Plone site → portal_skins → custom → Add "Script (Python)"
Or run via plonecli console.
"""

# Get LDAP plugin
acl_users = context.acl_users
ldap_plugin = acl_users['pasldap']

# Get current attrmap
attrmap = ldap_plugin.settings.get('users.attrmap')

print("Current LDAP attribute mappings:")
for key, value in sorted(attrmap.items()):
    print(f"  {key} → {value}")

# Remove old description mapping if it exists
if 'description' in attrmap:
    old_value = attrmap.pop('description')
    print(f"\n✓ Removed old mapping: description → {old_value}")

# Add job_title mapping (maps to AD 'title' attribute)
if 'job_title' not in attrmap:
    attrmap['job_title'] = 'title'
    print("✓ Added LDAP mapping: job_title → title (AD job position)")
else:
    print(f"  job_title already mapped to {attrmap['job_title']}")

# Add manager mapping (for org chart)
if 'manager' not in attrmap:
    attrmap['manager'] = 'manager'
    print("✓ Added LDAP mapping: manager → manager (for org chart)")
else:
    print(f"  manager already mapped to {attrmap['manager']}")

# Mark as changed
ldap_plugin._p_changed = True

print("\nUpdated LDAP attribute mappings:")
for key, value in sorted(attrmap.items()):
    print(f"  {key} → {value}")

print("\n✓ LDAP mappings updated successfully!")

# Now update memberdata properties
memberdata = context.portal_memberdata

print("\nCurrent memberdata properties:")
if hasattr(memberdata, '_properties'):
    for prop in memberdata._properties:
        print(f"  {prop['id']} ({prop['type']})")

# Add job_title property if missing
if not hasattr(memberdata, 'job_title'):
    memberdata._setProperty('job_title', '', 'string')
    print("\n✓ Added memberdata property: job_title")
else:
    print("\n  job_title property already exists")

# Add manager property if missing
if not hasattr(memberdata, 'manager'):
    memberdata._setProperty('manager', '', 'string')
    print("✓ Added memberdata property: manager")
else:
    print("  manager property already exists")

print("\n✓ All done! Now add these fields in Site Setup → Users → Member Fields:")
print("  1. Job Title (Text line) → property: job_title")
print("  2. Manager (Text line) → property: manager")

return printed
