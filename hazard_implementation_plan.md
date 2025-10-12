# Hazard Report Implementation Plan

## Overview
Implement a complete Hazard Report system in the csc.whs addon, mirroring the structure and functionality of the existing Incident Report system, but adapted for hazard identification and risk assessment.

## Form Fields Analysis (from HAZARD_REPORT.pdf)

### Required Fields (*)
1. **Date hazard identified** - Date field (dd/MM/yyyy)
2. **Name of person who identified the hazard** - Text field
3. **Person Reporting the identified hazard** - Text field
4. **Location of hazard** - Textarea (Provide address and/or area)
5. **Division primarily associated with this hazard** - Select dropdown
6. **How would you categorise this hazard** - Multi-select checkboxes with 14 categories
7. **Provide detail of the hazard you have identified** - Textarea

### Optional Fields
8. **Suggested preventative or corrective measures** - Textarea
9. **Risk rating matrix** - Radio button matrix (5x5 grid: Likelihood vs Consequence)

### Hazard Categories (14 options, multi-select)
1. Chemical
2. Electrical
3. Environmental
4. Hazardous Manual Task
5. Height
6. Human factors
7. Mechanical
8. Mobile Plant
9. Pressure
10. Psychosocial
11. Radiation
12. Thermal
13. Workplace
14. Other

### Risk Matrix (5x5 grid)
**Likelihood levels:**
- Almost certain (≥90%)
- Likely (≥60% & <90%)
- Possible (≥30% & <60%)
- Unlikely (≥10% & <30%)
- Rare (<10%)

**Consequence levels:**
- Very High (death, permanent disability, major damage)
- Major (serious injury or significant disruption)
- Moderate (medical treatment required, moderate disruption)
- Minor (first aid required, minor disruption)
- Insignificant (no injuries or disruptions)

## Implementation Components

### Phase 1: Content Type Definition
**File:** `src/csc/whs/content/hazard.py`

Create `csc.whs.hazard` content type with fields:
- `identified_date` (Date) - *Required*
- `identified_by_name` (TextLine) - *Required*
- `identified_by_username` (TextLine) - Hidden, for LDAP lookup
- `reported_by_name` (TextLine) - *Required*
- `reported_by_username` (TextLine) - Hidden
- `reported_by_email` (TextLine) - For anonymous users
- `location` (Text) - *Required*
- `division` (Choice from vocabulary) - *Required*
- `hazard_categories` (List of Choice) - *Required*, multi-select
- `hazard_description` (Text) - *Required*
- `suggested_controls` (Text) - Optional
- `risk_likelihood` (Choice) - Optional, from vocabulary
- `risk_consequence` (Choice) - Optional, from vocabulary
- `risk_rating` (TextLine) - Computed field based on matrix
- `attachments` (List of NamedBlobFile) - Up to 3 photos/documents

**Behaviors:**
- `plone.dublincore.IDublinCore`
- `plone.namefromtitle.INameFromTitle`
- `plone.versioning.IVersionable`

### Phase 2: Vocabularies
**File:** `src/csc/whs/vocabularies.py`

Add new vocabulary factories:
1. **`hazard_category_options`** - 14 hazard categories with full descriptions
2. **`risk_likelihood_options`** - 5 likelihood levels with percentages
3. **`risk_consequence_options`** - 5 consequence levels with descriptions

Note: Reuse existing `directorate_options` vocabulary for divisions.

### Phase 3: Browser Views & Form
**File:** `src/csc/whs/browser/report_hazard.py`

Create view class `ReportHazardView` with methods:
- `is_authenticated()`
- `current_user_fullname()`
- `authenticator()` - CSRF token
- `portal_url()`
- `today_iso()`
- `get_directorate_options()`
- `get_hazard_category_options()`
- `get_risk_likelihood_options()`
- `get_risk_consequence_options()`

**File:** `src/csc/whs/browser/templates/report_hazard.pt`

Create template with progressive sections (matching incident form UX):
- **Section 1: Hazard Identification** (Q1-Q3)
  - Date identified
  - Person who identified (LDAP search for authenticated users)
  - Person reporting
- **Section 2: Location & Division** (Q4-Q5)
  - Location with interactive map (reuse incident form map functionality)
  - Division dropdown
- **Section 3: Hazard Details** (Q6-Q7)
  - Multi-select hazard categories (checkboxes)
  - Detailed description
- **Section 4: Risk Assessment & Controls** (Q8-Q9)
  - Suggested controls (optional)
  - Risk matrix (5x5 radio button grid)
  - Attachments (up to 3 files)

Use same styling approach as incident form:
- Progressive collapsible sections
- Mobile-optimized (16-18px fonts, 48px touch targets)
- Leaflet.js map for location
- LDAP autocomplete for person identification

**File:** `src/csc/whs/browser/hazard_intake.py`

Create intake handler `HazardIntakeView` with methods:
- `__call__()` - Main form handler
- `validate_form()` - Server-side validation
- `create_hazard()` - Creates hazard content object
- `calculate_risk_rating()` - Computes risk level from matrix
- `handle_attachments()` - Process file uploads
- `send_notifications()` - Email to WHS officer

Risk rating calculation logic:
- Combine likelihood + consequence to determine priority
- Return rating: Extreme, High, Medium, Low

### Phase 4: Static Resources
**Files:**
- `src/csc/whs/browser/static/hazard_form.css` - Based on incident_form.css
- `src/csc/whs/browser/static/hazard_form.js` - Based on incident_form.js

Features to include:
- Progressive section management
- LDAP user search (reuse from incident form)
- Interactive map for location (reuse Leaflet.js implementation)
- Risk matrix interaction (highlight selected cell, show computed rating)
- Form validation
- File upload handling

### Phase 5: Content Type Registration
**File:** `src/csc/whs/profiles/default/types/csc.whs.hazard.xml`

Define content type with:
- Title: "Hazard Report"
- Description: "A reported workplace hazard requiring assessment and control"
- Icon: hazard icon
- Add permission: "csc.whs: Add Hazard"
- Allowed content types: None (leaf content)
- Factory: dexterity.Item
- Schema: csc.whs.content.hazard.IHazard

**File:** `src/csc/whs/profiles/default/types.xml`

Register `csc.whs.hazard` content type.

### Phase 6: Workflow
**File:** `src/csc/whs/profiles/default/workflows/csc_hazard_workflow/definition.xml`

Create workflow states (similar to incident workflow):
- **submitted** - Initial state when hazard reported
- **under_review** - WHS officer reviewing hazard
- **controls_applied** - Control measures implemented
- **monitoring** - Ongoing monitoring of controls
- **closed** - Hazard resolved/no longer present

Transitions:
- submit → under_review (automatic on creation)
- under_review → controls_applied
- controls_applied → monitoring
- monitoring → closed
- Any state → under_review (if reassessment needed)

Permissions:
- Reporter can view their own hazard
- WHS Officer can view/edit all hazards
- Manager can view all hazards
- Site Administrator has full access

### Phase 7: Interface Registration
**File:** `src/csc/whs/interfaces.py`

Add marker interface:
```python
class IHazard(Interface):
    """Marker interface for hazard reports"""
```

### Phase 8: Browser View Registration
**File:** `src/csc/whs/configure.zcml`

Register browser views:
```xml
<!-- Hazard report form view -->
<browser:page
    name="report-hazard"
    for="*"
    class=".browser.report_hazard.ReportHazardView"
    template="browser/templates/report_hazard.pt"
    permission="zope2.View"
    />

<!-- Hazard intake handler -->
<browser:page
    name="whs-hazard-intake"
    for="*"
    class=".browser.hazard_intake.HazardIntakeView"
    permission="zope2.View"
    />

<!-- Hazard display view -->
<browser:page
    name="view"
    for=".interfaces.IHazard"
    class=".browser.hazard.HazardView"
    template="browser/templates/hazard.pt"
    permission="zope2.View"
    />
```

### Phase 9: Notifications
**File:** `src/csc/whs/notifications.py`

Add function `send_hazard_notification(hazard, request)`:
- Send email to WHS officer when hazard reported
- Include hazard details, risk rating, location
- Link to hazard in portal
- CC reporter if they provided email

### Phase 10: Catalog Indexes
**File:** `src/csc/whs/profiles/default/catalog.xml`

Add indexes for hazard searches:
- `identified_date` (DateIndex)
- `division` (FieldIndex)
- `hazard_categories` (KeywordIndex)
- `risk_likelihood` (FieldIndex)
- `risk_consequence` (FieldIndex)
- `risk_rating` (FieldIndex)

### Phase 11: Upgrade Step
**File:** `src/csc/whs/upgrades/v10.py`

Create upgrade step to:
1. Register new content type
2. Install new workflow
3. Add catalog indexes
4. Create hazard reports folder in portal

**File:** `src/csc/whs/profiles/default/metadata.xml`

Bump version to `0.8.0`

**File:** `pyproject.toml`

Bump version to `0.8.0`

## Testing Checklist

### Functional Testing
- [ ] Anonymous user can submit hazard report
- [ ] Authenticated user can submit hazard report with LDAP lookup
- [ ] Form validation works (required fields, file size limits)
- [ ] Risk matrix calculates correct rating
- [ ] Location map works (click to place pin, reverse geocoding)
- [ ] File attachments upload successfully (up to 3 files)
- [ ] Hazard created in correct location with all metadata
- [ ] Email notification sent to WHS officer
- [ ] Hazard displays correctly in view

### Mobile Testing
- [ ] Progressive sections work on mobile (collapse/expand)
- [ ] Touch targets are 48px minimum
- [ ] Fonts are readable (16-18px)
- [ ] Map is usable on mobile
- [ ] Form submits successfully from mobile

### LDAP Testing
- [ ] User search returns LDAP users
- [ ] Selected user populates name field
- [ ] Manual entry fallback works
- [ ] Authenticated user's name pre-filled

### Workflow Testing
- [ ] Hazard starts in "submitted" state
- [ ] WHS officer can transition to "under_review"
- [ ] Transitions work correctly
- [ ] Permissions are correct at each state

## File Structure Summary

```
src/csc/whs/
├── content/
│   └── hazard.py                          # NEW - Hazard content type
├── browser/
│   ├── report_hazard.py                   # NEW - Form view
│   ├── hazard_intake.py                   # NEW - Form handler
│   ├── hazard.py                          # NEW - Display view
│   ├── templates/
│   │   ├── report_hazard.pt              # NEW - Form template
│   │   └── hazard.pt                     # NEW - Display template
│   └── static/
│       ├── hazard_form.css               # NEW - Hazard form styles
│       └── hazard_form.js                # NEW - Hazard form JavaScript
├── profiles/default/
│   ├── types/
│   │   └── csc.whs.hazard.xml            # NEW - Type definition
│   ├── workflows/
│   │   └── csc_hazard_workflow/
│   │       └── definition.xml            # NEW - Workflow definition
│   ├── types.xml                         # MODIFIED - Register hazard type
│   ├── workflows.xml                     # MODIFIED - Register hazard workflow
│   ├── catalog.xml                       # MODIFIED - Add hazard indexes
│   └── metadata.xml                      # MODIFIED - Bump to v0.8.0
├── upgrades/
│   └── v10.py                            # NEW - Upgrade to v0.8.0
├── vocabularies.py                       # MODIFIED - Add hazard vocabularies
├── interfaces.py                         # MODIFIED - Add IHazard interface
├── notifications.py                      # MODIFIED - Add hazard notifications
├── configure.zcml                        # MODIFIED - Register hazard views
└── pyproject.toml                        # MODIFIED - Bump to v0.8.0
```

## Implementation Order

1. ✅ Create implementation plan document
2. ⏳ Create content type (`content/hazard.py`)
3. ⏳ Add vocabularies (`vocabularies.py`)
4. ⏳ Create form view and template (`browser/report_hazard.py`, `templates/report_hazard.pt`)
5. ⏳ Create intake handler (`browser/hazard_intake.py`)
6. ⏳ Create display view and template (`browser/hazard.py`, `templates/hazard.pt`)
7. ⏳ Create static resources (`static/hazard_form.css`, `static/hazard_form.js`)
8. ⏳ Register content type (`profiles/default/types/csc.whs.hazard.xml`, `types.xml`)
9. ⏳ Create workflow (`profiles/default/workflows/csc_hazard_workflow/definition.xml`, `workflows.xml`)
10. ⏳ Add catalog indexes (`profiles/default/catalog.xml`)
11. ⏳ Update interfaces (`interfaces.py`)
12. ⏳ Register browser views (`configure.zcml`)
13. ⏳ Add notifications (`notifications.py`)
14. ⏳ Create upgrade step (`upgrades/v10.py`, update `profiles/default/upgrades.zcml`)
15. ⏳ Bump version numbers (`profiles/default/metadata.xml`, `pyproject.toml`)
16. ⏳ Test all functionality
17. ⏳ Deploy to whsportaldev

## Key Design Decisions

### Reuse from Incident Form
- LDAP user search functionality
- Interactive Leaflet.js map for location
- Progressive section UI pattern
- Mobile-first responsive design
- Cache-busting for static resources
- Form validation patterns

### Hazard-Specific Features
- Multi-select hazard categories (14 options)
- Risk matrix (5x5 grid) with calculated rating
- Suggested controls field (optional)
- Different workflow states focused on hazard control lifecycle

### User Experience
- Form URL: `@@report-hazard` (matches incident form pattern)
- Same progressive section UX as incident form
- Risk matrix with visual feedback (highlight selection, show computed rating)
- Optional risk assessment (not required to submit)
- Mobile-optimized for outdoor workforce

### Technical Considerations
- Separate content type from incidents (different lifecycle)
- Separate workflow (hazard control process vs incident investigation)
- Reuse LDAP integration from incident form
- Use same static resource registration approach
- Follow same naming conventions and code structure

## Version Management
- Current version: 0.7.7.2 (incident form improvements)
- Target version: 0.8.0 (hazard reporting system)
- Upgrade path: v10.py upgrade step

## Deployment Notes
- Deploy using `./deploy.sh csc` from project root
- Run upgrade step in Plone: Site Setup → Add-ons → csc.whs → Upgrade
- Verify hazard form accessible at: https://whsportal.cook.qld.gov.au/@@report-hazard
- Test on mobile devices (tablets used by outdoor workforce)

## Success Criteria
✅ Hazard form accessible to all users (authenticated and anonymous)
✅ All 9 form fields working correctly
✅ Risk matrix calculates rating properly
✅ LDAP user search integrated
✅ Location map functional
✅ File attachments working (up to 3 files)
✅ Email notifications sent to WHS officer
✅ Mobile-friendly (progressive sections, large touch targets)
✅ Workflow states and transitions functional
✅ Catalog searches work for hazards
✅ Upgrade step completes without errors
