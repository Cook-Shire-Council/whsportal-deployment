# Content Type Improvements Assessment

## Date: 2025-10-09

## Overview
This document assesses possible improvements to the Incident and Hazard content types in Plone to provide better editing experiences similar to the `@@report-incident` and `@@report-hazard` forms.

## Current State

### Incident Content Type (`csc.whs.incident`)
**What Works:**
- ✅ All fields defined in `IIncident` interface (77 fields total)
- ✅ Dexterity schema-driven with proper vocabulary integrations
- ✅ Catalog indexes for searching (identified_date, division, hazard_categories, etc.)
- ✅ Standard Plone behaviors (Dublin Core, versioning, locking, categorization)
- ✅ File attachments (photo_1, photo_2, photo_3) using NamedBlobFile
- ✅ Default view: `incident-view` (custom browser view)

**What's Limited:**
- ❌ **Location fields**: Manual text entry for latitude/longitude/accuracy
  - No interactive map widget
  - No GPS capture button
  - No reverse geocoding
- ❌ **LDAP username field**: Plain text field
  - No autocomplete search
  - No automatic user lookup
  - No auto-population of related fields
- ❌ **Multi-select incident types**: Standard checkbox widget
  - No custom validation messaging
  - Basic styling only
- ❌ **Date/Time fields**: Separate datetime picker
  - No date + time combination like the form
- ❌ **Progressive sections**: N/A (content type edit is single page)
  - All 77 fields on one long page
  - Can be overwhelming for mobile users

### Form vs Content Type Comparison

| Feature | `@@report-incident` Form | Content Type Edit |
|---------|-------------------------|-------------------|
| **LDAP User Search** | ✅ Autocomplete with debounce | ❌ Plain text field |
| **GPS Location** | ✅ Click button, capture coords | ❌ Manual entry only |
| **Interactive Map** | ✅ Leaflet.js, draggable marker | ❌ No map widget |
| **Reverse Geocoding** | ✅ Auto-populate address | ❌ Manual entry only |
| **Progressive Sections** | ✅ 4 collapsible sections | ❌ All fields at once |
| **Mobile Optimization** | ✅ 48px touch targets, large fonts | ⚠️ Standard Plone UI |
| **Field Auto-population** | ✅ Division from LDAP | ❌ No auto-population |
| **Custom Validation** | ✅ Real-time, custom messages | ⚠️ Standard Plone validation |

## Technical Constraints

### Dexterity Field Limitations
Plone's Dexterity content type system has these constraints:

1. **Widget Layer**: Fields use z3c.form widgets
   - Standard widgets: TextLine, Text, Choice, List, Boolean, File
   - Custom widgets must implement `z3c.form.interfaces.IWidget`
   - JavaScript integration requires widget-specific implementations

2. **No Built-in Map Widget**:
   - No standard Dexterity widget for interactive maps
   - Would require custom widget development
   - Leaflet.js integration needs custom widget class

3. **No Built-in LDAP Autocomplete Widget**:
   - No standard widget for LDAP user search
   - z3c.form has `AutocompleteWidget` but needs backend integration
   - Would require custom widget + AJAX endpoint

4. **Field Dependencies**:
   - Auto-population (e.g., division from LDAP) requires JavaScript
   - z3c.form doesn't have built-in dependency management
   - Custom JavaScript needed per field

### What's Possible with Custom Widgets

#### Option 1: Custom Map Widget (MODERATE EFFORT)
**Feasibility**: ✅ Possible
**Effort**: Medium (2-3 days)
**Approach**:
```python
from z3c.form.widget import Widget
from z3c.form.interfaces import IWidget

class MapLocationWidget(Widget):
    """Custom widget for interactive map location selection"""

    def render(self):
        # Render Leaflet.js map
        # Include hidden fields for lat/lon/accuracy
        # Include JavaScript for map interaction
        pass
```

**Benefits**:
- Interactive map in content type edit
- GPS capture button
- Reverse geocoding
- Consistent UX with form

**Challenges**:
- Need to handle widget registration in configure.zcml
- Must handle field value serialization (lat/lon/method)
- JavaScript needs to be loaded with widget
- Testing across browsers

#### Option 2: Custom LDAP Autocomplete Widget (MODERATE EFFORT)
**Feasibility**: ✅ Possible
**Effort**: Medium (2-3 days)
**Approach**:
```python
from z3c.form.browser.text import TextWidget
from z3c.form.interfaces import ITextWidget

class LDAPAutocompleteWidget(TextWidget):
    """Custom widget with LDAP user autocomplete"""

    def render(self):
        # Render text input with autocomplete
        # Include JavaScript for AJAX search
        # Handle user selection and field population
        pass
```

**Benefits**:
- LDAP search in content type edit
- Auto-population of related fields
- Consistent UX with form

**Challenges**:
- Needs AJAX endpoint (can reuse `@@search-users`)
- Must handle field dependencies (division auto-population)
- JavaScript for autocomplete behavior
- Browser compatibility

#### Option 3: Progressive Form Tabs/Fieldsets (EASY-MODERATE EFFORT)
**Feasibility**: ✅ Possible
**Effort**: Low-Medium (1-2 days)
**Approach**:
```python
from plone.autoform import directives as form
from plone.supermodel import model

class IIncident(model.Schema):
    model.fieldset(
        'incident_type',
        label=u'Incident Type and Person(s) Involved',
        fields=['occurred_at', 'injured_person_name', ...]
    )

    model.fieldset(
        'reporting_info',
        label=u'Reporting Information',
        fields=['supervisor_notified', 'reported_at', ...]
    )
```

**Benefits**:
- Organizes 77 fields into manageable sections
- Standard Plone UI pattern (tabs or accordion)
- Mobile-friendly (fewer fields visible at once)
- No custom JavaScript required

**Challenges**:
- Not as elegant as progressive sections
- Still full-page form (not collapsible sections)
- Standard Plone tab styling

#### Option 4: Risk Matrix Widget for Hazards (MODERATE EFFORT)
**Feasibility**: ✅ Possible
**Effort**: Medium (2 days)
**Approach**:
```python
class RiskMatrixWidget(Widget):
    """5x5 radio button matrix for risk assessment"""

    def render(self):
        # Render 5x5 grid of radio buttons
        # JavaScript to highlight selection
        # Calculate and display risk rating
        pass
```

**Benefits**:
- Visual risk matrix in content type edit
- Automatic risk rating calculation
- Consistent with hazard form

**Challenges**:
- Complex HTML structure (25 radio buttons)
- JavaScript for selection highlighting
- Value serialization (likelihood + consequence)

## Recommendations

### Priority 1: CRITICAL (Required for Demo)
✅ **Fix "Next" Button Scroll** - COMPLETED
- Issue: Clicking "Next" scrolls to end of section instead of beginning
- Solution: Scroll to section header after CSS transition completes
- Status: Fixed in `incident_form.js:87-99`
- Deploy: Include in next csc.whs deployment

### Priority 2: HIGH (Significant UX Improvement)
⏳ **Add Fieldsets to Content Types** - RECOMMENDED
- Organize 77 incident fields into 4 fieldsets:
  1. Incident Type and Person(s) Involved
  2. Reporting Information
  3. Incident Details
  4. Attachments
- Use Plone's standard fieldset/tab UI
- Low effort, big impact for mobile
- **Include in Hazard Implementation Plan**

### Priority 3: MEDIUM (Nice to Have)
⏸️ **Custom Map Widget** - DEFER
- Would provide map in content type edit
- Significant effort (2-3 days)
- Current workaround: Users can use form for initial submission
- **Decision**: Not worth effort at this stage
- **Rationale**: Forms are primary interface, content type edit is for WHS officer corrections only

⏸️ **Custom LDAP Autocomplete Widget** - DEFER
- Would provide LDAP search in content type edit
- Significant effort (2-3 days)
- Current workaround: Pre-populated from form submission
- **Decision**: Not worth effort at this stage
- **Rationale**: WHS officers rarely edit the person's name after initial submission

### Priority 4: LOW (Future Enhancement)
⏸️ **Risk Matrix Widget** - DEFER TO PHASE 2
- Only relevant for hazard content type
- Can be implemented after basic hazard form is working
- **Decision**: Implement fieldsets first, custom widget later if needed

## Integration into Hazard Implementation Plan

### Changes to Hazard Plan

#### Add to Phase 1 (Content Type Definition)
```python
# src/csc/whs/content/hazard.py (UPDATED)

from plone.autoform import directives as form
from plone.supermodel import model

class IHazard(model.Schema):
    """Hazard Report schema with fieldsets"""

    # Fieldset 1: Hazard Identification
    model.fieldset(
        'identification',
        label=u'Hazard Identification',
        fields=['identified_date', 'identified_by_name', 'identified_by_username',
                'reported_by_name', 'reported_by_email']
    )

    # Fieldset 2: Location & Division
    model.fieldset(
        'location_division',
        label=u'Location & Division',
        fields=['location', 'location_latitude', 'location_longitude',
                'location_accuracy', 'location_method', 'division']
    )

    # Fieldset 3: Hazard Details
    model.fieldset(
        'details',
        label=u'Hazard Details',
        fields=['hazard_categories', 'hazard_description']
    )

    # Fieldset 4: Risk Assessment & Controls
    model.fieldset(
        'risk_controls',
        label=u'Risk Assessment & Controls',
        fields=['suggested_controls', 'risk_likelihood', 'risk_consequence',
                'risk_rating', 'photo_1', 'photo_2', 'photo_3']
    )

    # Field definitions...
```

#### Add to Incident Content Type (Optional Improvement)
```python
# src/csc/whs/interfaces.py (FUTURE UPDATE)

# Add fieldsets to IIncident to match form sections
model.fieldset(
    'incident_type_persons',
    label=u'Section 1: Incident Type and Person(s) Involved',
    fields=['occurred_at', 'injured_person_name', 'injured_person_username',
            'person_relationship', 'division', 'location', 'location_latitude',
            'location_longitude', 'location_accuracy', 'location_method',
            'incident_types']
)

model.fieldset(
    'reporting_information',
    label=u'Section 2: Reporting Information',
    fields=['supervisor_notified', 'reported_at', 'reported_by_name',
            'reported_by_email', 'witnesses']
)

model.fieldset(
    'incident_details',
    label=u'Section 3: Incident Details',
    fields=['immediate_actions', 'persons_involved', 'injury_type',
            'treatment', 'body_part', 'equipment_plant', 'property_damage']
)

model.fieldset(
    'attachments',
    label=u'Section 4: Attachments',
    fields=['photo_1', 'photo_2', 'photo_3']
)
```

## Implementation Steps for "Next" Button Fix

### Step 1: Test Fix Locally ✅
- Modified `incident_form.js` expandSection() function
- Changed timeout from 100ms to 350ms (wait for CSS transition)
- Scroll to section header instead of section

### Step 2: Deploy to whsportaldev
```bash
cd /home/ceo/Development/WHSPortal/csc
./deploy.sh csc
```

### Step 3: Test on Production
- Navigate to: https://whsportal.cook.qld.gov.au/@@report-incident
- Test progressive sections:
  1. Fill in Section 1 fields
  2. Click "Next Section →"
  3. Verify it scrolls to **beginning** of Section 2 (header visible)
  4. Repeat for Sections 3 and 4

### Step 4: Copy Fix to Hazard Form
When implementing hazard form:
- Copy fixed `expandSection()` function to `hazard_form.js`
- Use same timing (350ms) for consistency
- Test on hazard form as well

## Summary

### What We're Fixing Now
✅ **"Next" Button Scroll Issue** - Fixed and ready to deploy

### What We're Adding to Hazard Plan
✅ **Fieldsets for Content Type** - Organize fields into 4 sections using Plone's standard tab/fieldset UI

### What We're NOT Doing (and Why)
❌ **Custom Map Widget** - Too much effort, forms are primary interface
❌ **Custom LDAP Widget** - Too much effort, auto-populated from form
❌ **Progressive Sections in Content Type** - Standard fieldsets are sufficient

### Key Insight
The `@@report-incident` and `@@report-hazard` forms are the **primary user interfaces** for incident/hazard submission. The content type edit screens are **secondary interfaces** used mainly by WHS officers for:
- Corrections/updates after initial submission
- Adding investigation details (root cause, corrective actions)
- Changing workflow states
- Adding classifications (severity ratings)

Therefore, it makes sense to invest heavily in the form UX (which we've done) and keep the content type edit functional but standard (using Plone's built-in fieldsets).

## Next Actions

1. ✅ Deploy "Next" button fix immediately (required for demo)
2. ✅ Update hazard implementation plan with fieldset approach
3. ✅ Test "Next" button fix on production after deployment
4. ⏸️ Defer custom widget development until there's demonstrated need from WHS officers

## References

- **Plone Dexterity Documentation**: https://docs.plone.org/develop/plone/content/dexterity.html
- **z3c.form Widgets**: https://z3cform.readthedocs.io/
- **Plone Autoform Fieldsets**: https://pypi.org/project/plone.autoform/
- **Custom Widget Example**: https://docs.plone.org/develop/addons/schema-driven-forms/customising-form-behaviour/widgets.html
