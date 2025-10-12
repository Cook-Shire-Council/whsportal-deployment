# CSC.TEAMS ADDON - Implementation Status & Plan

## Overview
The `csc.teams` addon provides a simple, reference-based team listing system that displays live user data from LDAP/Active Directory without duplicating or allowing modification of user information.

## Design Philosophy
- **Single source of truth**: All user data comes from LDAP/memberdata
- **Reference-based**: Team content stores only user IDs, not user data
- **Read-only display**: No field editing - only IT/HR modifies user data
- **Reusable**: Theme-independent, works across multiple Plone sites
- **Simple workflow**: WHS Officer selects users via searchable picker

## Current Implementation Status

### ✅ COMPLETED (95% of structure)

#### 1. Package Structure
```
/home/ceo/Development/WHSPortal/csc.teams/
├── pyproject.toml                 # Package metadata, dependencies
├── README.md                      # Documentation
├── MANIFEST.in                    # Package files to include
└── src/csc/teams/
    ├── __init__.py               # Package initializer
    ├── configure.zcml            # Main ZCML configuration
    ├── interfaces.py             # Browser layer interface
    ├── content/
    │   ├── __init__.py
    │   └── team.py               # Team content type schema
    └── profiles/
        ├── default/
        │   ├── metadata.xml       # Profile version 1000
        │   ├── browserlayer.xml   # ICSCTeamsLayer
        │   ├── types.xml          # Register Team type
        │   └── types/
        │       └── Team.xml       # Team FTI definition
        └── uninstall/
            ├── metadata.xml
            └── browserlayer.xml
```

#### 2. Team Content Type (`content/team.py`)
**Schema Fields:**
- `members` (List of Choice): User selection using `plone.app.vocabularies.Users`
  - Uses Volto/React select widget with vocabulary lookup
  - Searchable, auto-complete interface
  - Multi-select for multiple users

- `description` (RichText): Team description

**Display Options (fieldset):**
- `show_portraits` (Bool): Show user portraits (default: True)
- `show_contact_info` (Bool): Show email/phone/mobile (default: True)
- `show_job_info` (Bool): Show job title/department (default: True)
- `show_manager` (Bool): Show manager name (default: False)
- `sort_by` (Choice): Sort order - fullname, job_title, department, none

**Key Features:**
- Frontend widget configured for Volto compatibility
- All fields optional except sort_by
- Clean separation of content from display options

#### 3. GenericSetup Profile
- Profile registered in configure.zcml
- Browser layer for view registration
- Team FTI properly configured:
  - Global add permission
  - Default view
  - Dexterity container type
  - Dublin Core + Name from title behaviors

#### 4. Dependencies
**Already defined in pyproject.toml:**
- Plone >= 6.1
- plone.app.dexterity
- plone.app.contenttypes
- Products.GenericSetup >= 1.8.2
- plone.autoform
- plone.supermodel

---

## 🚧 REMAINING WORK (Est. 1.5-2 hours)

### Phase 1: Browser Views (45 mins)

#### A. Create Team View (`browser/views.py`)
**Purpose**: Render team members with their live LDAP data

**Class**: `TeamView(BrowserView)`

**Methods needed:**
```python
def get_team_members(self):
    """Get member info for all users in self.context.members.

    Returns: List[dict] with structure:
    {
        'username': 'johnsmith',
        'fullname': 'John Smith',
        'email': 'john.smith@cook.qld.gov.au',
        'phone': '07 4000 1234',
        'mobile': '0400 123 456',
        'job_title': 'WHS Officer',
        'department': 'Safety',
        'manager_name': 'Jane Doe',  # Extracted from DN
        'portrait_url': '/portal_memberdata/portraits/johnsmith',
    }
    """
    members = []
    for username in self.context.members or []:
        user_data = self._get_user_data(username)
        if user_data:
            members.append(user_data)

    # Sort according to context.sort_by
    return self._sort_members(members)

def _get_user_data(self, username):
    """Fetch live data from Plone user + memberdata."""
    user = api.user.get(username=username)
    if not user:
        return None

    # Get memberdata with LDAP attributes
    memberdata = user.getUser()

    # Extract manager name using utility from cook.whs.barceloneta
    from cook.whs.barceloneta.utils import extract_cn_from_dn
    manager_dn = getattr(memberdata, 'manager', '')

    return {
        'username': username,
        'fullname': user.getProperty('fullname', ''),
        'email': user.getProperty('email', ''),
        'phone': getattr(memberdata, 'phone', ''),
        'mobile': getattr(memberdata, 'mobile', ''),
        'job_title': getattr(memberdata, 'job_title', ''),
        'department': getattr(memberdata, 'department', ''),
        'manager_name': extract_cn_from_dn(manager_dn),
        'portrait_url': self._get_portrait_url(username),
    }

def _get_portrait_url(self, username):
    """Get portrait URL from portal_memberdata or default."""
    portal = api.portal.get()
    portraits = portal.portal_memberdata.portraits
    if username in portraits:
        return f"{portal.absolute_url()}/portal_memberdata/portraits/{username}"
    return f"{portal.absolute_url()}/defaultUser.png"

def _sort_members(self, members):
    """Sort members according to context.sort_by."""
    sort_by = getattr(self.context, 'sort_by', 'fullname')
    if sort_by == 'none':
        return members

    key_map = {
        'fullname': 'fullname',
        'job_title': 'job_title',
        'department': 'department',
    }
    key = key_map.get(sort_by, 'fullname')
    return sorted(members, key=lambda m: m.get(key, '').lower())
```

#### B. Create Template (`browser/templates/team_view.pt`)
**Structure**:
```xml
<html metal:use-macro="context/main_template/macros/master">
  <metal:content-core fill-slot="content-core">

    <!-- Team title (automatic) -->
    <!-- Team description (if provided) -->
    <div class="team-description"
         tal:condition="context/description"
         tal:content="structure context/description/output">
    </div>

    <!-- Team members grid -->
    <div class="team-members-grid"
         tal:define="members view/get_team_members">

      <tal:member repeat="member members">
        <div class="team-member-card">

          <!-- Portrait (conditional) -->
          <div class="member-portrait"
               tal:condition="context/show_portraits">
            <img tal:attributes="src member/portrait_url;
                                 alt string:${member/fullname} photo" />
          </div>

          <!-- Name -->
          <h3 class="member-name" tal:content="member/fullname">
            John Smith
          </h3>

          <!-- Job info (conditional) -->
          <div class="member-job-info"
               tal:condition="context/show_job_info">
            <div class="job-title" tal:content="member/job_title">
              WHS Officer
            </div>
            <div class="department" tal:content="member/department">
              Safety Team
            </div>
          </div>

          <!-- Manager (conditional) -->
          <div class="member-manager"
               tal:condition="python:context.show_manager and member.get('manager_name')"
               tal:content="string:Manager: ${member/manager_name}">
            Manager: Jane Doe
          </div>

          <!-- Contact info (conditional) -->
          <div class="member-contact"
               tal:condition="context/show_contact_info">
            <div tal:condition="member/email">
              <a tal:attributes="href string:mailto:${member/email}"
                 tal:content="member/email">email</a>
            </div>
            <div tal:condition="member/phone"
                 tal:content="member/phone">Phone</div>
            <div tal:condition="member/mobile"
                 tal:content="member/mobile">Mobile</div>
          </div>

        </div>
      </tal:member>

      <!-- Empty state -->
      <div class="no-members-message"
           tal:condition="not:members">
        <p>No team members selected. Edit this team to add members.</p>
      </div>

    </div>
  </metal:content-core>
</html>
```

#### C. Register View (`browser/configure.zcml`)
```xml
<configure xmlns="http://namespaces.zope.org/zope"
           xmlns:browser="http://namespaces.zope.org/browser">

  <browser:resourceDirectory
      name="csc.teams"
      directory="static"
      layer="..interfaces.ICSCTeamsLayer"
      />

  <browser:page
      name="view"
      for="..content.team.ITeam"
      class=".views.TeamView"
      template="templates/team_view.pt"
      permission="zope2.View"
      layer="..interfaces.ICSCTeamsLayer"
      />

</configure>
```

**Update main configure.zcml to include browser:**
```xml
<include package=".browser" />
```

---

### Phase 2: Styling (30 mins)

#### Create `browser/static/teams.css`

```css
/* Team listing styles */

.team-description {
    margin-bottom: 2rem;
    padding: 1rem;
    background: #f8f9fa;
    border-left: 4px solid #007bb1;
}

.team-members-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 2rem;
    margin-top: 2rem;
}

.team-member-card {
    background: #fff;
    border: 1px solid #ddd;
    border-radius: 8px;
    padding: 1.5rem;
    text-align: center;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    transition: box-shadow 0.3s, transform 0.3s;
}

.team-member-card:hover {
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    transform: translateY(-2px);
}

.member-portrait {
    margin-bottom: 1rem;
}

.member-portrait img {
    width: 150px;
    height: 150px;
    border-radius: 50%;
    object-fit: cover;
    border: 3px solid #007bb1;
}

.member-name {
    font-size: 1.3rem;
    margin: 0 0 0.5rem 0;
    color: #333;
}

.member-job-info {
    margin: 0.75rem 0;
    color: #666;
}

.member-job-info .job-title {
    font-weight: 600;
    color: #444;
}

.member-job-info .department {
    font-size: 0.9rem;
    font-style: italic;
}

.member-manager {
    font-size: 0.9rem;
    color: #777;
    margin: 0.5rem 0;
}

.member-contact {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid #eee;
    font-size: 0.9rem;
}

.member-contact div {
    margin: 0.25rem 0;
}

.member-contact a {
    color: #007bb1;
    text-decoration: none;
}

.member-contact a:hover {
    text-decoration: underline;
}

.no-members-message {
    grid-column: 1 / -1;
    text-align: center;
    padding: 3rem;
    color: #999;
    font-style: italic;
}

/* Responsive */
@media (max-width: 768px) {
    .team-members-grid {
        grid-template-columns: 1fr;
        gap: 1.5rem;
    }
}

@media (min-width: 1200px) {
    .team-members-grid {
        grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    }
}
```

#### Register CSS in profile (`profiles/default/cssregistry.xml`)
```xml
<?xml version="1.0"?>
<object name="portal_css">
  <stylesheet
      id="++resource++csc.teams/teams.css"
      expression=""
      enabled="True"
      />
</object>
```

---

### Phase 3: Deployment Setup (15 mins)

#### A. Create deployment script
Copy and adapt `deploy.sh` from theme addon:

```bash
#!/bin/bash
# Deploy script for csc.teams addon

ADDON_NAME="csc.teams"
WHEEL_NAME="csc_teams"

# Navigate to addon directory
cd "$(dirname "$0")"

echo "Deploying ${ADDON_NAME}..."

# Clean previous builds
rm -rf build/ dist/ src/*.egg-info

# Build wheel
python -m build --wheel

# Get version from pyproject.toml
VERSION=$(grep "^version = " pyproject.toml | cut -d'"' -f2)

# Copy to server
scp "dist/${WHEEL_NAME}-${VERSION}-py3-none-any.whl" whsportaldev:/tmp/whs_deploy/

# Install on server
ssh whsportaldev "/opt/plone/venv/bin/pip install --force-reinstall /tmp/whs_deploy/${WHEEL_NAME}-${VERSION}-py3-none-any.whl"

echo "✓ Deployed ${ADDON_NAME} v${VERSION}"
echo "⚠ Plone instance restart required"
```

#### B. Create browser/__init__.py and browser/views.py

**`browser/__init__.py`**: Empty file

**`browser/views.py`**: Implement TeamView class (see Phase 1A above)

---

### Phase 4: Testing & Documentation (20 mins)

#### A. Test Installation
1. Deploy addon to server
2. Restart Plone
3. Install via Site Setup → Add-ons
4. Verify Team content type appears in Add menu

#### B. Test Functionality
1. Create a Team content item
2. Add team members using user picker
3. Configure display options
4. Verify:
   - User data displays correctly
   - LDAP fields show (phone, mobile, job_title, department, manager)
   - Portraits work (if uploaded to Plone)
   - Sorting works
   - Display options are respected

#### C. Update README.md
Add usage examples, screenshots if possible

---

## Implementation Order (Recommended)

1. **Create browser structure**:
   ```bash
   cd /home/ceo/Development/WHSPortal/csc.teams/src/csc/teams
   mkdir -p browser/templates browser/static
   touch browser/__init__.py
   ```

2. **Write browser/views.py** (TeamView class - see Phase 1A)

3. **Write browser/templates/team_view.pt** (see Phase 1B)

4. **Write browser/configure.zcml** (see Phase 1C)

5. **Update main configure.zcml** to include browser package

6. **Write browser/static/teams.css** (see Phase 2)

7. **Create profiles/default/cssregistry.xml** (see Phase 2)

8. **Build and deploy**:
   ```bash
   cd /home/ceo/Development/WHSPortal/csc.teams
   python -m build --wheel
   # Copy wheel to server and install
   ```

9. **Test in Plone**:
   - Install addon
   - Create test team
   - Verify display

---

## Key Dependencies on Theme Addon

**IMPORTANT**: The `csc.teams` addon uses a utility function from the theme:

```python
from cook.whs.barceloneta.utils import extract_cn_from_dn
```

This extracts clean manager names from LDAP DNs. The theme addon must be installed for this to work.

**Alternative**: Copy `extract_cn_from_dn()` function into `csc.teams` to make it fully independent.

---

## Future Enhancements (Not in scope)

1. **Folder view**: A view for folders that lists all Team objects
2. **LDAP group integration**: Auto-populate from AD groups
3. **Export functionality**: CSV/PDF exports
4. **Org chart visualization**: Hierarchical display using manager relationships
5. **Bulk operations**: Mass update display settings
6. **Custom portraits**: Allow Team-specific portrait overrides

---

## File Checklist

### ✅ Already Created:
- [x] pyproject.toml
- [x] README.md
- [x] MANIFEST.in
- [x] src/csc/__init__.py
- [x] src/csc/teams/__init__.py
- [x] src/csc/teams/configure.zcml
- [x] src/csc/teams/interfaces.py
- [x] src/csc/teams/content/__init__.py
- [x] src/csc/teams/content/team.py
- [x] src/csc/teams/profiles/default/metadata.xml
- [x] src/csc/teams/profiles/default/browserlayer.xml
- [x] src/csc/teams/profiles/default/types.xml
- [x] src/csc/teams/profiles/default/types/Team.xml
- [x] src/csc/teams/profiles/uninstall/metadata.xml
- [x] src/csc/teams/profiles/uninstall/browserlayer.xml

### ⏳ To Create:
- [ ] src/csc/teams/browser/__init__.py
- [ ] src/csc/teams/browser/configure.zcml
- [ ] src/csc/teams/browser/views.py
- [ ] src/csc/teams/browser/templates/team_view.pt
- [ ] src/csc/teams/browser/static/teams.css
- [ ] src/csc/teams/profiles/default/cssregistry.xml
- [ ] deploy.sh (optional - can use manual build/install)

---

## Quick Start for Next Session

```bash
# 1. Navigate to addon
cd /home/ceo/Development/WHSPortal/csc.teams/src/csc/teams

# 2. Create browser structure
mkdir -p browser/templates browser/static
touch browser/__init__.py

# 3. Create files using the templates above in this order:
#    - browser/views.py
#    - browser/templates/team_view.pt
#    - browser/configure.zcml
#    - browser/static/teams.css
#    - profiles/default/cssregistry.xml

# 4. Update main configure.zcml to include browser

# 5. Build
cd /home/ceo/Development/WHSPortal/csc.teams
python -m build --wheel

# 6. Deploy
scp dist/*.whl whsportaldev:/tmp/
ssh whsportaldev "/opt/plone/venv/bin/pip install /tmp/csc_teams-1.0.0-py3-none-any.whl"

# 7. Restart Plone
ssh whsportaldev "screen -X -S plone quit; sleep 2; screen -dmS plone bash -c 'cd /opt/plone && /opt/plone/venv/bin/runwsgi -v /opt/plone/instance/etc/zope.ini'"

# 8. Install addon in Plone UI
# Site Setup → Add-ons → Install "CSC Teams"
```

---

## Expected Timeline

- **Browser views/templates**: 45 minutes
- **CSS styling**: 30 minutes
- **Deployment/testing**: 15 minutes
- **Total**: ~1.5 hours for a working addon

This is a straightforward implementation since all the complex parts (content type, schema, user vocabulary) are already done. It's just the display layer remaining.
