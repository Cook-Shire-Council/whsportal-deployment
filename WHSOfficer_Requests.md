# WHS Officer Change Requests

**Date Created:** October 18, 2025
**Status:** Planning Phase
**Version:** csc.whs v0.10.17 (deployed)

This document tracks change requests from the WHS Officer for the incident and hazard reporting forms in the csc.whs addon.

---

## Request #1: Replace "Division" with "Department"

**Date Requested:** October 18, 2025
**Status:** ⏳ Planning
**Priority:** High
**Applies To:** Incidents and Hazards (both authenticated and anonymous forms)

### Background

The organizational structure has three levels:
1. **Directorate** (Level 1): e.g., "Growth and Liveability", "Infrastructure"
2. **Department** (Level 2): e.g., "Information & Communications Technology", "Water & Wastewater"
3. **Teams/Units** (Level 3): Individual work teams

Currently, the system uses "Division" to capture the Directorate level. The WHS Officer has requested this be changed to capture the **Department** level instead, as this provides more granular organizational tracking.

### Current Implementation

**Incidents:**
- Field: `division` (Text field, manual entry)
- Located in: Section 1B - Person Injured/Involved Details
- Anonymous Form: Manual text entry
- Authenticated Form: Manual text entry

**Hazards:**
- Field: `division` (Text field, manual entry)
- Located in: Section 2 - Hazard Details
- Anonymous Form: Manual text entry
- Authenticated Form: Manual text entry

### Requested Changes

**Incidents:**
- Rename field: `division` → `department`
- Field Type: **Choice field** (dropdown/select)
- Behavior: **Auto-populate from LDAP when injured person is selected**
- Source: Active Directory `department` attribute via LDAP integration
- Fallback: Allow manual selection if person not in AD or if anonymous report

**Hazards:**
- Rename field: `division` → `department`
- Field Type: **Choice field** (dropdown/select)
- Behavior: **Manual selection by reporter** (reporter determines which department should own the hazard)
- Source: Controlled vocabulary of all council departments

### Implementation Plan

#### Phase 1: Schema Changes (csc/src/csc/whs/interfaces.py)

**File:** `csc/src/csc/whs/interfaces.py`

1. **Create Department Vocabulary**
   - Add new vocabulary factory `department_vocabulary`
   - Source departments from organizational chart (Page 3)
   - Return ~20 departments across all 4 directorates
   - Vocabulary should include:
     - Office of the CEO departments (5)
     - Growth and Liveability departments (9)
     - Infrastructure departments (4)
     - People and Performance departments (2)

2. **Update IIncident Schema**
   - Rename field: `division` → `department`
   - Change type: `schema.TextLine()` → `schema.Choice()`
   - Add vocabulary: `vocabulary='csc.whs.department_vocabulary'`
   - Update field description to clarify it's the injured person's department
   - Keep field required: `required=True`
   - Update field order (keep in Section 1B)

3. **Update IHazard Schema**
   - Rename field: `division` → `department`
   - Change type: `schema.TextLine()` → `schema.Choice()`
   - Add vocabulary: `vocabulary='csc.whs.department_vocabulary'`
   - Update field description to clarify it's the department responsible for hazard
   - Keep field required: `required=True`
   - Update field order (keep in Section 2)

#### Phase 2: Vocabulary Implementation (csc/src/csc/whs/vocabularies.py)

**File:** `csc/src/csc/whs/vocabularies.py`

1. **Create Department Vocabulary**
   - Function: `department_vocabulary(context)`
   - Return SimpleVocabulary with all Cook Shire Council departments
   - Use organizational chart structure as reference
   - Format: token=slug, title=display name
   - Example:
     ```python
     SimpleTerm(value='ict', title='Information & Communications Technology')
     SimpleTerm(value='water-waste', title='Water & Wastewater')
     ```

2. **Register Vocabulary**
   - Add to `configure.zcml` as named vocabulary
   - Name: `csc.whs.department_vocabulary`

#### Phase 3: Incident Form Auto-Population (csc/src/csc/whs/browser/report_incident.pt + incident_form.js)

**Files:**
- `csc/src/csc/whs/browser/templates/report_incident.pt`
- `csc/src/csc/whs/browser/static/incident_form.js`

1. **Update Form Field**
   - Change from text input to select dropdown
   - Add `id="form-widgets-department"` for JavaScript targeting
   - Ensure field is in Section 1B after injured person name field

2. **Add JavaScript Auto-Population**
   - Listen for changes on injured person LDAP field
   - When user selected via LDAP autocomplete:
     - Extract department from LDAP response
     - Map department name to vocabulary token
     - Auto-select matching option in department dropdown
     - If no match found, leave dropdown at default
   - User can override auto-selected value if needed

3. **LDAP API Enhancement** (if needed)
   - Verify `@@ldap-search` endpoint returns `department` field
   - Currently returns: username, fullname, email, department (line 158 in ldap_utils.py)
   - Should already be available ✅

#### Phase 4: Anonymous Form Updates

**Files:**
- `csc/src/csc/whs/browser/templates/anonymous_form.pt`
- `csc/src/csc/whs/browser/anonymous.py`

1. **Update Anonymous Incident Section 1B**
   - Change division text input to department dropdown
   - Use same vocabulary as authenticated form
   - Manual selection only (no LDAP auto-population for anonymous)

2. **Update Anonymous Hazard Section 2**
   - Change division text input to department dropdown
   - Use same vocabulary as authenticated form
   - Manual selection by reporter

3. **Update Form Processing**
   - In `anonymous.py`, update field extraction
   - Change: `form.get('division', '')` → `form.get('department', '')`
   - Validate selection is from vocabulary

#### Phase 5: Intake Processing Updates

**Files:**
- `csc/src/csc/whs/browser/intake.py` (incidents)
- `csc/src/csc/whs/browser/hazard_intake.py` (hazards)

1. **Update Field Extraction**
   - Change field name from `division` to `department` in form processing
   - Validate department value against vocabulary
   - Ensure proper storage in content object

2. **Update Email Notifications**
   - In `csc/src/csc/whs/notifications.py`
   - Change "Division" label to "Department" in email templates
   - Update field reference: `incident.division` → `incident.department`

#### Phase 6: View Template Updates

**Files:**
- `csc/src/csc/whs/browser/templates/incident.pt`
- `csc/src/csc/whs/browser/templates/hazard.pt`
- `csc/src/csc/whs/browser/templates/incident_listing.pt`
- `csc/src/csc/whs/browser/templates/hazard_listing.pt`

1. **Update Incident View Template**
   - Change "Division" label to "Department" in Section 1B display
   - Update TAL expression: `incident/division` → `incident/department`

2. **Update Hazard View Template**
   - Change "Division" label to "Department" in Section 2 display
   - Update TAL expression: `hazard/division` → `hazard/department`

3. **Update Folder Listing Views** (if division shown)
   - Check if division/department displayed in listing tables
   - Update column headers and field references if present

#### Phase 7: Backwards Compatibility & Data Migration

**File:** `csc/src/csc/whs/upgrades/v18.py` (new file)

1. **Create Upgrade Step**
   - Version: 17 → 18
   - Purpose: Migrate `division` field data to `department`
   - Strategy: Keep old field, add new field, copy data

2. **Migration Logic**
   - For all existing Incidents:
     - Read `division` text value
     - Map to department vocabulary token (best match)
     - Store in new `department` field
     - Keep original `division` value for reference
   - For all existing Hazards:
     - Same logic as incidents

3. **Field Deprecation Strategy**
   - Option A: Hide old `division` field using `directives.omitted()`
   - Option B: Remove field entirely after migration (breaks old data display)
   - **Recommendation:** Use Option A for safety

4. **Register Upgrade Step**
   - Add to `profiles/default/upgrades.zcml`
   - Source: `17`, Destination: `18`
   - Handler: `csc.whs.upgrades.v18.upgrade_division_to_department`

5. **Update Profile Version**
   - In `profiles/default/metadata.xml`
   - Change version from `17` to `18`

#### Phase 8: Catalog Updates (if indexed)

**File:** `csc/src/csc/whs/profiles/default/catalog.xml`

1. **Check if division is indexed**
   - Review catalog.xml for `division` index
   - If present, add new `department` index
   - Keep both during transition period

2. **Update Catalog Configuration**
   - Add FieldIndex for `department` if used for searching
   - Add metadata column if needed for listings

#### Phase 9: Testing Plan

1. **Unit Tests**
   - Test vocabulary returns all departments
   - Test field validation
   - Test data migration from division to department

2. **Integration Tests**
   - Test LDAP auto-population on incident form
   - Test manual selection on hazard form
   - Test anonymous form submissions (both incident and hazard)
   - Test authenticated form submissions
   - Test upgrade step execution

3. **User Acceptance Testing**
   - Create test incident with LDAP user (verify department auto-fills)
   - Create test hazard with manual department selection
   - Create anonymous incident and hazard submissions
   - Verify email notifications show "Department" not "Division"
   - Verify view templates display department correctly

#### Phase 10: Deployment

1. **Version Update**
   - Update `pyproject.toml` version: `0.10.17` → `0.10.18`

2. **Documentation Updates**
   - Update README.md with department field changes
   - Update PROJECT_STATUS.md with v0.10.18 changes
   - Document department vocabulary source

3. **Deployment Steps**
   ```bash
   cd /home/ceo/Development/WHSPortal
   ./deploy-systemd.sh csc
   # Then in Plone: Site Setup → Add-ons → Upgrade csc.whs (17→18)
   ```

4. **Post-Deployment Verification**
   - Check upgrade step completed successfully
   - Verify existing incidents/hazards display department field
   - Test new incident submission with LDAP auto-population
   - Test new hazard submission with manual selection

### Files to Modify

#### Core Schema & Logic (9 files)
1. `csc/src/csc/whs/interfaces.py` - Schema changes (IIncident, IHazard)
2. `csc/src/csc/whs/vocabularies.py` - Department vocabulary
3. `csc/src/csc/whs/configure.zcml` - Register vocabulary
4. `csc/src/csc/whs/browser/intake.py` - Incident intake processing
5. `csc/src/csc/whs/browser/hazard_intake.py` - Hazard intake processing
6. `csc/src/csc/whs/browser/anonymous.py` - Anonymous form processing
7. `csc/src/csc/whs/notifications.py` - Email notification templates
8. `csc/src/csc/whs/upgrades/v18.py` - NEW: Upgrade step
9. `csc/src/csc/whs/profiles/default/upgrades.zcml` - Register upgrade

#### Templates (5 files)
10. `csc/src/csc/whs/browser/templates/report_incident.pt` - Incident form
11. `csc/src/csc/whs/browser/templates/report_hazard.pt` - Hazard form
12. `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Anonymous form
13. `csc/src/csc/whs/browser/templates/incident.pt` - Incident view
14. `csc/src/csc/whs/browser/templates/hazard.pt` - Hazard view

#### JavaScript (1 file)
15. `csc/src/csc/whs/browser/static/incident_form.js` - Auto-population logic

#### Configuration (2 files)
16. `csc/src/csc/whs/profiles/default/metadata.xml` - Profile version 17→18
17. `csc/src/csc/whs/profiles/default/catalog.xml` - Catalog updates (if needed)

#### Build Configuration (1 file)
18. `pyproject.toml` - Package version 0.10.17→0.10.18

**Total:** 18 files to modify

### Estimated Effort

- **Schema & Vocabulary:** 1-2 hours
- **Form Updates & JavaScript:** 2-3 hours
- **Upgrade Step & Migration:** 2 hours
- **Testing:** 2 hours
- **Documentation:** 1 hour

**Total: 8-10 hours**

### Risks & Mitigation

**Risk 1: Department names in AD don't match organizational chart**
- Mitigation: Create fuzzy matching logic in LDAP utils
- Fallback: Allow manual override

**Risk 2: Existing data migration issues**
- Mitigation: Thorough testing of upgrade step
- Backup: Keep old `division` field hidden but intact

**Risk 3: JavaScript auto-population doesn't work**
- Mitigation: Extensive browser testing (Chrome, Firefox, Safari)
- Fallback: Manual dropdown selection always available

### Department Vocabulary (Draft)

Based on organizational chart (Page 3), the vocabulary should include:

**Office of the CEO (5 departments)**
- Mayor and Councillor Support
- CEO Support
- Governance & Risk
- Records
- Grants and Administration

**Growth and Liveability (9 departments)**
- Economy, Tourism & Arts
- Community Lifestyle
- Financial Services
- Planning & Environment
- Biosecurity
- Local Laws & Animal Control
- Buildings & Facilities
- Communications & Engagement
- Information & Communications Technology
- Disaster Management

**Infrastructure (4 departments)**
- Parks & Gardens
- Water & Wastewater
- Waste Management
- Engineering
- Fleet & Workshop
- Roads & Civil Works
- Project Management
- Airports
- DRFA

**People and Performance (2 departments)**
- Workplace Health & Safety
- Human Resources

**Total: ~20 departments**

---

## Request #2: Incident Form Section 3 Enhancements

**Date Requested:** October 18, 2025
**Status:** ⏳ Planning
**Priority:** Medium
**Applies To:** Incidents only (authenticated and anonymous forms)

### Background

Section 3 of the incident form currently uses the Dublin Core metadata "title" and "description" fields. The WHS Officer has requested enhancements to improve data quality and reduce manual work:

1. **Auto-generate title** from key incident details
2. **Make "What happened" (description) mandatory**
3. **Make "Immediate Actions" mandatory**

### Current Implementation

**Section 3 Fields:**
- **Title** (Brief Title/Summary): Dublin Core `title` field, optional, manually entered
- **Description** (What happened): Dublin Core `description` field, optional, manually entered
- **Immediate Actions**: Custom field `immediate_actions`, optional (line 154-158 in interfaces.py)

### Requested Changes

#### Change 2A: Auto-Generate Title
**Current:** Manual text entry for "Brief Title / Summary"
**Requested:** Auto-generate from mandatory fields using pattern:
```
<Incident Type> - <Department> - <Location Town>
```

**Examples:**
- "Minor Injury - ICT - Cooktown"
- "Near Miss - Water & Wastewater - Lakeland"
- "Property Damage - Fleet & Workshop - Cooktown"

**Implementation Notes:**
- If multiple incident types selected, use first one or "Multiple Types"
- Extract town/suburb from location field (may need geocoding or manual entry)
- Allow user to override auto-generated title if needed
- Generate on form submission (both authenticated and anonymous)

#### Change 2B: Make "What happened" Mandatory
**Current:** Dublin Core `description` field is optional
**Requested:** Make this a required field

**Implementation Notes:**
- Update schema: `required=False` → `required=True`
- Add validation to form templates
- Update form instructions to indicate mandatory field
- Both authenticated and anonymous forms

#### Change 2C: Make "Immediate Actions" Mandatory
**Current:** `immediate_actions` field is optional (line 156: `required=False`)
**Requested:** Make this a required field

**Implementation Notes:**
- Update schema: `required=False` → `required=True`
- Add validation to form templates
- Update form instructions to indicate mandatory field
- Both authenticated and anonymous forms

### Implementation Plan

#### Phase 1: Schema Changes (csc/src/csc/whs/interfaces.py)

**File:** `csc/src/csc/whs/interfaces.py`

1. **Update immediate_actions field** (line 154-158)
   ```python
   immediate_actions = schema.Text(
       title=u"Immediate Actions Taken",
       required=True,  # Changed from False
       description=u"What actions were taken immediately after the incident? (Required)",
   )
   ```

2. **Consider adding location_town field** (optional, for title generation)
   ```python
   location_town = schema.TextLine(
       title=u"Town/Suburb",
       required=False,
       description=u"Town or suburb where incident occurred (used for incident title)",
   )
   ```
   **Alternative:** Extract town from existing `location` field using string parsing

#### Phase 2: Dublin Core Description Override

**Challenge:** Dexterity content types inherit Dublin Core `description` field, which is optional by default.

**Solution Options:**

**Option A: Use form field override (simplest)**
- In form templates, mark description field as required via form validation
- Use JavaScript to enforce required field
- Update form widgets configuration

**Option B: Override IDublinCore behavior (more complex)**
- Create custom behavior that overrides `description` field
- Register behavior in configure.zcml
- Apply to Incident content type only

**Recommendation:** Use Option A for simplicity and faster implementation

#### Phase 3: Title Auto-Generation Logic

**File:** `csc/src/csc/whs/utilities.py` (add new function)

```python
def generate_incident_title(incident_types, department, location):
    """Generate incident title from key fields

    Args:
        incident_types: List of incident type tokens (e.g., ['minor-injury', 'near-miss'])
        department: Department name/token (e.g., 'ict')
        location: Location text or town name

    Returns:
        str: Generated title (e.g., "Minor Injury - ICT - Cooktown")
    """
    # Get first incident type or "Multiple Types"
    # Map department token to display name
    # Extract town from location (or use location_town field)
    # Return formatted title
```

**Location Town Extraction:**
- Option 1: Add new `location_town` field (explicit, recommended)
- Option 2: Parse `location` text field for town name (regex/heuristics)
- Option 3: Use geocoding API with lat/long (complex, requires API)

#### Phase 4: Form Template Updates

**Files:**
- `csc/src/csc/whs/browser/templates/report_incident.pt`
- `csc/src/csc/whs/browser/templates/anonymous_form.pt`

**Changes:**

1. **Add location_town field** (if using new field approach)
   - Add input field in Section 1 (location section)
   - Place after main location field
   - Optional field, but helpful for title generation

2. **Mark description as required**
   - Add `required` attribute to textarea
   - Add asterisk (*) to field label
   - Add client-side validation

3. **Mark immediate_actions as required**
   - Add `required` attribute to textarea
   - Add asterisk (*) to field label
   - Add client-side validation

4. **Title field behavior**
   - Option A: Keep title field visible but auto-populate on blur/change
   - Option B: Hide title field and auto-generate on submission
   - **Recommendation:** Option A allows user override

#### Phase 5: Intake Processing Updates

**Files:**
- `csc/src/csc/whs/browser/intake.py` (authenticated incidents)
- `csc/src/csc/whs/browser/anonymous.py` (anonymous incidents)

**Changes:**

1. **Add title generation logic**
   ```python
   from csc.whs.utilities import generate_incident_title

   # After extracting form data
   if not title or title.strip() == '':
       title = generate_incident_title(
           incident_types=incident_types,
           department=department,
           location=location_town or location
       )
   ```

2. **Set content title**
   ```python
   incident.title = title
   incident.setTitle(title)  # For Dublin Core
   ```

3. **Validate required fields**
   - Ensure `description` is not empty
   - Ensure `immediate_actions` is not empty
   - Return error if validation fails

#### Phase 6: JavaScript Enhancements

**File:** `csc/src/csc/whs/browser/static/incident_form.js`

**Add auto-title generation:**
```javascript
function generateIncidentTitle() {
    // Get incident type (first selected)
    const incidentType = getFirstSelectedIncidentType();

    // Get department
    const department = document.getElementById('form-widgets-department').value;

    // Get location town
    const locationTown = document.getElementById('form-widgets-location_town')?.value
                      || extractTownFromLocation();

    // Generate title
    if (incidentType && department && locationTown) {
        const title = `${incidentType} - ${department} - ${locationTown}`;
        document.getElementById('form-widgets-IDublinCore-title').value = title;
    }
}

// Attach to field change events
document.addEventListener('DOMContentLoaded', function() {
    ['incident_types', 'department', 'location_town'].forEach(field => {
        document.getElementById(`form-widgets-${field}`)?.addEventListener('change', generateIncidentTitle);
    });
});
```

#### Phase 7: Vocabulary Mapping

**File:** `csc/src/csc/whs/vocabularies.py`

**Add helper function:**
```python
def get_display_name_from_vocabulary(vocabulary_name, token):
    """Get display name from vocabulary token

    Args:
        vocabulary_name: Name of vocabulary (e.g., 'csc.whs.IncidentTypeVocabulary')
        token: Token value (e.g., 'minor-injury')

    Returns:
        str: Display name (e.g., 'Minor Injury')
    """
    # Get vocabulary
    # Find term by token
    # Return term.title
```

Used by title generation to convert tokens to human-readable names.

#### Phase 8: Testing Plan

**Unit Tests:**
1. Test title generation with various input combinations
2. Test required field validation for description
3. Test required field validation for immediate_actions
4. Test location town extraction (if applicable)

**Integration Tests:**
1. Submit authenticated incident form without description (should fail)
2. Submit authenticated incident form without immediate actions (should fail)
3. Submit incident with all required fields (should succeed with auto-title)
4. Submit anonymous incident form with required fields (should succeed)
5. Verify user can override auto-generated title

**User Acceptance Testing:**
1. Create test incident and verify title auto-generates correctly
2. Verify description field is marked as required
3. Verify immediate actions field is marked as required
4. Verify form validation prevents submission without required fields
5. Verify user can manually edit auto-generated title

#### Phase 9: Deployment

1. **Version Update**
   - Can be included in v0.10.18 (with Request #1)
   - Or separate as v0.10.19 if deployed independently

2. **No Upgrade Step Required**
   - Schema changes affect new submissions only
   - Existing incidents unchanged
   - No data migration needed

3. **Documentation Updates**
   - Update README.md with new required fields
   - Document title generation pattern
   - Update user documentation/training materials

### Files to Modify

#### Core Schema & Logic (3 files)
1. `csc/src/csc/whs/interfaces.py` - Schema changes (make fields required, possibly add location_town)
2. `csc/src/csc/whs/utilities.py` - Add title generation function
3. `csc/src/csc/whs/vocabularies.py` - Add helper for vocabulary display names

#### Form Processing (2 files)
4. `csc/src/csc/whs/browser/intake.py` - Add title generation logic
5. `csc/src/csc/whs/browser/anonymous.py` - Add title generation logic

#### Templates (2 files)
6. `csc/src/csc/whs/browser/templates/report_incident.pt` - Mark fields required, add location_town
7. `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Mark fields required, add location_town

#### JavaScript (1 file)
8. `csc/src/csc/whs/browser/static/incident_form.js` - Auto-title generation logic

**Total:** 8 files to modify

### Estimated Effort

- **Schema Changes:** 0.5 hours
- **Title Generation Logic:** 1-2 hours
- **Form Template Updates:** 1 hour
- **JavaScript Implementation:** 1 hour
- **Testing:** 1 hour
- **Documentation:** 0.5 hours

**Total: 5-6 hours**

### Design Decisions

#### Decision 1: Location Town Field
**Options:**
- A) Add new `location_town` field (explicit)
- B) Parse existing `location` field (heuristic)
- C) Use geocoding with lat/long (complex)

**Recommendation:** Option A (add new field)
- **Pros:** Explicit, reliable, user-controlled
- **Cons:** One extra field to fill
- **Justification:** Most reliable for title generation

#### Decision 2: Multiple Incident Types
**Options:**
- A) Use first selected incident type
- B) Use "Multiple Types" if >1 selected
- C) Concatenate all types (may be long)

**Recommendation:** Option A (use first)
- **Pros:** Clean, predictable
- **Cons:** May not represent all types
- **Justification:** Titles should be concise; full details in description

#### Decision 3: Title Override
**Options:**
- A) Allow manual override (editable field)
- B) Auto-generate only, no override (readonly)

**Recommendation:** Option A (allow override)
- **Pros:** Flexibility for edge cases
- **Cons:** Users might not use auto-generation
- **Justification:** Best of both worlds - auto-generate but allow customization

### Impact on Existing Data

**No impact on existing incidents:**
- Existing incidents keep their current titles (may be empty)
- Existing incidents may have empty description/immediate_actions (grandfathered)
- New validation only applies to new submissions

**Optional Enhancement:**
- Could create utility script to back-fill titles for existing incidents
- Low priority, not required

### User Experience Improvements

**Before:**
- Title: Optional, often left blank
- Description: Optional, sometimes skipped
- Immediate Actions: Optional, frequently empty

**After:**
- Title: Auto-generated from key details, consistent format
- Description: Required, ensures incident details captured
- Immediate Actions: Required, ensures response is documented
- Overall: Better data quality, more complete incident records

---

## Request #3: Number Section 3 Questions

**Date Requested:** October 18, 2025
**Status:** ⏳ Planning
**Priority:** Low
**Applies To:** Incidents only (authenticated and anonymous forms)

### Background

Currently, Section 3 (Incident Details) fields don't have question numbers like the other sections. For consistency and better form navigation, these should be numbered.

### Current Implementation

**Section 3 Fields (unnumbered):**
- Brief Title / Summary (Dublin Core title)
- What happened (Dublin Core description)
- Immediate Actions Taken

### Requested Changes

Add question numbers to Section 3 fields to match the format of other sections:

**Proposed numbering:**
- **Q13:** Brief Title / Summary
- **Q14:** What happened
- **Q15:** Immediate Actions Taken

**Note:** This assumes Section 1 has Q1-Q7, Section 2 has Q8-Q12. Need to verify exact question count in earlier sections.

### Implementation Plan

#### Phase 1: Verify Question Numbering

**Files to review:**
- `csc/src/csc/whs/browser/templates/report_incident.pt`
- `csc/src/csc/whs/browser/templates/anonymous_form.pt`
- `csc/src/csc/whs/interfaces.py` (comments show question numbers)

**Tasks:**
1. Count questions in Section 1 (Incident Type and Person(s) Involved)
2. Count questions in Section 2 (Reporting Information)
3. Determine correct starting number for Section 3
4. Verify numbering continues correctly into Section 4+ (Injury Details, Property Damage, etc.)

#### Phase 2: Update Form Templates

**Files:**
- `csc/src/csc/whs/browser/templates/report_incident.pt`
- `csc/src/csc/whs/browser/templates/anonymous_form.pt`

**Changes:**

Add question number labels to Section 3 fields:

```html
<div class="field">
    <label for="form-widgets-IDublinCore-title">
        <strong>Q13:</strong> Brief Title / Summary
    </label>
    <input type="text" id="form-widgets-IDublinCore-title" ...>
</div>

<div class="field">
    <label for="form-widgets-IDublinCore-description">
        <strong>Q14:</strong> What happened <span class="required">*</span>
    </label>
    <textarea id="form-widgets-IDublinCore-description" ...></textarea>
</div>

<div class="field">
    <label for="form-widgets-immediate_actions">
        <strong>Q15:</strong> Immediate Actions Taken <span class="required">*</span>
    </label>
    <textarea id="form-widgets-immediate_actions" ...></textarea>
</div>
```

#### Phase 3: Update Schema Comments (Optional)

**File:** `csc/src/csc/whs/interfaces.py`

Update comments in Section 3 to include question numbers for developer reference:

```python
# ========================================
# SECTION 3: INCIDENT DETAILS
# ========================================
# Q13: Brief Title / Summary - provided by Dublin Core title field
# Q14: What happened - provided by Dublin Core description field
# Q15: Immediate Actions Taken

immediate_actions = schema.Text(
    title=u"Q15: Immediate Actions Taken",  # Add Q number to title
    required=True,
    description=u"What actions were taken immediately after the incident? (Required)",
)
```

#### Phase 4: CSS Styling (Optional)

**File:** `csc/src/csc/whs/browser/static/incident_form.css`

Optionally add styling for question numbers:

```css
label strong {
    color: #0066cc;
    font-weight: 600;
    margin-right: 0.25rem;
}
```

### Files to Modify

1. `csc/src/csc/whs/browser/templates/report_incident.pt` - Add question numbers to labels
2. `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Add question numbers to labels
3. `csc/src/csc/whs/interfaces.py` - Update comments (optional)
4. `csc/src/csc/whs/browser/static/incident_form.css` - Add styling (optional)

**Total:** 2-4 files to modify

### Estimated Effort

- **Verify question numbering:** 0.25 hours
- **Update templates:** 0.5 hours
- **Update schema comments:** 0.25 hours (optional)
- **Testing:** 0.25 hours

**Total: 1-1.25 hours**

### Testing Plan

1. **Visual Verification:**
   - Load authenticated incident form
   - Verify Section 3 fields show Q13, Q14, Q15
   - Verify numbering is consistent with previous sections
   - Check anonymous form as well

2. **Cross-Section Verification:**
   - Verify Section 1 ends with correct question number
   - Verify Section 2 ends with correct question number
   - Verify Section 4 (Injury Details) starts with correct number (likely Q16)

### Implementation Notes

**This change can be bundled with Request #2** since it affects the same Section 3 fields. No separate version bump needed if implemented together.

**Low priority:** This is a cosmetic/usability improvement. Can be implemented alongside Request #2 or as a quick standalone task.

---

## Request #4: Move Emergency Services Questions to Section 3

**Date Requested:** October 18, 2025
**Status:** ⏳ Planning
**Priority:** Medium
**Applies To:** Incidents only (authenticated and anonymous forms)

### Background

Currently, questions about emergency services (Q22 and Q23) are located in Section 4 (Injury Details), but they apply to all incidents regardless of whether there was an injury. These questions should be moved to Section 3 (Incident Details) and enhanced with better validation.

### Current Implementation

**Section 4 (Injury Details) - Current Q22 & Q23:**

From `interfaces.py` lines 222-234:

```python
# Q22: If emergency services were called to the scene, select "yes"
emergency_services_called = schema.Bool(
    title=u"Were emergency services called to the scene?",
    required=False,
    default=False,
    description=u"This does not include First Aid provided by First Aiders.",
)

# Q23: If medical treatment was sought / provided, who provided it / where were they taken?
medical_treatment_location = schema.Text(
    title=u"If medical treatment was sought / provided, who provided it / where were they taken?",
    required=False,
    description=u"This does not include First Aid provided by First Aiders.",
)
```

**Issues:**
1. Q22 is boolean (True/False) but not mandatory
2. Q23 is about medical treatment location, not emergency services details
3. Both are in Section 4 (injury-specific section), but emergency services apply to all incidents
4. No way to specify which emergency services responded (Police, Fire, Ambulance)

### Requested Changes

#### Change 4A: Move Q22 to Section 3 and Make Mandatory

**New location:** Section 3 (Incident Details), after Q15 (Immediate Actions)
**New question number:** Q16 (renumber existing Q16+ accordingly)
**Field name:** `emergency_services_called`
**Type:** Choice field (Yes/No dropdown) instead of Boolean checkbox
**Required:** True (mandatory field)

**New schema:**
```python
emergency_services_called = schema.Choice(
    title=u"Were emergency services called to the scene?",
    required=True,
    vocabulary="csc.whs.YesNoVocabulary",
    description=u"This does not include First Aid provided by First Aiders.",
)
```

#### Change 4B: Add New Q17 for Emergency Service Types

**New field:** `emergency_services_types` (multi-select)
**Location:** Section 3, immediately after Q16
**Conditional:** Only required if Q16 = "Yes"
**Options:** Police, Fire, Ambulance (minimum 1 required if Q16=Yes)

**New schema:**
```python
emergency_services_types = schema.List(
    title=u"Which emergency services attended?",
    required=False,  # Conditionally required via form validation
    description=u"Select all emergency services that were called to the scene",
    value_type=schema.Choice(
        vocabulary="csc.whs.EmergencyServicesVocabulary"
    ),
)
```

**New vocabulary:** `EmergencyServicesVocabulary`
- Police
- Fire
- Ambulance
- SES (State Emergency Service)
- Other

#### Change 4C: Keep Q23 in Section 4 (Medical Treatment)

**Current Q23** (`medical_treatment_location`) is actually about medical treatment, not emergency services, so it should remain in Section 4 (Injury Details) where it logically belongs.

**Action:** No change to Q23, just renumber from Q23 → Q24 after inserting new Q16-Q17

### Implementation Plan

#### Phase 1: Schema Changes (csc/src/csc/whs/interfaces.py)

**File:** `csc/src/csc/whs/interfaces.py`

**Step 1: Move emergency_services_called to Section 3**

Current location: Lines 222-227 (Section 4)
New location: After `immediate_actions` in Section 3 (after line 158)

```python
# ========================================
# SECTION 3: INCIDENT DETAILS
# ========================================

immediate_actions = schema.Text(
    title=u"Q15: Immediate Actions Taken",
    required=True,
    description=u"What actions were taken immediately after the incident? (Required)",
)

# Q16: Were emergency services called to the scene?
emergency_services_called = schema.Choice(
    title=u"Were emergency services called to the scene?",
    required=True,
    vocabulary="csc.whs.YesNoVocabulary",
    description=u"This does not include First Aid provided by First Aiders.",
)

# Q17: Which emergency services attended?
emergency_services_types = schema.List(
    title=u"Which emergency services attended?",
    required=False,  # Conditionally required based on Q16
    description=u"Select all emergency services that were called to the scene (required if emergency services were called)",
    value_type=schema.Choice(
        vocabulary="csc.whs.EmergencyServicesVocabulary"
    ),
)
```

**Step 2: Renumber subsequent questions**

All questions from current Q16 onwards need to be renumbered:
- Current Q16 (injury_body_areas) → Q18
- Current Q17 (injury_classifications) → Q19
- Current Q18 (first_aid_given) → Q20
- Current Q19 (first_aid_provider) → Q21
- Current Q20 (first_aid_description) → Q22
- Current Q21 (medical_treatment_sought) → Q23
- Current Q23 (medical_treatment_location) → Q24
- And so on...

**Step 3: Remove old boolean emergency_services_called**

Delete or comment out the old boolean field definition (lines 222-227).

#### Phase 2: Create New Vocabulary (csc/src/csc/whs/vocabularies.py)

**File:** `csc/src/csc/whs/vocabularies.py`

**Add new vocabulary:**

```python
@provider(IVocabularyFactory)
def emergency_services_vocabulary(context):
    """Emergency services types that can attend an incident

    Used for multi-select field when emergency services are called
    """
    terms = [
        SimpleTerm(value='police', title='Police (QPS)'),
        SimpleTerm(value='fire', title='Fire and Emergency Services (QFES)'),
        SimpleTerm(value='ambulance', title='Ambulance (QAS)'),
        SimpleTerm(value='ses', title='SES (State Emergency Service)'),
        SimpleTerm(value='other', title='Other emergency service'),
    ]
    return SimpleVocabulary(terms)
```

**Register in configure.zcml:**

```xml
<utility
    component=".vocabularies.emergency_services_vocabulary"
    name="csc.whs.EmergencyServicesVocabulary"
    />
```

#### Phase 3: Form Template Updates

**Files:**
- `csc/src/csc/whs/browser/templates/report_incident.pt`
- `csc/src/csc/whs/browser/templates/anonymous_form.pt`

**Changes in Section 3:**

1. **Add Q16 (emergency services called) after Q15**
   - Use dropdown/select widget for Yes/No choice
   - Mark as required with asterisk (*)
   - Add `id="form-widgets-emergency_services_called"` for JavaScript

2. **Add Q17 (emergency services types) after Q16**
   - Checkbox group for multi-select (Police, Fire, Ambulance, SES, Other)
   - Initially hidden with CSS (`display: none`)
   - Show via JavaScript when Q16 = "Yes"
   - Add `id="form-widgets-emergency_services_types"` for JavaScript

3. **Remove emergency services from Section 4**
   - Remove old Q22 boolean field from Section 4
   - Keep Q23 (medical_treatment_location) and renumber to Q24

**Example HTML structure:**

```html
<!-- Q16: Emergency services called -->
<div class="field">
    <label for="form-widgets-emergency_services_called">
        <strong>Q16:</strong> Were emergency services called to the scene? <span class="required">*</span>
    </label>
    <select id="form-widgets-emergency_services_called" name="emergency_services_called" required>
        <option value="">-- Select --</option>
        <option value="yes">Yes</option>
        <option value="no">No</option>
    </select>
</div>

<!-- Q17: Emergency services types (conditional) -->
<div class="field" id="emergency-services-types-container" style="display: none;">
    <label>
        <strong>Q17:</strong> Which emergency services attended? <span class="required">*</span>
    </label>
    <div class="checkbox-group">
        <label><input type="checkbox" name="emergency_services_types" value="police"> Police (QPS)</label>
        <label><input type="checkbox" name="emergency_services_types" value="fire"> Fire and Emergency Services (QFES)</label>
        <label><input type="checkbox" name="emergency_services_types" value="ambulance"> Ambulance (QAS)</label>
        <label><input type="checkbox" name="emergency_services_types" value="ses"> SES (State Emergency Service)</label>
        <label><input type="checkbox" name="emergency_services_types" value="other"> Other emergency service</label>
    </div>
</div>
```

#### Phase 4: JavaScript Conditional Logic

**File:** `csc/src/csc/whs/browser/static/incident_form.js`

**Add conditional display logic:**

```javascript
// Show/hide emergency services types based on Q16 answer
document.addEventListener('DOMContentLoaded', function() {
    const emergencyCalledField = document.getElementById('form-widgets-emergency_services_called');
    const emergencyTypesContainer = document.getElementById('emergency-services-types-container');
    const emergencyTypesCheckboxes = document.querySelectorAll('input[name="emergency_services_types"]');

    if (emergencyCalledField && emergencyTypesContainer) {
        emergencyCalledField.addEventListener('change', function() {
            if (this.value === 'yes') {
                emergencyTypesContainer.style.display = 'block';
                // Make at least one checkbox required
                emergencyTypesCheckboxes.forEach(cb => cb.required = true);
            } else {
                emergencyTypesContainer.style.display = 'none';
                // Clear selections and remove required
                emergencyTypesCheckboxes.forEach(cb => {
                    cb.checked = false;
                    cb.required = false;
                });
            }
        });

        // Trigger on page load if value already set
        emergencyCalledField.dispatchEvent(new Event('change'));
    }
});

// Validate at least one emergency service selected if Q16=Yes
function validateEmergencyServices() {
    const emergencyCalled = document.getElementById('form-widgets-emergency_services_called').value;

    if (emergencyCalled === 'yes') {
        const checkboxes = document.querySelectorAll('input[name="emergency_services_types"]:checked');
        if (checkboxes.length === 0) {
            alert('Please select at least one emergency service type.');
            return false;
        }
    }
    return true;
}

// Add to form submit handler
document.querySelector('form').addEventListener('submit', function(e) {
    if (!validateEmergencyServices()) {
        e.preventDefault();
        return false;
    }
});
```

#### Phase 5: Intake Processing Updates

**Files:**
- `csc/src/csc/whs/browser/intake.py` (authenticated incidents)
- `csc/src/csc/whs/browser/anonymous.py` (anonymous incidents)

**Changes:**

1. **Extract emergency services fields from Section 3**
   ```python
   emergency_services_called = form.get('emergency_services_called', 'no')
   emergency_services_types = form.getlist('emergency_services_types', [])
   ```

2. **Validate conditional requirement**
   ```python
   if emergency_services_called == 'yes':
       if not emergency_services_types or len(emergency_services_types) == 0:
           return error_response("Please select at least one emergency service type")
   ```

3. **Store in incident object**
   ```python
   incident.emergency_services_called = emergency_services_called
   incident.emergency_services_types = emergency_services_types
   ```

4. **Remove old boolean field handling**
   - Delete code that sets `incident.emergency_services_called = True/False`

#### Phase 6: View Template Updates

**Files:**
- `csc/src/csc/whs/browser/templates/incident.pt` (incident view)

**Changes:**

1. **Update Section 3 display to show emergency services**
   ```html
   <div class="field" tal:condition="incident/emergency_services_called">
       <strong>Q16: Were emergency services called?</strong>
       <span tal:content="incident/emergency_services_called">Yes</span>
   </div>

   <div class="field" tal:condition="python: incident.emergency_services_called == 'yes' and incident.emergency_services_types">
       <strong>Q17: Emergency services attended:</strong>
       <ul>
           <li tal:repeat="service incident/emergency_services_types"
               tal:content="service">Police</li>
       </ul>
   </div>
   ```

2. **Remove emergency services from Section 4 display**
   - Remove old boolean display
   - Keep medical_treatment_location display (renumbered to Q24)

#### Phase 7: Email Notification Updates

**File:** `csc/src/csc/whs/notifications.py`

**Update email templates:**

1. **Add emergency services to incident notification**
   ```python
   if incident.emergency_services_called == 'yes':
       body += f"\n🚨 Emergency Services Called: {', '.join(incident.emergency_services_types)}\n"
   ```

2. **Update field labels if referencing question numbers**

#### Phase 8: Upgrade Step (Data Migration)

**File:** `csc/src/csc/whs/upgrades/v18.py` (or v19.py if separate)

**Create upgrade step to migrate existing data:**

```python
def migrate_emergency_services_field(setup_tool):
    """Migrate boolean emergency_services_called to choice field

    - Old: Boolean (True/False)
    - New: Choice ('yes'/'no')
    """
    catalog = api.portal.get_tool('portal_catalog')
    incidents = catalog(portal_type='csc.whs.incident')

    for brain in incidents:
        incident = brain.getObject()

        # Migrate boolean to choice
        old_value = getattr(incident, 'emergency_services_called', None)
        if isinstance(old_value, bool):
            incident.emergency_services_called = 'yes' if old_value else 'no'

        # Initialize empty list for emergency_services_types if not present
        if not hasattr(incident, 'emergency_services_types'):
            incident.emergency_services_types = []

        incident.reindexObject()

    logger.info(f"Migrated {len(incidents)} incidents")
```

**Register in upgrades.zcml:**

```xml
<genericsetup:upgradeStep
    source="17"
    destination="18"
    title="Migrate emergency services to Section 3"
    description="Convert emergency_services_called from boolean to choice field"
    handler="csc.whs.upgrades.v18.migrate_emergency_services_field"
    profile="csc.whs:default"
    />
```

#### Phase 9: CSS Styling

**File:** `csc/src/csc/whs/browser/static/incident_form.css`

**Add styling for checkbox group:**

```css
.checkbox-group {
    margin: 0.5rem 0;
}

.checkbox-group label {
    display: block;
    margin: 0.5rem 0;
    cursor: pointer;
}

.checkbox-group input[type="checkbox"] {
    margin-right: 0.5rem;
}

#emergency-services-types-container {
    margin-top: 1rem;
    padding: 1rem;
    background-color: #f8f9fa;
    border-left: 3px solid #0066cc;
}
```

#### Phase 10: Testing Plan

**Unit Tests:**
1. Test emergency services vocabulary returns correct values
2. Test conditional requirement validation
3. Test data migration from boolean to choice field

**Integration Tests:**
1. Submit incident with emergency_services_called = 'no' (should succeed)
2. Submit incident with emergency_services_called = 'yes' but no types selected (should fail)
3. Submit incident with emergency_services_called = 'yes' and types selected (should succeed)
4. Test authenticated and anonymous forms

**User Acceptance Testing:**
1. Fill incident form, select Q16="No" → Q17 should be hidden
2. Change Q16 to "Yes" → Q17 should appear and be required
3. Try to submit with Q16="Yes" but no services checked → should show error
4. Select at least one service → should submit successfully
5. Verify incident view displays emergency services correctly
6. Test on existing incidents (after migration)

#### Phase 11: Documentation Updates

**Files to update:**
- `csc/README.md` - Document new emergency services fields
- `PROJECT_STATUS.md` - Add to version notes
- User documentation - Update Section 3 instructions

### Files to Modify

#### Core Schema & Logic (4 files)
1. `csc/src/csc/whs/interfaces.py` - Move field, add new field, renumber questions
2. `csc/src/csc/whs/vocabularies.py` - Add EmergencyServicesVocabulary
3. `csc/src/csc/whs/configure.zcml` - Register new vocabulary
4. `csc/src/csc/whs/upgrades/v18.py` - Data migration from boolean to choice

#### Form Processing (2 files)
5. `csc/src/csc/whs/browser/intake.py` - Update field extraction and validation
6. `csc/src/csc/whs/browser/anonymous.py` - Update field extraction and validation

#### Templates (3 files)
7. `csc/src/csc/whs/browser/templates/report_incident.pt` - Move Q22→Q16, add Q17
8. `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Move Q22→Q16, add Q17
9. `csc/src/csc/whs/browser/templates/incident.pt` - Update view display

#### JavaScript & CSS (2 files)
10. `csc/src/csc/whs/browser/static/incident_form.js` - Conditional logic
11. `csc/src/csc/whs/browser/static/incident_form.css` - Checkbox group styling

#### Notifications (1 file)
12. `csc/src/csc/whs/notifications.py` - Update email templates

#### Configuration (2 files)
13. `csc/src/csc/whs/profiles/default/metadata.xml` - Profile version bump
14. `csc/src/csc/whs/profiles/default/upgrades.zcml` - Register upgrade step

**Total:** 14 files to modify

### Estimated Effort

- **Schema changes & renumbering:** 1 hour
- **Vocabulary creation:** 0.5 hours
- **Form template updates:** 2 hours
- **JavaScript conditional logic:** 1 hour
- **Intake processing & validation:** 1 hour
- **View template updates:** 0.5 hours
- **Data migration/upgrade step:** 1 hour
- **Testing:** 1.5 hours
- **Documentation:** 0.5 hours

**Total: 9 hours**

### Impact Analysis

**Breaking Changes:**
- Field type change: `emergency_services_called` from Boolean → Choice
- Requires data migration for existing incidents
- Upgrade step **must** be run after deployment

**Benefits:**
1. Emergency services questions apply to all incidents, not just injuries
2. Mandatory field ensures data completeness
3. Specific service types captured (Police, Fire, Ambulance)
4. Better organized - logical placement in Section 3
5. Conditional validation prevents submission errors

**Risks:**
- Data migration must work correctly to preserve existing data
- Conditional validation adds form complexity
- Question renumbering affects documentation/training materials

### Question Renumbering Impact

**Before (Current):**
- Section 3: Q13-Q15 (if Request #3 implemented)
- Section 4: Q16-Q23 (Injury Details)
- Section 5: Q24-Q26 (Property Damage)
- Section 6: Q27-Q28 (Preliminary Observations)

**After (with Request #4):**
- Section 3: Q13-Q17 (Incident Details + Emergency Services)
- Section 4: Q18-Q24 (Injury Details)
- Section 5: Q25-Q27 (Property Damage)
- Section 6: Q28-Q29 (Preliminary Observations)

**All subsequent question numbers shift by +2**

---

## Request #5: Add Plant Number Field to Section 5

**Date Requested:** October 18, 2025
**Status:** ⏳ Planning
**Priority:** Low
**Applies To:** Incidents only (authenticated and anonymous forms)

### Background

Section 5 (Property & Plant Damage) currently captures property damage types and details, but doesn't have a specific field for plant/vehicle identification numbers. Adding a plant number field will help with asset tracking and insurance claims.

### Current Implementation

**Section 5 (Property Damage) - Current Fields:**

From `interfaces.py` lines 262-290:

```python
# Q24: Type of property damaged (multi-select, 9 categories)
property_damage_types = schema.List(
    title=u"Type of property damaged",
    required=False,
    ...
)

# Q25: Further detail of property damaged
property_damage_detail = schema.Text(
    title=u"Further detail of property damaged",
    required=False,
    ...
)

# Q26: If you have damaged a Council vehicle / plant...
vehicle_damage_report_completed = schema.Choice(
    title=u"If you have damaged a Council vehicle / plant...",
    required=False,
    vocabulary="csc.whs.YesNoVocabulary",
)
```

**Note:** Question numbers shown above assume Requests #2, #3, and #4 have been implemented, shifting Section 5 from Q24-Q26 to Q25-Q27.

### Requested Changes

Add new field after property damage detail:

**New field:** `plant_number`
**Question number:** Q27 (between current detail and damage report fields)
**Type:** Text field (short text, optional)
**Label:** "Enter the plant number if one assigned"

### Implementation Plan

#### Phase 1: Schema Changes (csc/src/csc/whs/interfaces.py)

**File:** `csc/src/csc/whs/interfaces.py`

**Add new field in Section 5** (Property & Plant Damage section):

Current location: After `property_damage_detail` field
Insert before: `vehicle_damage_report_completed` field

```python
# ========================================
# PROPERTY DAMAGE DETAILS
# ========================================

# Q25: Type of property damaged (multi-select, 9 categories)
property_damage_types = schema.List(
    title=u"Type of property damaged",
    required=False,
    description=u"If the incident included property damage, select all types that apply. If not, move to the next section.",
    value_type=schema.Choice(
        vocabulary="csc.whs.PropertyDamageTypeVocabulary"
    ),
)

# Q26: Further detail of property damaged
property_damage_detail = schema.Text(
    title=u"Further detail of property damaged",
    required=False,
    description=u"e.g. type of plant, structure and detail of damage received. Include make and model of vehicle / plant if known",
)

# Q27: Plant number (NEW FIELD)
plant_number = schema.TextLine(
    title=u"Enter the plant number if one assigned",
    required=False,
    description=u"Council asset/plant number (if applicable). This helps identify the specific vehicle or equipment involved.",
)

# Q28: Vehicle damage report completed (renumbered from Q26)
vehicle_damage_report_completed = schema.Choice(
    title=u"If you have damaged a Council vehicle / plant, or been involved in damage of other vehicle / plant, have you completed a Plant / Vehicle Damage Report?",
    required=False,
    description=u"A Plant / Vehicle Damage Report must be completed in this circumstance, and sent to the Insurance Claims Officer / Manager Fleet & Workshop",
    vocabulary="csc.whs.YesNoVocabulary",
)
```

**Update question numbers:**
- Current Q26 (vehicle_damage_report_completed) → Q28
- All subsequent questions shift by +1

#### Phase 2: Form Template Updates

**Files:**
- `csc/src/csc/whs/browser/templates/report_incident.pt`
- `csc/src/csc/whs/browser/templates/anonymous_form.pt`

**Changes in Section 5:**

Add Q27 field after property damage detail (Q26) and before damage report question (Q28):

```html
<!-- Q26: Property damage detail -->
<div class="field">
    <label for="form-widgets-property_damage_detail">
        <strong>Q26:</strong> Further detail of property damaged
    </label>
    <textarea id="form-widgets-property_damage_detail"
              name="property_damage_detail"
              rows="4"
              placeholder="e.g. type of plant, structure and detail of damage received. Include make and model of vehicle / plant if known"></textarea>
</div>

<!-- Q27: Plant number (NEW) -->
<div class="field">
    <label for="form-widgets-plant_number">
        <strong>Q27:</strong> Enter the plant number if one assigned
    </label>
    <input type="text"
           id="form-widgets-plant_number"
           name="plant_number"
           placeholder="e.g. P123, VEH-456"
           maxlength="50">
    <p class="field-description">Council asset/plant number (if applicable). This helps identify the specific vehicle or equipment involved.</p>
</div>

<!-- Q28: Vehicle damage report completed (renumbered) -->
<div class="field">
    <label for="form-widgets-vehicle_damage_report_completed">
        <strong>Q28:</strong> If you have damaged a Council vehicle / plant, or been involved in damage of other vehicle / plant, have you completed a Plant / Vehicle Damage Report?
    </label>
    <select id="form-widgets-vehicle_damage_report_completed" name="vehicle_damage_report_completed">
        <option value="">-- Select --</option>
        <option value="yes">Yes</option>
        <option value="no">No</option>
    </select>
</div>
```

#### Phase 3: Intake Processing Updates

**Files:**
- `csc/src/csc/whs/browser/intake.py` (authenticated incidents)
- `csc/src/csc/whs/browser/anonymous.py` (anonymous incidents)

**Add field extraction:**

```python
# Extract property damage fields
property_damage_types = form.getlist('property_damage_types', [])
property_damage_detail = form.get('property_damage_detail', '')
plant_number = form.get('plant_number', '').strip()  # NEW
vehicle_damage_report_completed = form.get('vehicle_damage_report_completed', '')

# Store in incident object
incident.property_damage_types = property_damage_types
incident.property_damage_detail = property_damage_detail
incident.plant_number = plant_number  # NEW
incident.vehicle_damage_report_completed = vehicle_damage_report_completed
```

**Note:** No validation needed - field is optional

#### Phase 4: View Template Updates

**File:** `csc/src/csc/whs/browser/templates/incident.pt`

**Update Section 5 display:**

Add plant number display between property damage detail and damage report:

```html
<!-- Section 5: Property & Plant Damage -->
<div class="section" tal:condition="python: incident.property_damage_types or incident.property_damage_detail or incident.plant_number or incident.vehicle_damage_report_completed">
    <h3 class="section-header">Section 5: Property & Plant Damage</h3>

    <!-- Q25: Property damage types -->
    <div class="field" tal:condition="incident/property_damage_types">
        <strong>Q25: Type of property damaged:</strong>
        <ul>
            <li tal:repeat="damage_type incident/property_damage_types"
                tal:content="damage_type">Vehicle</li>
        </ul>
    </div>

    <!-- Q26: Property damage detail -->
    <div class="field" tal:condition="incident/property_damage_detail">
        <strong>Q26: Further detail of property damaged:</strong>
        <p tal:content="structure python:incident.property_damage_detail">Detail here</p>
    </div>

    <!-- Q27: Plant number (NEW) -->
    <div class="field" tal:condition="incident/plant_number">
        <strong>Q27: Plant number:</strong>
        <span tal:content="incident/plant_number">P123</span>
    </div>

    <!-- Q28: Vehicle damage report -->
    <div class="field" tal:condition="incident/vehicle_damage_report_completed">
        <strong>Q28: Plant / Vehicle Damage Report completed:</strong>
        <span tal:content="incident/vehicle_damage_report_completed">Yes</span>
    </div>
</div>
```

#### Phase 5: Email Notification Updates

**File:** `csc/src/csc/whs/notifications.py`

**Add plant number to email template:**

```python
# Property damage section
if incident.property_damage_types or incident.property_damage_detail:
    body += "\n📦 PROPERTY DAMAGE:\n"
    if incident.property_damage_types:
        body += f"  Types: {', '.join(incident.property_damage_types)}\n"
    if incident.property_damage_detail:
        body += f"  Details: {incident.property_damage_detail}\n"
    if incident.plant_number:  # NEW
        body += f"  Plant Number: {incident.plant_number}\n"  # NEW
    if incident.vehicle_damage_report_completed:
        body += f"  Damage Report Completed: {incident.vehicle_damage_report_completed}\n"
```

#### Phase 6: Testing Plan

**Unit Tests:**
1. Test field accepts alphanumeric plant numbers (e.g., "P123", "VEH-456")
2. Test field accepts empty value (optional field)
3. Test field trims whitespace

**Integration Tests:**
1. Submit incident with plant number filled (should succeed)
2. Submit incident without plant number (should succeed - optional field)
3. Test authenticated and anonymous forms
4. Verify plant number stored correctly

**User Acceptance Testing:**
1. Fill incident form with property damage and plant number
2. Verify plant number displays in incident view
3. Verify plant number appears in email notification
4. Test plant number field with various formats (numeric, alphanumeric, with dashes)

#### Phase 7: CSS Styling (Optional)

**File:** `csc/src/csc/whs/browser/static/incident_form.css`

**Optional styling for plant number field:**

```css
#form-widgets-plant_number {
    max-width: 200px;
    font-family: monospace; /* Makes asset numbers easier to read */
}

#form-widgets-plant_number::placeholder {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
```

#### Phase 8: Documentation Updates

**Files to update:**
- `csc/README.md` - Document new plant_number field
- `PROJECT_STATUS.md` - Add to version notes
- User documentation - Update Section 5 instructions

### Files to Modify

1. `csc/src/csc/whs/interfaces.py` - Add plant_number field, renumber Q26→Q28
2. `csc/src/csc/whs/browser/templates/report_incident.pt` - Add Q27 field
3. `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Add Q27 field
4. `csc/src/csc/whs/browser/templates/incident.pt` - Display plant number
5. `csc/src/csc/whs/browser/intake.py` - Extract and store plant_number
6. `csc/src/csc/whs/browser/anonymous.py` - Extract and store plant_number
7. `csc/src/csc/whs/notifications.py` - Add to email template
8. `csc/src/csc/whs/browser/static/incident_form.css` - Optional styling

**Total:** 7-8 files to modify

### Estimated Effort

- **Schema changes:** 0.25 hours
- **Form template updates:** 0.5 hours
- **Intake processing:** 0.25 hours
- **View template updates:** 0.25 hours
- **Email notifications:** 0.25 hours
- **Testing:** 0.5 hours
- **Documentation:** 0.25 hours

**Total: 2-2.5 hours**

### Question Renumbering Impact

**Only affects Section 5 and beyond:**

- Section 5 (Property Damage):
  - Q25: property_damage_types (unchanged)
  - Q26: property_damage_detail (unchanged)
  - **Q27: plant_number (NEW)**
  - Q28: vehicle_damage_report_completed (was Q26, now Q28)

- Section 6 (Preliminary Observations):
  - Q29: contributing_factors_identified (was Q27, now Q29)
  - Q30: preventative_actions_suggested (was Q28, now Q30)

**Minimal impact** - only shifts 2 questions by +1

### Design Decisions

#### Decision 1: Field Type
**Options:**
- A) TextLine (short text, single line)
- B) Text (multi-line textarea)
- C) Choice (dropdown with predefined plant numbers)

**Recommendation:** Option A (TextLine)
- **Pros:** Simple, flexible for various numbering schemes
- **Cons:** No validation of format
- **Justification:** Plant numbering schemes vary; free text most flexible

#### Decision 2: Required vs Optional
**Options:**
- A) Optional (not required)
- B) Required if property damage selected
- C) Always required

**Recommendation:** Option A (Optional)
- **Pros:** Doesn't block form if plant number unknown
- **Cons:** May be left empty when should be filled
- **Justification:** Not all property damage involves numbered plant/vehicles

#### Decision 3: Field Length
**Recommendation:** MaxLength = 50 characters
- Covers most asset numbering schemes
- Short enough to prevent abuse
- Long enough for descriptive identifiers

### Impact on Existing Data

**No impact on existing incidents:**
- New optional field, defaults to empty/None
- No data migration required
- No upgrade step needed
- Existing incidents display normally (field simply not shown if empty)

### User Experience Improvements

**Before:**
- Plant/vehicle numbers buried in free-text "property damage detail" field
- Difficult to extract for reporting
- Not consistently captured

**After:**
- Dedicated plant number field
- Easy to search and report on
- Consistent data structure
- Still optional to not block forms

### Integration with Fleet Management

**Future Enhancement Opportunities:**
1. Validate plant number against fleet management system
2. Auto-populate vehicle/plant details from number
3. Link to asset register for make/model information
4. Generate reports by plant number for maintenance planning

**Not included in this request** - just documents future possibilities

---

## Summary: All WHS Officer Requests

### Request Overview

| # | Request | Priority | Files | Effort | Impact |
|---|---------|----------|-------|--------|--------|
| 1 | Replace Division with Department | High | 18 | 8-10h | Moderate - Data migration |
| 2 | Section 3 Enhancements (Title, Required) | Medium | 8 | 5-6h | Low - New submissions only |
| 3 | Number Section 3 Questions | Low | 2-4 | 1-1.25h | None - Cosmetic |
| 4 | Move Emergency Services to Section 3 | Medium | 14 | 9h | High - Breaking change |
| 5 | Add Plant Number Field | Low | 7-8 | 2-2.5h | None - New field |

**Total Estimated Effort: 25.5-28.75 hours (traditional development)**

### Implementation Strategy

**Option A: Implement All Together (Recommended)**
- Version: 0.10.18
- Single upgrade step (17→18)
- All changes tested together
- One deployment, one verification cycle
- **Estimated: 20-22 hours (AI-assisted)** with efficiencies from batch implementation

**Option B: Phased Approach**
- Phase 1 (v0.10.18): Request #1 (Division→Department)
- Phase 2 (v0.10.19): Requests #2, #3, #4 (Section 3 enhancements)
- Phase 3 (v0.10.20): Request #5 (Plant number)
- Allows incremental testing and user feedback
- More deployments, longer total timeline
- **Estimated: 25-29 hours** due to repeated deployment/testing cycles

### Deployment Dependencies

**Must be implemented together:**
- Request #3 depends on Request #2 (both affect Section 3 numbering)
- Request #4 renumbers questions, affects all subsequent sections

**Can be implemented independently:**
- Request #1 (Division→Department) standalone
- Request #5 (Plant number) standalone or with others

### Recommendation

Implement **Requests #2, #3, #4, and #5 together** as they all affect question numbering. This creates a clean "Section 3 Enhancement" release.

**Request #1** (Division→Department) could be done separately or included, depending on priority and testing capacity.

---

## Change Log

| Date | Version | Request | Status | Notes |
|------|---------|---------|--------|-------|
| 2025-10-18 | 0.10.18 | Request #1: Replace Division with Department | Planning | Implementation plan created |
| 2025-10-18 | 0.10.18/19 | Request #2: Incident Form Section 3 Enhancements | Planning | Title auto-generation, required fields |
| 2025-10-18 | 0.10.18/19 | Request #3: Number Section 3 Questions | Planning | Add Q13-Q15 numbering for consistency |
| 2025-10-18 | 0.10.18/19 | Request #4: Move Emergency Services to Section 3 | Planning | Q16-Q17, conditional multi-select, data migration required |
| 2025-10-18 | 0.10.18/19 | Request #5: Add Plant Number Field | Planning | Q27 in Section 5, optional field |

---

## Request #10: Fix Q13 Title Field - Remove from Form & Update Generation Formula

**Date Requested:** October 21, 2025
**Status:** ⏳ Planning
**Priority:** High
**Applies To:** Incidents only (authenticated and anonymous forms)

### Background

The WHS Officer identified a mismatch between the Q13 title field label and the actual auto-generation behavior, and requested that the field be made mandatory and non-modifiable. After analysis, the decision was made to remove Q13 from the user-facing form entirely and generate the title server-side.

### Current Implementation

**Q13 Field Issues:**

From `report_incident.pt` lines 433-447:
```html
<!-- Q13: Title (auto-generated) -->
<div class="whs-form-field">
    <label for="title">
        13. Brief title / summary
        <span class="required">*</span>
    </label>
    <p class="field-description">
        This will be auto-generated from the town and date, but you can edit it if needed (max 200 characters)
    </p>
    <input type="text"
           id="title"
           name="title"
           maxlength="200"
           class="whs-input"
           placeholder="Will auto-generate from location and date" />
</div>
```

**Current Title Generation (JavaScript):**

From `incident_form.js` lines 1338-1413:
- Formula: `{Incident Type} - {Department} - {Location Town}`
- Example: "First Aid Injury - Biosecurity - Cooktown"

**Problems:**
1. Label says "auto-generated from town and date" but actually uses incident type, department, and location town
2. Field is editable by user (not non-modifiable as requested)
3. JavaScript generation is less reliable than server-side
4. Users don't need to see this field during data entry
5. Formula doesn't match WHS Officer's requirements

### Requested Changes

#### Change 10A: Remove Q13 from Form Templates

**Action:** Completely remove the Q13 title field from both authenticated and anonymous incident forms

**Rationale:**
- Users don't need to see title during form entry
- Title visible in incident views, listings, and search results after submission
- Cleaner UX without confusion about editable vs non-editable fields
- Server-side generation more reliable than JavaScript
- Eliminates label/description mismatch

**Files affected:**
- `csc/src/csc/whs/browser/templates/report_incident.pt`
- `csc/src/csc/whs/browser/templates/anonymous_form.pt`

#### Change 10B: Update Title Generation Formula

**Current Formula:**
```
{Incident Type} - {Department} - {Location Town}
```

**New Formula:**
```
{Injury Type} - {Person Name} - {Town/Locality} - {Date}
```

**Example:**
- Old: "First Aid Injury - Biosecurity - Cooktown"
- New: "Sprain/Strain - John Smith - Cooktown - 21/10/2025"

**Field Mapping:**
- **Injury Type:** `injury_classifications` field (first selected if multiple)
  - Values: Sprain/Strain, Laceration/Cut, Bruise/Contusion, Fracture, etc.
- **Person Name:** `injured_person_name` field
  - Full name of person injured or principally involved
- **Town/Locality:** `location_town` field
  - Town or suburb where incident occurred
- **Date:** `incident_date` field
  - Format: DD/MM/YYYY

#### Change 10C: Implement Server-Side Title Generation

**Location:** `csc/src/csc/whs/browser/intake.py` and `anonymous.py`

**Implementation:**
1. Generate title in intake processing after form validation
2. Set Dublin Core title before object creation
3. Handle edge cases (missing fields, multiple injury types, etc.)

**Pseudocode:**
```python
def generate_incident_title(incident_data):
    """Generate incident title from key fields

    Returns: "Injury Type - Person Name - Town - Date"
    """
    # Get injury type (first selected, or "Not Specified")
    injury_type = incident_data.get('injury_classifications', [])[0] if incident_data.get('injury_classifications') else 'Not Specified'

    # Get person name
    person_name = incident_data.get('injured_person_name', 'Unknown')

    # Get location town
    location_town = incident_data.get('location_town', 'Unknown Location')

    # Get date (format DD/MM/YYYY)
    incident_date = incident_data.get('incident_date')
    date_str = incident_date.strftime('%d/%m/%Y') if incident_date else 'No Date'

    # Generate title
    title = f"{injury_type} - {person_name} - {location_town} - {date_str}"

    return title
```

#### Change 10D: Remove JavaScript Title Generation

**File:** `csc/src/csc/whs/browser/static/incident_form.js`

**Action:** Remove `initializeTitleAutoGeneration()` function and related code (lines 1338-1413)

**Impact:** JavaScript no longer needed for title generation

#### Change 10E: Update Question Numbering

**Action:** Renumber questions after Q13 removal

**Impact:**
- Current Q14 (What happened) → Q13
- Current Q15 (Immediate Actions) → Q14
- Current Q16 (Emergency Services Called) → Q15
- Current Q17 (Emergency Services Types) → Q16
- All subsequent questions shift up by 1

**Note:** This assumes Requests #2-#5 have been implemented. If not, numbering may differ.

### Implementation Plan

#### Phase 1: Remove Q13 from Form Templates

**Files:**
- `csc/src/csc/whs/browser/templates/report_incident.pt`
- `csc/src/csc/whs/browser/templates/anonymous_form.pt`

**Changes:**
1. Delete Q13 title field div (lines ~433-447 in report_incident.pt)
2. Renumber subsequent questions (Q14→Q13, Q15→Q14, etc.)
3. Update all question number references in labels

#### Phase 2: Add Title Generation Utility Function

**File:** `csc/src/csc/whs/utilities.py` (create if doesn't exist)

**Add function:**
```python
def generate_incident_title(injury_classifications, injured_person_name, location_town, incident_date):
    """Generate incident title for automatic naming

    Args:
        injury_classifications: List of injury classification tokens (e.g., ['sprain-strain'])
        injured_person_name: Full name of person injured or principally involved
        location_town: Town or suburb where incident occurred
        incident_date: Date object of incident

    Returns:
        str: Generated title (e.g., "Sprain/Strain - John Smith - Cooktown - 21/10/2025")
    """
    # Implementation here
```

#### Phase 3: Update Intake Processing

**Files:**
- `csc/src/csc/whs/browser/intake.py` (authenticated form)
- `csc/src/csc/whs/browser/anonymous.py` (anonymous form)

**Changes:**
1. Import title generation function
2. Generate title after form validation
3. Set incident.title with generated value
4. Remove any existing title extraction from form data

**Example:**
```python
from csc.whs.utilities import generate_incident_title

# After extracting form data and validation
incident_title = generate_incident_title(
    injury_classifications=injury_classifications,
    injured_person_name=injured_person_name,
    location_town=location_town,
    incident_date=incident_date
)

# Set title
incident.title = incident_title
incident.setTitle(incident_title)
```

#### Phase 4: Remove JavaScript Title Generation

**File:** `csc/src/csc/whs/browser/static/incident_form.js`

**Changes:**
1. Remove `initializeTitleAutoGeneration()` function (lines 1338-1413)
2. Remove function call from DOMContentLoaded event listener
3. Remove any related helper functions (if any)

#### Phase 5: Update Schema Comments (Optional)

**File:** `csc/src/csc/whs/interfaces.py`

**Update comment in Section 3:**
```python
# ========================================
# SECTION 3: INCIDENT DETAILS
# ========================================
# Title is auto-generated server-side from: Injury Type - Person Name - Location Town - Date
# Not displayed in form (Dublin Core title field used)

# Q13: What happened (Dublin Core description field)
# Q14: Immediate Actions Taken
```

#### Phase 6: Testing Plan

**Unit Tests:**
1. Test title generation with all fields present
2. Test title generation with missing injury type (should use "Not Specified")
3. Test title generation with missing person name (should use "Unknown")
4. Test title generation with multiple injury types (should use first)
5. Test title generation with missing date (should handle gracefully)

**Integration Tests:**
1. Submit authenticated incident form (verify title generated correctly)
2. Submit anonymous incident form (verify title generated correctly)
3. Verify title visible in incident view template
4. Verify title visible in incident listing
5. Verify title visible in search results

**User Acceptance Testing:**
1. Create test incident via authenticated form
2. Verify title not shown during form entry
3. Submit form and navigate to incident view
4. Verify title matches pattern: "Injury Type - Person Name - Town - Date"
5. Create test incident via anonymous form and verify same behavior

#### Phase 7: Documentation Updates

**Files to update:**
- `csc/README.md` - Document title auto-generation change
- `PROJECT_STATUS.md` - Add to version notes
- Form user documentation - Remove references to Q13 title field

### Files to Modify

1. `csc/src/csc/whs/browser/templates/report_incident.pt` - Remove Q13, renumber questions
2. `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Remove Q13, renumber questions
3. `csc/src/csc/whs/utilities.py` - Add title generation function (create if needed)
4. `csc/src/csc/whs/browser/intake.py` - Add server-side title generation
5. `csc/src/csc/whs/browser/anonymous.py` - Add server-side title generation
6. `csc/src/csc/whs/browser/static/incident_form.js` - Remove JS title generation
7. `csc/src/csc/whs/interfaces.py` - Update schema comments (optional)

**Total:** 6-7 files to modify

### Estimated Effort

- **Remove Q13 from templates & renumber:** 1 hour
- **Create title generation utility:** 0.5 hours
- **Update intake processing (both forms):** 1 hour
- **Remove JavaScript code:** 0.25 hours
- **Testing:** 1 hour
- **Documentation:** 0.25 hours

**Total: 4 hours**

### Impact Analysis

**Benefits:**
1. Title always generated consistently (no user variation)
2. Cleaner user experience (one less field to see/ignore)
3. Server-side generation more reliable than JavaScript
4. Title format matches WHS Officer's requirements
5. Eliminates confusion about editable vs non-editable field
6. Title visible where it matters (views, listings, search)

**Risks:**
1. Question numbering changes (Q14→Q13, Q15→Q14, etc.)
2. Documentation needs updating to reflect new numbering
3. Users accustomed to seeing title field may ask where it went

**Mitigation:**
- Update all documentation with new question numbers
- Add note in form instructions: "Incident title will be generated automatically"
- Communicate change to WHS Officers before deployment

### Edge Cases to Handle

1. **Missing Injury Classification:** Use "Not Specified" or "Unknown Injury Type"
2. **Multiple Injury Classifications:** Use first selected classification
3. **Missing Person Name:** Use "Unknown Person" or fall back to reporter name
4. **Missing Location Town:** Use "Unknown Location" or extract from location field
5. **Missing Incident Date:** Use submission date or "No Date"
6. **Very Long Names/Towns:** Truncate title to 200 chars (Dublin Core title max length)

**Formula with Edge Cases:**
```python
injury_type = injury_classifications[0] if injury_classifications else "Not Specified"
person_name = injured_person_name or "Unknown Person"
location_town = location_town or "Unknown Location"
date_str = incident_date.strftime('%d/%m/%Y') if incident_date else "No Date"

title = f"{injury_type} - {person_name} - {location_town} - {date_str}"

# Truncate if needed
if len(title) > 200:
    title = title[:197] + "..."
```

### User Experience Comparison

**Before (Current):**
- Q13 visible in form with placeholder "Will auto-generate from location and date"
- User sees title field but description doesn't match behavior
- JavaScript generates title from incident type, department, town
- User can edit title (but shouldn't)
- Confusion about what title will be

**After (Request #10):**
- Q13 not visible in form
- No confusion about editable fields
- Title generated server-side with correct formula
- User doesn't need to think about title during entry
- Title visible in views/listings after submission with predictable format: "Injury Type - Person Name - Town - Date"

### Integration Notes

**This change integrates well with:**
- Request #2: Already makes immediate actions mandatory
- Request #3: Already adds question numbering to Section 3
- Request #4: Emergency services fields (Q16-Q17 become Q15-Q16)

**Can be implemented:**
- Standalone (if Requests #2-#5 not implemented yet)
- Together with other Section 3 enhancements
- As part of larger form improvement release

### Question Numbering After Implementation

**Section 3 (Incident Details):**
- ~~Q13: Title (REMOVED)~~
- Q13: What happened (was Q14)
- Q14: Immediate Actions (was Q15)
- Q15: Emergency Services Called (was Q16)
- Q16: Emergency Services Types (was Q17)

**Section 4+ shift up by 1:**
- All subsequent sections renumbered accordingly

---

## Summary: All WHS Officer Requests

### Request Overview

| # | Request | Priority | Files | Effort | Impact |
|---|---------|----------|-------|--------|--------|
| 1 | Replace Division with Department | High | 18 | 8-10h | Moderate - Data migration |
| 2 | Section 3 Enhancements (Title, Required) | Medium | 8 | 5-6h | Low - New submissions only |
| 3 | Number Section 3 Questions | Low | 2-4 | 1-1.25h | None - Cosmetic |
| 4 | Move Emergency Services to Section 3 | Medium | 14 | 9h | High - Breaking change |
| 5 | Add Plant Number Field | Low | 7-8 | 2-2.5h | None - New field |
| **10** | **Fix Q13 Title Field - Remove & Update Formula** | **High** | **6-7** | **4h** | **Medium - Question renumbering** |

**Total Estimated Effort: 29.5-32.75 hours (traditional development)**

### Updated Implementation Strategy

**Recommended Approach:**

Since Request #10 directly modifies the title generation behavior from Request #2, these should be implemented together:

**Phase A (v0.10.28): Title & Section 3 Enhancements**
- Request #2: Section 3 field requirements (modify title approach)
- Request #3: Number Section 3 Questions
- Request #10: Remove Q13, server-side title generation
- Estimated: 6-7 hours (combined with efficiencies)

**Phase B (v0.10.29): Emergency Services Enhancement**
- Request #4: Move emergency services to Section 3
- Estimated: 9 hours

**Phase C (Later): Department & Plant Number**
- Request #1: Division→Department (complex, standalone)
- Request #5: Plant Number (can be added anytime)
- Estimated: 10.5-12.5 hours

### Deployment Dependencies

**Must be implemented together:**
- Request #2 and Request #10 (both affect title generation)
- Request #3 with either #2 or #10 (question numbering)

**Can be implemented independently:**
- Request #1 (Division→Department) - standalone
- Request #4 (Emergency Services) - affects question numbering
- Request #5 (Plant Number) - minimal impact

---

## Change Log

| Date | Version | Request | Status | Notes |
|------|---------|---------|--------|-------|
| 2025-10-18 | 0.10.18 | Request #1: Replace Division with Department | Planning | Implementation plan created |
| 2025-10-18 | 0.10.18/19 | Request #2: Incident Form Section 3 Enhancements | Planning | Title auto-generation, required fields |
| 2025-10-18 | 0.10.18/19 | Request #3: Number Section 3 Questions | Planning | Add Q13-Q15 numbering for consistency |
| 2025-10-18 | 0.10.18/19 | Request #4: Move Emergency Services to Section 3 | Planning | Q16-Q17, conditional multi-select, data migration required |
| 2025-10-18 | 0.10.18/19 | Request #5: Add Plant Number Field | Planning | Q27 in Section 5, optional field |
| 2025-10-21 | 0.10.28 | Request #10: Fix Q13 Title Field - Remove & Update Formula | Planning | Remove Q13 from form, server-side generation with new formula |

---

**Document Maintained By:** Cook Shire Council IT Department
**Last Updated:** October 21, 2025
