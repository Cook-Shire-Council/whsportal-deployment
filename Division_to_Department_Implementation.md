# Phase A Implementation Plan: Division → Department Field

**Version:** csc.whs v0.10.17 → v0.10.18.7
**Profile Version:** 17 → 18
**Status:** ✅ COMPLETE
**Priority:** High
**Estimated Effort:** 6-7 hours (AI-assisted)
**Completion Date:** October 19, 2025

---

## Overview

Replace "Division" field with "Department" field for both Incidents and Hazards. This provides more granular organizational tracking aligned with Cook Shire Council's organizational structure:

- **Directorate** (Level 1): e.g., "Growth and Liveability", "Infrastructure"
- **Department** (Level 2): e.g., "Information & Communications Technology", "Water & Wastewater" ← **NEW TARGET**
- **Teams/Units** (Level 3): Individual work teams

### Key Changes

**Incidents:**
- Change from text field to Choice dropdown
- Auto-populate from LDAP when injured person is selected
- Fallback to manual selection for anonymous reports

**Hazards:**
- Change from text field to Choice dropdown
- Manual selection by reporter (determines which department owns the hazard)

### Change Summary

| Aspect | Current | New |
|--------|---------|-----|
| Field Name | `division` | `department` |
| Field Type | TextLine (free text) | Choice (dropdown) |
| Data Source | Manual entry | Department vocabulary (~20 departments) |
| Incidents | Manual entry | Auto-populated from LDAP (with manual override) |
| Hazards | Manual entry | Manual selection from dropdown |

---

## Implementation Phases

### ✅ Phase 1: Create Department Vocabulary (1 hour)

**Goal:** Define all Cook Shire Council departments in a reusable vocabulary.

#### 1.1 Create Vocabulary Function

**File:** `csc/src/csc/whs/vocabularies.py`

**Add new vocabulary function:**

```python
@provider(IVocabularyFactory)
def department_vocabulary(context):
    """Cook Shire Council Departments

    Based on organizational structure (Oct 2025)
    Source: organisational-chart.pdf (Page 3)

    Returns all departments across 4 directorates:
    - Office of the CEO (5 departments)
    - Growth and Liveability (10 departments)
    - Infrastructure (9 departments)
    - People and Performance (2 departments)
    """
    terms = [
        # Office of the CEO
        SimpleTerm(value='mayor-councillor-support', title='Mayor and Councillor Support'),
        SimpleTerm(value='ceo-support', title='CEO Support'),
        SimpleTerm(value='governance-risk', title='Governance & Risk'),
        SimpleTerm(value='records', title='Records'),
        SimpleTerm(value='grants-admin', title='Grants and Administration'),

        # Growth and Liveability
        SimpleTerm(value='economy-tourism-arts', title='Economy, Tourism & Arts'),
        SimpleTerm(value='community-lifestyle', title='Community Lifestyle'),
        SimpleTerm(value='financial-services', title='Financial Services'),
        SimpleTerm(value='planning-environment', title='Planning & Environment'),
        SimpleTerm(value='biosecurity', title='Biosecurity'),
        SimpleTerm(value='local-laws-animal-control', title='Local Laws & Animal Control'),
        SimpleTerm(value='buildings-facilities', title='Buildings & Facilities'),
        SimpleTerm(value='communications-engagement', title='Communications & Engagement'),
        SimpleTerm(value='ict', title='Information & Communications Technology'),
        SimpleTerm(value='disaster-management', title='Disaster Management'),

        # Infrastructure
        SimpleTerm(value='parks-gardens', title='Parks & Gardens'),
        SimpleTerm(value='water-wastewater', title='Water & Wastewater'),
        SimpleTerm(value='waste-management', title='Waste Management'),
        SimpleTerm(value='engineering', title='Engineering'),
        SimpleTerm(value='fleet-workshop', title='Fleet & Workshop'),
        SimpleTerm(value='roads-civil-works', title='Roads & Civil Works'),
        SimpleTerm(value='project-management', title='Project Management'),
        SimpleTerm(value='airports', title='Airports'),
        SimpleTerm(value='drfa', title='DRFA (Disaster Recovery Funding)'),

        # People and Performance
        SimpleTerm(value='whs', title='Workplace Health & Safety'),
        SimpleTerm(value='human-resources', title='Human Resources'),
    ]
    return SimpleVocabulary(terms)
```

**Notes:**
- Total: 26 departments
- Token format: lowercase-with-dashes
- Title format: Proper case with punctuation
- Source: Organizational chart page 3

#### 1.2 Register Vocabulary

**File:** `csc/src/csc/whs/configure.zcml`

**Add vocabulary registration:**

```xml
<!-- Department Vocabulary -->
<utility
    component=".vocabularies.department_vocabulary"
    name="csc.whs.DepartmentVocabulary"
    />
```

**Location:** Add after other vocabulary registrations (incident types, hazard types, etc.)

#### 1.3 Testing Checklist

- [ ] Vocabulary imports without errors
- [ ] Returns 26 department terms
- [ ] All tokens are lowercase-with-dashes
- [ ] All titles display correctly
- [ ] Vocabulary accessible via name `csc.whs.DepartmentVocabulary`

---

### ✅ Phase 2: Update Schema Definitions (1 hour)

**Goal:** Replace `division` field with `department` field in both Incident and Hazard schemas.

#### 2.1 Update IIncident Schema

**File:** `csc/src/csc/whs/interfaces.py`

**Location:** Section 1B - Person Injured/Involved Details (around line 54-59)

**Current field:**
```python
# Division of the person injured
division = schema.TextLine(
    title=u"Division of the person injured",
    required=True,
    description=u"The division or area that the person injured belongs to.",
)
```

**Replace with:**
```python
# Q7: Department of the person injured
department = schema.Choice(
    title=u"Department of the person injured",
    required=True,
    vocabulary='csc.whs.DepartmentVocabulary',
    description=u"The department that the injured person belongs to. This will auto-populate from Active Directory when you select the person's name above.",
)
```

**Notes:**
- Question number Q7 (verify this is correct)
- Changed from TextLine → Choice
- Added vocabulary reference
- Updated description to mention auto-population

#### 2.2 Update IHazard Schema

**File:** `csc/src/csc/whs/interfaces.py`

**Location:** Section 2 - Hazard Details (around line 54-59 in hazard section)

**Current field:**
```python
# Division primarily associated with hazard
division = schema.TextLine(
    title=u"Division primarily associated with hazard",
    required=True,
    description=u"The division responsible for managing this hazard.",
)
```

**Replace with:**
```python
# Department primarily associated with hazard
department = schema.Choice(
    title=u"Department primarily associated with hazard",
    required=True,
    vocabulary='csc.whs.DepartmentVocabulary',
    description=u"The department responsible for managing this hazard. Select the department best positioned to address this hazard.",
)
```

**Notes:**
- Changed from TextLine → Choice
- Added vocabulary reference
- Updated description to clarify manual selection

#### 2.3 Hide Old Division Field (Backwards Compatibility)

**File:** `csc/src/csc/whs/interfaces.py`

**Add directive to hide old field from edit forms:**

```python
from plone.autoform import directives

# At the top of IIncident class, after other directives
directives.omitted('division')

# At the top of IHazard class, after other directives
directives.omitted('division')
```

**Note:** This keeps the old field in the database but hides it from forms. Ensures existing data remains accessible.

#### 2.4 Testing Checklist

- [ ] Schema validates without errors
- [ ] Department field shows as dropdown in edit form
- [ ] Dropdown populated with 26 departments
- [ ] Old division field hidden from edit forms
- [ ] Required validation works (cannot submit without selecting department)

---

### ✅ Phase 3: LDAP Auto-Population for Incidents (1.5 hours)

**Goal:** When user selects an injured person from LDAP, automatically populate their department.

#### 3.1 Verify LDAP API Returns Department

**File:** `csc/src/csc/whs/ldap_utils.py`

**Check:** Line 158 confirms `department` field is returned by `get_user_details()`:
```python
return {
    'username': username,
    'fullname': fullname,
    'email': email,
    'phone': phone,
    'mobile': mobile,
    'department': department,  # ✅ Already available
    'directorate': directorate,
    'job_title': job_title,
    'manager_dn': manager_dn,
    'manager_name': manager_name,
}
```

**Status:** ✅ No changes needed - department already available from LDAP

#### 3.2 Create Department Name → Token Mapping Function

**File:** `csc/src/csc/whs/utilities.py` (create if doesn't exist)

**Add helper function:**

```python
# -*- coding: utf-8 -*-
"""Utility functions for csc.whs"""

from plone import api
import logging

logger = logging.getLogger('csc.whs.utilities')

# Department name to vocabulary token mapping
# Maps AD department names to our vocabulary tokens
DEPARTMENT_NAME_TO_TOKEN = {
    # Office of the CEO
    'governance': 'governance-risk',
    'records': 'records',
    'grants': 'grants-admin',
    'ceo': 'ceo-support',
    'mayor': 'mayor-councillor-support',
    'councillor': 'mayor-councillor-support',

    # Growth and Liveability
    'economy': 'economy-tourism-arts',
    'tourism': 'economy-tourism-arts',
    'arts': 'economy-tourism-arts',
    'community': 'community-lifestyle',
    'lifestyle': 'community-lifestyle',
    'financial': 'financial-services',
    'finance': 'financial-services',
    'planning': 'planning-environment',
    'environment': 'planning-environment',
    'biosecurity': 'biosecurity',
    'local laws': 'local-laws-animal-control',
    'animal': 'local-laws-animal-control',
    'buildings': 'buildings-facilities',
    'facilities': 'buildings-facilities',
    'communications': 'communications-engagement',
    'engagement': 'communications-engagement',
    'ict': 'ict',
    'information': 'ict',
    'disaster': 'disaster-management',

    # Infrastructure
    'parks': 'parks-gardens',
    'gardens': 'parks-gardens',
    'water': 'water-wastewater',
    'wastewater': 'water-wastewater',
    'waste': 'waste-management',
    'engineering': 'engineering',
    'fleet': 'fleet-workshop',
    'workshop': 'fleet-workshop',
    'roads': 'roads-civil-works',
    'civil': 'roads-civil-works',
    'project': 'project-management',
    'airports': 'airports',
    'drfa': 'drfa',

    # People and Performance
    'whs': 'whs',
    'safety': 'whs',
    'workplace health': 'whs',
    'hr': 'human-resources',
    'human resources': 'human-resources',
}


def map_department_name_to_token(department_name):
    """Map an Active Directory department name to vocabulary token

    Args:
        department_name (str): Department name from LDAP (e.g., "Water & Wastewater")

    Returns:
        str: Vocabulary token (e.g., "water-wastewater") or empty string if no match

    Example:
        >>> map_department_name_to_token("Water & Wastewater")
        "water-wastewater"

        >>> map_department_name_to_token("Information & Communications Technology")
        "ict"
    """
    if not department_name:
        return ''

    # Normalize: lowercase, remove punctuation
    normalized = department_name.lower().strip()

    # Try exact match first
    if normalized in DEPARTMENT_NAME_TO_TOKEN:
        return DEPARTMENT_NAME_TO_TOKEN[normalized]

    # Try keyword matching
    for keyword, token in DEPARTMENT_NAME_TO_TOKEN.items():
        if keyword in normalized:
            logger.debug(f"Mapped department '{department_name}' to '{token}' via keyword '{keyword}'")
            return token

    logger.warning(f"No mapping found for department: {department_name}")
    return ''
```

**Notes:**
- Fuzzy matching via keywords (handles variations in AD names)
- Returns empty string if no match (user can manually select)
- Logs warnings for unmapped departments

#### 3.3 Update LDAP Search Endpoint

**File:** `csc/src/csc/whs/browser/ldap_views.py` (or wherever @@ldap-search is defined)

**Verify response includes department:**

If not already included, ensure the LDAP search view returns department:

```python
# Should already be returning this structure
return {
    'username': user['username'],
    'fullname': user['fullname'],
    'email': user['email'],
    'department': user['department'],  # ✅ Ensure this is included
}
```

**Check existing implementation** - this is likely already correct based on ldap_utils.py

#### 3.4 Add JavaScript Auto-Population

**File:** `csc/src/csc/whs/browser/static/incident_form.js`

**Add auto-population logic:**

```javascript
/**
 * Auto-populate department field when LDAP user is selected
 *
 * Listens to LDAP autocomplete selection and maps department name
 * to vocabulary token, then selects it in the department dropdown.
 */
document.addEventListener('DOMContentLoaded', function() {
    // Get form elements
    const injuredPersonField = document.getElementById('form-widgets-injured_person_name');
    const departmentField = document.getElementById('form-widgets-department');

    if (!injuredPersonField || !departmentField) {
        return; // Fields not present on this form
    }

    // Listen for LDAP autocomplete selection
    // This depends on your existing LDAP autocomplete implementation
    // Adjust the event listener based on your autocomplete library

    injuredPersonField.addEventListener('ldap-user-selected', function(event) {
        const userData = event.detail;

        if (userData && userData.department) {
            // Map department name to vocabulary token
            const departmentToken = mapDepartmentToToken(userData.department);

            if (departmentToken) {
                // Select the mapped department in dropdown
                departmentField.value = departmentToken;

                // Highlight the auto-populated field (visual feedback)
                departmentField.classList.add('auto-populated');
                setTimeout(() => {
                    departmentField.classList.remove('auto-populated');
                }, 2000);

                console.log(`Auto-populated department: ${userData.department} → ${departmentToken}`);
            } else {
                console.warn(`Could not map department: ${userData.department}`);
            }
        }
    });
});

/**
 * Map department name to vocabulary token (client-side)
 *
 * This mirrors the Python mapping logic in utilities.py
 */
function mapDepartmentToToken(departmentName) {
    if (!departmentName) return '';

    const normalized = departmentName.toLowerCase().trim();

    // Department keyword to token mapping
    const mapping = {
        'governance': 'governance-risk',
        'records': 'records',
        'grants': 'grants-admin',
        'ceo': 'ceo-support',
        'mayor': 'mayor-councillor-support',
        'councillor': 'mayor-councillor-support',
        'economy': 'economy-tourism-arts',
        'tourism': 'economy-tourism-arts',
        'community': 'community-lifestyle',
        'financial': 'financial-services',
        'finance': 'financial-services',
        'planning': 'planning-environment',
        'environment': 'planning-environment',
        'biosecurity': 'biosecurity',
        'local laws': 'local-laws-animal-control',
        'animal': 'local-laws-animal-control',
        'buildings': 'buildings-facilities',
        'facilities': 'buildings-facilities',
        'communications': 'communications-engagement',
        'ict': 'ict',
        'information': 'ict',
        'disaster': 'disaster-management',
        'parks': 'parks-gardens',
        'water': 'water-wastewater',
        'wastewater': 'water-wastewater',
        'waste': 'waste-management',
        'engineering': 'engineering',
        'fleet': 'fleet-workshop',
        'workshop': 'fleet-workshop',
        'roads': 'roads-civil-works',
        'civil': 'roads-civil-works',
        'project': 'project-management',
        'airports': 'airports',
        'drfa': 'drfa',
        'whs': 'whs',
        'safety': 'whs',
        'hr': 'human-resources',
        'human resources': 'human-resources',
    };

    // Try keyword matching
    for (const [keyword, token] of Object.entries(mapping)) {
        if (normalized.includes(keyword)) {
            return token;
        }
    }

    return '';
}
```

**Notes:**
- Adjust event listener based on your LDAP autocomplete implementation
- Provides visual feedback when auto-population occurs
- User can still manually override the selection

#### 3.5 Add CSS for Auto-Population Visual Feedback

**File:** `csc/src/csc/whs/browser/static/incident_form.css`

```css
/* Visual feedback for auto-populated fields */
.auto-populated {
    background-color: #d4edda !important;
    border-color: #28a745 !important;
    transition: background-color 2s ease, border-color 2s ease;
}
```

#### 3.6 Testing Checklist

- [ ] LDAP autocomplete returns department in response
- [ ] Department field auto-populates when LDAP user selected
- [ ] Correct vocabulary token is selected in dropdown
- [ ] Visual feedback shows when auto-population occurs
- [ ] User can manually override auto-selected department
- [ ] Test with multiple departments (ICT, Water, Fleet, etc.)
- [ ] Handle case where department cannot be mapped (manual selection)

---

### ✅ Phase 4: Update Form Templates (1 hour)

**Goal:** Replace division text input with department dropdown in all forms.

#### 4.1 Update Authenticated Incident Form

**File:** `csc/src/csc/whs/browser/templates/report_incident.pt`

**Location:** Section 1B - Person Injured Details

**Find and replace:**
```html
<!-- OLD: Division text input -->
<div class="field">
    <label for="form-widgets-division">
        Division of the person injured <span class="required">*</span>
    </label>
    <input type="text" id="form-widgets-division" name="division" required />
</div>
```

**Replace with:**
```html
<!-- Q7: Department dropdown with auto-population -->
<div class="field">
    <label for="form-widgets-department">
        <strong>Q7:</strong> Department of the person injured <span class="required">*</span>
    </label>
    <select id="form-widgets-department"
            name="department"
            required
            tal:define="vocab_name string:csc.whs.DepartmentVocabulary;
                        vocab python:context.portal_vocabs[vocab_name]">
        <option value="">-- Select Department --</option>
        <option tal:repeat="term python:vocab.getVocabulary()"
                tal:attributes="value term/token"
                tal:content="term/title">Department Name</option>
    </select>
    <p class="field-description">
        This will auto-populate from Active Directory when you select the injured person's name above.
        You can change it if needed.
    </p>
</div>
```

**Notes:**
- Added question number Q7 (verify correct number)
- Changed from text input to select dropdown
- Populated from vocabulary
- Added helper text about auto-population

#### 4.2 Update Authenticated Hazard Form

**File:** `csc/src/csc/whs/browser/templates/report_hazard.pt`

**Location:** Section 2 - Hazard Details

**Find and replace:**
```html
<!-- OLD: Division text input -->
<div class="field">
    <label for="form-widgets-division">
        Division primarily associated with hazard <span class="required">*</span>
    </label>
    <input type="text" id="form-widgets-division" name="division" required />
</div>
```

**Replace with:**
```html
<!-- Department dropdown (manual selection for hazards) -->
<div class="field">
    <label for="form-widgets-department">
        Department primarily associated with hazard <span class="required">*</span>
    </label>
    <select id="form-widgets-department"
            name="department"
            required
            tal:define="vocab_name string:csc.whs.DepartmentVocabulary;
                        vocab python:context.portal_vocabs[vocab_name]">
        <option value="">-- Select Department --</option>
        <option tal:repeat="term python:vocab.getVocabulary()"
                tal:attributes="value term/token"
                tal:content="term/title">Department Name</option>
    </select>
    <p class="field-description">
        Select the department best positioned to manage this hazard.
    </p>
</div>
```

**Notes:**
- Changed from text input to select dropdown
- No auto-population for hazards (manual selection only)
- Added helper text

#### 4.3 Update Anonymous Form (Incidents and Hazards)

**File:** `csc/src/csc/whs/browser/templates/anonymous_form.pt`

**Update both incident and hazard sections:**

**Incident Section 1B:**
```html
<!-- Q7: Department dropdown (manual for anonymous) -->
<div class="field">
    <label for="form-widgets-department">
        <strong>Q7:</strong> Department of the person injured <span class="required">*</span>
    </label>
    <select id="form-widgets-department"
            name="department"
            required
            tal:define="vocab_name string:csc.whs.DepartmentVocabulary;
                        vocab python:context.portal_vocabs[vocab_name]">
        <option value="">-- Select Department --</option>
        <option tal:repeat="term python:vocab.getVocabulary()"
                tal:attributes="value term/token"
                tal:content="term/title">Department Name</option>
    </select>
</div>
```

**Hazard Section 2:**
```html
<!-- Department dropdown -->
<div class="field">
    <label for="form-widgets-department-hazard">
        Department primarily associated with hazard <span class="required">*</span>
    </label>
    <select id="form-widgets-department-hazard"
            name="department"
            required
            tal:define="vocab_name string:csc.whs.DepartmentVocabulary;
                        vocab python:context.portal_vocabs[vocab_name]">
        <option value="">-- Select Department --</option>
        <option tal:repeat="term python:vocab.getVocabulary()"
                tal:attributes="value term/token"
                tal:content="term/title">Department Name</option>
    </select>
</div>
```

**Notes:**
- Anonymous forms have no LDAP auto-population (manual selection only)
- Same vocabulary used for consistency

#### 4.4 Testing Checklist

- [ ] Authenticated incident form shows department dropdown
- [ ] Authenticated hazard form shows department dropdown
- [ ] Anonymous form shows department dropdown (both sections)
- [ ] All dropdowns populated with 26 departments
- [ ] Required validation works (cannot submit without selection)
- [ ] Helper text displays correctly

---

### ✅ Phase 5: Update Intake Processing (0.5 hours)

**Goal:** Update backend form processing to handle new department field.

#### 5.1 Update Authenticated Incident Intake

**File:** `csc/src/csc/whs/browser/intake.py`

**Find field extraction:**
```python
# OLD
division = form.get('division', '')
```

**Replace with:**
```python
# NEW: Extract department from dropdown
department = form.get('department', '')

# Validate department is from vocabulary
if department and department not in get_department_tokens():
    return error_response("Invalid department selected")
```

**Add validation helper:**
```python
def get_department_tokens():
    """Get list of valid department tokens from vocabulary"""
    vocab_factory = getUtility(IVocabularyFactory, 'csc.whs.DepartmentVocabulary')
    vocab = vocab_factory(None)
    return [term.token for term in vocab]
```

**Store in incident:**
```python
incident.department = department
```

#### 5.2 Update Hazard Intake

**File:** `csc/src/csc/whs/browser/hazard_intake.py`

**Same changes as above:**
```python
# Extract and validate department
department = form.get('department', '')

if department and department not in get_department_tokens():
    return error_response("Invalid department selected")

hazard.department = department
```

#### 5.3 Update Anonymous Form Processing

**File:** `csc/src/csc/whs/browser/anonymous.py`

**Find and update both incident and hazard processing:**
```python
# OLD
division = form.get('division', '')

# NEW
department = form.get('department', '')

# Validation
if department and department not in get_department_tokens():
    return error_response("Invalid department selected")

# Store
incident.department = department  # or hazard.department
```

#### 5.4 Testing Checklist

- [ ] Authenticated incident submission stores department correctly
- [ ] Authenticated hazard submission stores department correctly
- [ ] Anonymous incident submission stores department correctly
- [ ] Anonymous hazard submission stores department correctly
- [ ] Invalid department tokens rejected with error
- [ ] Empty department rejected (required field)

---

### ✅ Phase 6: Update View Templates (0.5 hours)

**Goal:** Display new department field in incident/hazard view pages.

#### 6.1 Update Incident View Template

**File:** `csc/src/csc/whs/browser/templates/incident.pt`

**Find Section 1B display:**
```html
<!-- OLD: Division display -->
<div class="field">
    <strong>Division:</strong>
    <span tal:content="incident/division">Infrastructure</span>
</div>
```

**Replace with:**
```html
<!-- Q7: Department display -->
<div class="field" tal:condition="incident/department">
    <strong>Q7: Department of person injured:</strong>
    <span tal:content="python: view.get_department_display_name(incident.department)">
        Water & Wastewater
    </span>
</div>
```

**Add helper method to view class:**

**File:** `csc/src/csc/whs/browser/incident_view.py` (or wherever incident view is defined)

```python
from zope.component import getUtility
from zope.schema.interfaces import IVocabularyFactory

class IncidentView(BrowserView):
    # ... existing methods ...

    def get_department_display_name(self, token):
        """Get display name for department token"""
        if not token:
            return ''

        vocab_factory = getUtility(IVocabularyFactory, 'csc.whs.DepartmentVocabulary')
        vocab = vocab_factory(self.context)

        try:
            term = vocab.getTerm(token)
            return term.title
        except LookupError:
            return token  # Fallback to token if not found
```

#### 6.2 Update Hazard View Template

**File:** `csc/src/csc/whs/browser/templates/hazard.pt`

**Find Section 2 display:**
```html
<!-- OLD: Division display -->
<div class="field">
    <strong>Division:</strong>
    <span tal:content="hazard/division">Infrastructure</span>
</div>
```

**Replace with:**
```html
<!-- Department display -->
<div class="field" tal:condition="hazard/department">
    <strong>Department primarily associated with hazard:</strong>
    <span tal:content="python: view.get_department_display_name(hazard.department)">
        Fleet & Workshop
    </span>
</div>
```

**Add same helper method to hazard view class.**

#### 6.3 Update Listing Templates (if applicable)

**Files to check:**
- `csc/src/csc/whs/browser/templates/incident_listing.pt`
- `csc/src/csc/whs/browser/templates/hazard_listing.pt`

**If division column exists in table:**
```html
<!-- OLD -->
<td tal:content="item/division">Infrastructure</td>

<!-- NEW -->
<td tal:content="python: view.get_department_display_name(item.department)">
    Water & Wastewater
</td>
```

#### 6.4 Testing Checklist

- [ ] Incident view displays department name (not token)
- [ ] Hazard view displays department name (not token)
- [ ] Listing views display department if column exists
- [ ] Old incidents with division field still display (backwards compatibility)
- [ ] Empty/missing department handled gracefully

---

### ✅ Phase 7: Update Email Notifications (0.5 hours)

**Goal:** Change email templates to show "Department" instead of "Division".

#### 7.1 Update Notification Templates

**File:** `csc/src/csc/whs/notifications.py`

**Find division references in email body:**

```python
# OLD
if incident.division:
    body += f"Division: {incident.division}\n"
```

**Replace with:**
```python
# NEW
if incident.department:
    # Get department display name from vocabulary
    dept_name = get_department_display_name(incident.department)
    body += f"Department: {dept_name}\n"
```

**Add helper function if not already present:**
```python
from zope.component import getUtility
from zope.schema.interfaces import IVocabularyFactory

def get_department_display_name(token):
    """Get display name for department token"""
    if not token:
        return ''

    try:
        vocab_factory = getUtility(IVocabularyFactory, 'csc.whs.DepartmentVocabulary')
        vocab = vocab_factory(None)
        term = vocab.getTerm(token)
        return term.title
    except (LookupError, ComponentLookupError):
        return token  # Fallback to token
```

**Update for both incident and hazard notifications:**
- Change label from "Division:" to "Department:"
- Convert token to display name before including in email

#### 7.2 Update Email Subject Lines (if applicable)

**If subject line includes division:**
```python
# OLD
subject = f"New Incident - {incident.division}"

# NEW
dept_name = get_department_display_name(incident.department)
subject = f"New Incident - {dept_name}"
```

#### 7.3 Testing Checklist

- [ ] Incident notification email shows "Department" not "Division"
- [ ] Department displayed as full name (e.g., "Water & Wastewater") not token
- [ ] Hazard notification email shows department correctly
- [ ] Email subject includes department name (if applicable)
- [ ] Test with various departments

---

### ✅ Phase 8: Data Migration / Upgrade Step (1.5 hours)

**Goal:** Create upgrade step to migrate existing incidents/hazards from division (text) to department (choice).

#### 8.1 Create Upgrade Step File

**File:** `csc/src/csc/whs/upgrades/v18.py` (create new file)

```python
# -*- coding: utf-8 -*-
"""Upgrade step: Profile 17 → 18 - Division to Department migration"""

from plone import api
from csc.whs.utilities import map_department_name_to_token
import logging

logger = logging.getLogger('csc.whs.upgrades.v18')


def upgrade_division_to_department(setup_tool):
    """Migrate division field (TextLine) to department field (Choice)

    This upgrade:
    1. Reads old 'division' field value (free text)
    2. Maps division text to department vocabulary token
    3. Stores mapped token in new 'department' field
    4. Keeps old 'division' field for reference (hidden via directives)
    5. Reindexes all affected content

    For Incidents and Hazards.
    """
    catalog = api.portal.get_tool('portal_catalog')

    # Migrate incidents
    logger.info("Starting migration of incidents from division to department...")
    incidents = catalog(portal_type='csc.whs.incident')
    incidents_migrated = 0
    incidents_failed = 0

    for brain in incidents:
        try:
            incident = brain.getObject()
            old_division = getattr(incident, 'division', '')

            if old_division:
                # Map old division text to new department token
                department_token = map_department_name_to_token(old_division)

                if department_token:
                    incident.department = department_token
                    logger.debug(f"Incident {incident.getId()}: '{old_division}' → '{department_token}'")
                    incidents_migrated += 1
                else:
                    logger.warning(f"Incident {incident.getId()}: Could not map division '{old_division}'")
                    incidents_failed += 1
            else:
                # No division value, set empty department
                incident.department = ''

            # Reindex
            incident.reindexObject()

        except Exception as e:
            logger.error(f"Error migrating incident {brain.getPath()}: {e}")
            incidents_failed += 1

    logger.info(f"Incidents migration complete: {incidents_migrated} migrated, {incidents_failed} failed/skipped")

    # Migrate hazards
    logger.info("Starting migration of hazards from division to department...")
    hazards = catalog(portal_type='csc.whs.hazard')
    hazards_migrated = 0
    hazards_failed = 0

    for brain in hazards:
        try:
            hazard = brain.getObject()
            old_division = getattr(hazard, 'division', '')

            if old_division:
                # Map old division text to new department token
                department_token = map_department_name_to_token(old_division)

                if department_token:
                    hazard.department = department_token
                    logger.debug(f"Hazard {hazard.getId()}: '{old_division}' → '{department_token}'")
                    hazards_migrated += 1
                else:
                    logger.warning(f"Hazard {hazard.getId()}: Could not map division '{old_division}'")
                    hazards_failed += 1
            else:
                # No division value, set empty department
                hazard.department = ''

            # Reindex
            hazard.reindexObject()

        except Exception as e:
            logger.error(f"Error migrating hazard {brain.getPath()}: {e}")
            hazards_failed += 1

    logger.info(f"Hazards migration complete: {hazards_migrated} migrated, {hazards_failed} failed/skipped")

    # Summary
    logger.info(f"=== MIGRATION SUMMARY ===")
    logger.info(f"Incidents: {incidents_migrated} migrated, {incidents_failed} failed")
    logger.info(f"Hazards: {hazards_migrated} migrated, {hazards_failed} failed")
    logger.info(f"Total: {incidents_migrated + hazards_migrated} successful migrations")

    # Log any unmapped divisions for manual review
    if incidents_failed > 0 or hazards_failed > 0:
        logger.warning(f"⚠️  {incidents_failed + hazards_failed} items could not be automatically mapped.")
        logger.warning(f"Review logs for specific items and update manually if needed.")
```

**Notes:**
- Uses `map_department_name_to_token()` from utilities.py
- Preserves old division field (hidden via directives.omitted)
- Logs all mappings for audit trail
- Handles missing/empty division values
- Reindexes all content

#### 8.2 Register Upgrade Step

**File:** `csc/src/csc/whs/profiles/default/upgrades.zcml`

**Add upgrade step registration:**

```xml
<genericsetup:upgradeStep
    source="17"
    destination="18"
    title="Migrate Division to Department field"
    description="Convert division text field to department choice field with vocabulary. Maps existing division values to new department tokens."
    handler="csc.whs.upgrades.v18.upgrade_division_to_department"
    profile="csc.whs:default"
    />
```

#### 8.3 Update Profile Version

**File:** `csc/src/csc/whs/profiles/default/metadata.xml`

**Change version:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <version>18</version>
  <dependencies>
    <dependency>profile-plone.app.dexterity:default</dependency>
    <dependency>profile-pas.plugins.ldap:default</dependency>
  </dependencies>
</metadata>
```

**Change from:** `<version>17</version>`
**Change to:** `<version>18</version>`

#### 8.4 Testing Checklist

- [ ] Upgrade step appears in Site Setup → Add-ons → Upgrade available
- [ ] Upgrade runs without errors
- [ ] Existing incidents show department field with mapped value
- [ ] Existing hazards show department field with mapped value
- [ ] Old division field hidden from edit forms but data preserved
- [ ] Check logs for any failed mappings
- [ ] Verify reindexing completed successfully
- [ ] Test display of migrated incidents/hazards

---

### ✅ Phase 9: Testing (1 hour)

**Goal:** Comprehensive testing of all changes before deployment.

#### 9.1 Unit Tests (if applicable)

**Create test file:** `csc/src/csc/whs/tests/test_department.py`

```python
# -*- coding: utf-8 -*-
"""Tests for department field and migration"""

import unittest
from csc.whs.utilities import map_department_name_to_token


class TestDepartmentMapping(unittest.TestCase):
    """Test department name to token mapping"""

    def test_exact_match(self):
        """Test exact keyword matches"""
        self.assertEqual(map_department_name_to_token('Water & Wastewater'), 'water-wastewater')
        self.assertEqual(map_department_name_to_token('ICT'), 'ict')
        self.assertEqual(map_department_name_to_token('Fleet & Workshop'), 'fleet-workshop')

    def test_partial_match(self):
        """Test partial keyword matches"""
        self.assertEqual(map_department_name_to_token('Water Operations'), 'water-wastewater')
        self.assertEqual(map_department_name_to_token('Human Resources Team'), 'human-resources')

    def test_case_insensitive(self):
        """Test case insensitivity"""
        self.assertEqual(map_department_name_to_token('WATER'), 'water-wastewater')
        self.assertEqual(map_department_name_to_token('water'), 'water-wastewater')

    def test_no_match(self):
        """Test unmapped departments return empty string"""
        self.assertEqual(map_department_name_to_token('Unknown Department'), '')
        self.assertEqual(map_department_name_to_token(''), '')
```

#### 9.2 Integration Tests

**Test checklist:**

**Vocabulary:**
- [ ] Department vocabulary loads successfully
- [ ] Returns 26 departments
- [ ] All tokens are valid identifiers

**Schema:**
- [ ] Incident schema validates with department field
- [ ] Hazard schema validates with department field
- [ ] Old division field hidden from forms
- [ ] Department field required validation works

**LDAP Auto-Population (Incidents):**
- [ ] Select LDAP user with known department (e.g., Water staff)
- [ ] Department dropdown auto-selects correct value
- [ ] Visual feedback shows auto-population occurred
- [ ] Can manually override auto-selected department

**Form Submission (Authenticated):**
- [ ] Submit incident with department selected → success
- [ ] Submit incident without department → error (required)
- [ ] Submit hazard with department selected → success
- [ ] Verify department stored correctly in database

**Form Submission (Anonymous):**
- [ ] Submit anonymous incident with department → success
- [ ] Submit anonymous hazard with department → success

**View Display:**
- [ ] Incident view shows department name (not token)
- [ ] Hazard view shows department name (not token)
- [ ] Old incidents with division field display correctly

**Email Notifications:**
- [ ] Submit test incident → verify email shows "Department: ..."
- [ ] Department displays as full name, not token

**Data Migration:**
- [ ] Run upgrade step 17→18
- [ ] Check existing incidents migrated successfully
- [ ] Check existing hazards migrated successfully
- [ ] Review logs for any failed mappings
- [ ] Verify old division data preserved

#### 9.3 User Acceptance Testing

**Test with WHS Officer:**
1. [ ] Create new incident with LDAP user selection
2. [ ] Verify department auto-fills correctly
3. [ ] Create new hazard with manual department selection
4. [ ] Create anonymous incident and hazard
5. [ ] View submitted incidents/hazards - verify department displays
6. [ ] Check email notifications - verify department appears correctly
7. [ ] Review migrated old incidents - verify department mapping looks correct

#### 9.4 Browser Compatibility Testing

Test in:
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (if Mac users)
- [ ] Edge (if Windows users)

**Focus on:**
- Dropdown rendering
- JavaScript auto-population
- Visual feedback animation

---

### ✅ Phase 10: Documentation & Deployment (0.5 hours)

**Goal:** Update documentation and deploy to production server.

#### 10.1 Update Package Version

**File:** `pyproject.toml`

**Change version:**
```toml
[project]
name = "csc.whs"
version = "0.10.18"  # Changed from 0.10.17
```

#### 10.2 Update README

**File:** `csc/README.md`

**Add to version history:**

```markdown
### Version 0.10.18 (October 2025) - Division → Department Field

**Schema Changes:**
- Replaced `division` text field with `department` choice field (26 departments)
- Applied to both Incidents and Hazards

**Features:**
- **Incidents:** Department auto-populates from LDAP when injured person selected
- **Hazards:** Department manually selected from dropdown
- **Migration:** Automatic upgrade step maps old division values to new departments
- **Vocabulary:** New DepartmentVocabulary with all Cook Shire Council departments

**Files Modified:** 18 files
**Upgrade Step:** Profile 17 → 18 (run via Site Setup → Add-ons)
```

#### 10.3 Update PROJECT_STATUS.md

**File:** `/home/ceo/Development/WHSPortal/PROJECT_STATUS.md`

**Add new version entry:**

```markdown
### Version 0.10.18 - Division → Department Field (October 18, 2025)

**Status:** ✅ Complete
**Priority:** High
**WHS Officer Request:** #1 - Replace Division with Department

**Implementation:**
- Replaced free-text division field with controlled department vocabulary
- Created DepartmentVocabulary with 26 Cook Shire Council departments
- Implemented LDAP auto-population for incident forms
- Manual selection for hazard forms and anonymous submissions
- Data migration from old division values to new department tokens

**Technical Details:**
- Profile upgrade: 17 → 18
- Files modified: 18
- New vocabulary: csc.whs.DepartmentVocabulary (26 terms)
- JavaScript auto-population with visual feedback
- Backwards compatible: old division field hidden but preserved

**Time Tracking:**
- Estimated: 8-10 hours (traditional), 6-7 hours (AI-assisted)
- Actual: [TO BE FILLED DURING IMPLEMENTATION]
- Productivity Gain: [TO BE CALCULATED]

**Testing:**
- Unit tests: Department name to token mapping
- Integration tests: LDAP auto-population, form submission, data migration
- UAT: WHS Officer verified functionality
```

#### 10.4 Deployment Steps

**Execute deployment:**

```bash
cd /home/ceo/Development/WHSPortal
./deploy-systemd.sh csc
```

**Deployment script will:**
1. Clean previous build artifacts
2. Build wheel from pyproject.toml (v0.10.18)
3. Copy wheel to whsportaldev via SSH
4. Install with `pip install --force-reinstall --no-deps`
5. Restart Plone via `sudo systemctl restart plone`
6. Clear nginx cache
7. Show service status

#### 10.5 Post-Deployment Steps

**On the server (via browser):**

1. Log in as admin to https://whsportal.cook.qld.gov.au
2. Go to: Site Setup → Add-ons
3. Find "csc.whs" addon
4. Click "Upgrade" button (will show 17 → 18 available)
5. Run upgrade step
6. Verify success message
7. Check upgrade log for any warnings

**Verification:**
```bash
# SSH to server
ssh whsportaldev

# Check Plone logs for errors
sudo journalctl -u plone -n 100

# Check for upgrade step completion
sudo journalctl -u plone | grep "MIGRATION SUMMARY"
```

#### 10.6 Post-Deployment Testing

- [ ] Create new incident with LDAP user → verify department auto-fills
- [ ] Create new hazard → verify department dropdown works
- [ ] Submit anonymous incident/hazard → verify department selection works
- [ ] View existing incidents → verify department displays correctly (migrated data)
- [ ] Check email notification → verify department appears
- [ ] Test with WHS Officer for acceptance

#### 10.7 Git Commit

**Commit all changes:**

```bash
cd /home/ceo/Development/WHSPortal/csc
git add -A
git commit -m "$(cat <<'EOF'
Implement Division → Department field (v0.10.18)

Replace free-text division field with controlled department vocabulary
for improved organizational tracking and LDAP integration.

Changes:
- Created DepartmentVocabulary with 26 Cook Shire Council departments
- Updated IIncident and IHazard schemas (TextLine → Choice)
- Implemented LDAP auto-population for incidents (JavaScript)
- Updated all form templates (authenticated and anonymous)
- Updated intake processing and validation
- Updated view templates and email notifications
- Created upgrade step (Profile 17 → 18) with data migration
- Backwards compatible: old division field hidden but preserved

Files modified: 18
Profile upgrade: 17 → 18
Testing: Unit, integration, and UAT complete

WHS Officer Request #1 - Complete

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Push to GitHub:**
```bash
gh repo sync
# OR
git push
```

#### 10.8 Documentation Checklist

- [ ] pyproject.toml version updated to 0.10.18
- [ ] csc/README.md updated with v0.10.18 entry
- [ ] PROJECT_STATUS.md updated with implementation details
- [ ] Time tracking recorded (estimated vs actual)
- [ ] Git commit created with comprehensive message
- [ ] Changes pushed to GitHub

---

## Progress Tracking

### Overall Status: ✅ COMPLETE

- [x] Phase 1: Create Department Vocabulary (1 hour) ✅ **COMPLETE**
- [x] Phase 2: Update Schema Definitions (1 hour) ✅ **COMPLETE**
- [x] Phase 3: LDAP Auto-Population for Incidents (1.5 hours) ✅ **COMPLETE**
- [x] Phase 4: Update Form Templates (1 hour) ✅ **COMPLETE**
- [x] Phase 5: Update Intake Processing (0.5 hours) ✅ **COMPLETE**
- [x] Phase 6: Update View Templates (0.5 hours) ✅ **COMPLETE**
- [x] Phase 7: Update Email Notifications (0.5 hours) ✅ **COMPLETE**
- [x] Phase 8: Data Migration / Upgrade Step (1.5 hours) ✅ **COMPLETE**
- [x] Phase 9: Testing (1 hour) ✅ **COMPLETE**
- [x] Phase 10: Documentation & Deployment (0.5 hours) ✅ **COMPLETE**

**Total Progress:** 10 / 10 phases complete (100%)
**Completion Date:** October 19, 2025
**Version Deployed:** csc.whs v0.10.18.7 (Profile 18)
**All testing verified by user**

---

## Files to Modify (18 files)

### Core Schema & Logic (10 files)
- [ ] `csc/src/csc/whs/interfaces.py` - Schema changes (IIncident, IHazard)
- [ ] `csc/src/csc/whs/vocabularies.py` - Department vocabulary
- [ ] `csc/src/csc/whs/configure.zcml` - Register vocabulary
- [ ] `csc/src/csc/whs/utilities.py` - Department name to token mapping (CREATE NEW)
- [ ] `csc/src/csc/whs/browser/intake.py` - Incident intake processing
- [ ] `csc/src/csc/whs/browser/hazard_intake.py` - Hazard intake processing
- [ ] `csc/src/csc/whs/browser/anonymous.py` - Anonymous form processing
- [ ] `csc/src/csc/whs/notifications.py` - Email notification templates
- [ ] `csc/src/csc/whs/upgrades/v18.py` - Upgrade step (CREATE NEW)
- [ ] `csc/src/csc/whs/profiles/default/upgrades.zcml` - Register upgrade

### Templates (5 files)
- [ ] `csc/src/csc/whs/browser/templates/report_incident.pt` - Incident form
- [ ] `csc/src/csc/whs/browser/templates/report_hazard.pt` - Hazard form
- [ ] `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Anonymous form
- [ ] `csc/src/csc/whs/browser/templates/incident.pt` - Incident view
- [ ] `csc/src/csc/whs/browser/templates/hazard.pt` - Hazard view

### JavaScript & CSS (2 files)
- [ ] `csc/src/csc/whs/browser/static/incident_form.js` - Auto-population logic
- [ ] `csc/src/csc/whs/browser/static/incident_form.css` - Visual feedback styling

### Configuration (1 file)
- [ ] `csc/src/csc/whs/profiles/default/metadata.xml` - Profile version 17→18

---

## Time Tracking

**Estimated Time:** 6-7 hours (AI-assisted)

**Actual Time:** _[To be filled during implementation]_

**Breakdown:**
- Phase 1: ___ hours (estimated 1h)
- Phase 2: ___ hours (estimated 1h)
- Phase 3: ___ hours (estimated 1.5h)
- Phase 4: ___ hours (estimated 1h)
- Phase 5: ___ hours (estimated 0.5h)
- Phase 6: ___ hours (estimated 0.5h)
- Phase 7: ___ hours (estimated 0.5h)
- Phase 8: ___ hours (estimated 1.5h)
- Phase 9: ___ hours (estimated 1h)
- Phase 10: ___ hours (estimated 0.5h)

**Total Actual:** ___ hours

**Productivity Gain:** ___% time savings vs traditional development (8-10 hours)

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| AD department names don't match vocabulary | Medium | Fuzzy keyword matching, manual override option |
| Data migration fails for some items | Medium | Preserve old division field, manual cleanup |
| JavaScript auto-population doesn't work | Low | Manual selection always available as fallback |
| Question numbering incorrect | Low | Comprehensive testing before deployment |

---

## Rollback Plan

**If deployment fails:**

1. **Restore previous version:**
   ```bash
   cd /home/ceo/Development/WHSPortal/csc
   git revert HEAD
   ./deploy-systemd.sh csc
   ```

2. **Revert upgrade step:** Cannot easily revert upgrade step once run. Old division field is preserved, so data is not lost.

3. **Contact WHS Officer:** Inform of rollback and timeline for fix.

---

## Success Criteria

✅ Department vocabulary displays correctly in all forms
✅ LDAP auto-population works for incident forms
✅ Manual selection works for hazard forms and anonymous submissions
✅ All existing incidents/hazards migrated successfully
✅ Email notifications show department correctly
✅ WHS Officer approves functionality
✅ No errors in Plone logs after deployment

---

**Document Created:** October 18, 2025
**Status:** Ready to implement
**Next Action:** Begin Phase 1 - Create Department Vocabulary
