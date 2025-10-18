# Phase B Implementation Plan: Form Enhancements (Consolidated)

**Version:** csc.whs v0.10.18 → v0.10.19
**Profile Version:** 18 → 19
**Status:** 📋 Ready to Implement
**Priority:** Medium
**Estimated Effort:** 12-14 hours (AI-assisted, consolidated)

---

## Overview

Consolidated implementation of WHS Officer Requests #2, #3, #4, and #5. These changes are being implemented together to:
- Avoid multiple question renumbering passes (efficiency gain)
- Single testing and deployment cycle
- Cohesive "Form Enhancement" release
- Reduce template file modifications from 4 separate changes to 1 comprehensive update

### Included Requests

| # | Request | Key Changes |
|---|---------|-------------|
| #2 | Section 3 Enhancements | Auto-generate title, make description and immediate_actions required |
| #3 | Number Section 3 Questions | Add Q13-Q15 numbering for consistency |
| #4 | Move Emergency Services to Section 3 | Convert boolean to choice, add multi-select, Q16-Q17 |
| #5 | Add Plant Number Field | New optional field Q27 in Section 5 |

### Efficiency Gains from Consolidation

**Time Savings:**
- Separate implementation: 17.25-19.75 hours
- Consolidated implementation: 12-14 hours
- **Savings: 30-35%** (5-6 hours saved)

**Why faster together:**
1. ✅ Templates opened once, not 4 times
2. ✅ Question renumbering done once (Q13-Q30), not 3 separate passes
3. ✅ Single vocabulary creation session
4. ✅ Single upgrade step for all migrations
5. ✅ One testing/deployment cycle
6. ✅ Single documentation update

---

## Question Renumbering Summary

### Before (Current State)
Assuming Request #1 (Division→Department) is already implemented:
- Section 3: No question numbers (Title, Description, Immediate Actions)
- Section 4: Q16-Q23 (Injury Details)
- Section 5: Q24-Q26 (Property Damage)
- Section 6: Q27-Q28 (Preliminary Observations)

### After (This Implementation)
- **Section 3: Q13-Q17** (Incident Details + Emergency Services)
  - Q13: Brief Title / Summary (auto-generated)
  - Q14: What happened (required)
  - Q15: Immediate Actions Taken (required)
  - Q16: Were emergency services called? (Yes/No, required) ← **NEW/MOVED**
  - Q17: Which emergency services attended? (multi-select, conditional) ← **NEW**

- **Section 4: Q18-Q24** (Injury Details)
  - Q18: Body areas affected (was Q16, +2)
  - Q19: Injury classifications (was Q17, +2)
  - Q20: First aid given (was Q18, +2)
  - Q21: First aid provider (was Q19, +2)
  - Q22: First aid description (was Q20, +2)
  - Q23: Medical treatment sought (was Q21, +2)
  - Q24: Medical treatment location (was Q23, +2)

- **Section 5: Q25-Q28** (Property Damage)
  - Q25: Property damage types (was Q24, +1)
  - Q26: Property damage detail (was Q25, +1)
  - Q27: Plant number ← **NEW**
  - Q28: Vehicle damage report completed (was Q26, +2)

- **Section 6: Q29-Q30** (Preliminary Observations)
  - Q29: Contributing factors (was Q27, +2)
  - Q30: Preventative actions (was Q28, +2)

**Total question shift:** +2 from Section 4 onwards (due to Q16-Q17 insertion in Section 3)

---

## Implementation Phases

### ✅ Super-Phase 1: Foundation - Schema & Vocabularies (2 hours)

**Goal:** Create all new fields and vocabularies in one consolidated session.

#### 1.1 Create Emergency Services Vocabulary

**File:** `csc/src/csc/whs/vocabularies.py`

**Add new vocabulary function:**

```python
@provider(IVocabularyFactory)
def emergency_services_vocabulary(context):
    """Emergency services types that can attend an incident

    Used for multi-select field when emergency services are called.
    Queensland emergency services.
    """
    terms = [
        SimpleTerm(value='police', title='Police (QPS - Queensland Police Service)'),
        SimpleTerm(value='fire', title='Fire and Emergency Services (QFES)'),
        SimpleTerm(value='ambulance', title='Ambulance (QAS - Queensland Ambulance Service)'),
        SimpleTerm(value='ses', title='SES (State Emergency Service)'),
        SimpleTerm(value='other', title='Other emergency service'),
    ]
    return SimpleVocabulary(terms)
```

**Register in configure.zcml:**

**File:** `csc/src/csc/whs/configure.zcml`

```xml
<!-- Emergency Services Vocabulary -->
<utility
    component=".vocabularies.emergency_services_vocabulary"
    name="csc.whs.EmergencyServicesVocabulary"
    />
```

#### 1.2 Update IIncident Schema - All Changes Together

**File:** `csc/src/csc/whs/interfaces.py`

**Section 3: Incident Details (Q13-Q17)**

```python
# ========================================
# SECTION 3: INCIDENT DETAILS
# ========================================
# Q13: Brief Title / Summary - provided by Dublin Core title field (auto-generated)
# Q14: What happened - provided by Dublin Core description field (now REQUIRED)
# Q15: Immediate Actions Taken (now REQUIRED)

# Add new field for title generation
location_town = schema.TextLine(
    title=u"Town/Suburb",
    required=False,
    description=u"Town or suburb where incident occurred (e.g., Cooktown, Lakeland). Used to generate incident title.",
)

# Q15: Immediate Actions Taken (CHANGE: now required)
immediate_actions = schema.Text(
    title=u"Q15: Immediate Actions Taken",
    required=True,  # Changed from False
    description=u"What actions were taken immediately after the incident? (Required)",
)

# Q16: Were emergency services called to the scene? (MOVED from Section 4, CHANGED from Boolean to Choice)
emergency_services_called = schema.Choice(
    title=u"Q16: Were emergency services called to the scene?",
    required=True,  # Changed from False, now mandatory
    vocabulary="csc.whs.YesNoVocabulary",
    description=u"This does not include First Aid provided by First Aiders.",
)

# Q17: Which emergency services attended? (NEW FIELD)
emergency_services_types = schema.List(
    title=u"Q17: Which emergency services attended?",
    required=False,  # Conditionally required via JavaScript
    description=u"Select all emergency services that were called to the scene (required if emergency services were called)",
    value_type=schema.Choice(
        vocabulary="csc.whs.EmergencyServicesVocabulary"
    ),
)
```

**Section 4: Injury Details - Renumber Q16→Q18 through Q23→Q24**

```python
# ========================================
# SECTION 4: INJURY DETAILS (CONDITIONAL)
# ========================================

# Q18: Body areas affected (was Q16)
injury_body_areas = schema.List(
    title=u"Q18: What body areas were affected?",  # Updated question number
    required=False,
    description=u"Select all body areas that were injured",
    value_type=schema.Choice(
        vocabulary="csc.whs.BodyAreaVocabulary"
    ),
)

# Q19: Injury classifications (was Q17)
injury_classifications = schema.List(
    title=u"Q19: What was the nature of the injury?",  # Updated question number
    required=False,
    description=u"Select all injury types that apply",
    value_type=schema.Choice(
        vocabulary="csc.whs.InjuryTypeVocabulary"
    ),
)

# Q20: First aid given (was Q18)
first_aid_given = schema.Bool(
    title=u"Q20: Was first aid provided?",  # Updated question number
    required=False,
    default=False,
)

# Q21: First aid provider (was Q19)
first_aid_provider = schema.TextLine(
    title=u"Q21: Who provided first aid?",  # Updated question number
    required=False,
    description=u"Name of the first aider",
)

# Q22: First aid description (was Q20)
first_aid_description = schema.Text(
    title=u"Q22: Describe the first aid provided",  # Updated question number
    required=False,
    description=u"What first aid treatment was given?",
)

# Q23: Medical treatment sought (was Q21)
medical_treatment_sought = schema.Bool(
    title=u"Q23: Was medical treatment sought/provided beyond first aid?",  # Updated question number
    required=False,
    default=False,
    description=u"This does not include First Aid provided by First Aiders.",
)

# NOTE: Remove old Q22 emergency_services_called (Boolean) - now in Section 3 as Choice

# Q24: Medical treatment location (was Q23)
medical_treatment_location = schema.Text(
    title=u"Q24: If medical treatment was sought/provided, who provided it / where were they taken?",  # Updated question number
    required=False,
    description=u"This does not include First Aid provided by First Aiders.",
)
```

**Section 5: Property Damage - Add plant_number field, renumber Q26→Q28**

```python
# ========================================
# SECTION 5: PROPERTY & PLANT DAMAGE
# ========================================

# Q25: Type of property damaged (was Q24)
property_damage_types = schema.List(
    title=u"Q25: Type of property damaged",  # Updated question number
    required=False,
    description=u"If the incident included property damage, select all types that apply. If not, move to the next section.",
    value_type=schema.Choice(
        vocabulary="csc.whs.PropertyDamageTypeVocabulary"
    ),
)

# Q26: Further detail of property damaged (was Q25)
property_damage_detail = schema.Text(
    title=u"Q26: Further detail of property damaged",  # Updated question number
    required=False,
    description=u"e.g. type of plant, structure and detail of damage received. Include make and model of vehicle / plant if known",
)

# Q27: Plant number (NEW FIELD)
plant_number = schema.TextLine(
    title=u"Q27: Enter the plant number if one assigned",
    required=False,
    description=u"Council asset/plant number (if applicable). This helps identify the specific vehicle or equipment involved.",
)

# Q28: Vehicle damage report completed (was Q26)
vehicle_damage_report_completed = schema.Choice(
    title=u"Q28: If you have damaged a Council vehicle / plant, or been involved in damage of other vehicle / plant, have you completed a Plant / Vehicle Damage Report?",  # Updated question number
    required=False,
    description=u"A Plant / Vehicle Damage Report must be completed in this circumstance, and sent to the Insurance Claims Officer / Manager Fleet & Workshop",
    vocabulary="csc.whs.YesNoVocabulary",
)
```

**Section 6: Preliminary Observations - Renumber Q27→Q29, Q28→Q30**

```python
# ========================================
# SECTION 6: PRELIMINARY OBSERVATIONS
# ========================================

# Q29: Contributing factors (was Q27)
contributing_factors_identified = schema.Text(
    title=u"Q29: Preliminary identification of factors that contributed to the incident",  # Updated question number
    required=False,
    description=u"What do you think caused or contributed to this incident?",
)

# Q30: Preventative actions (was Q28)
preventative_actions_suggested = schema.Text(
    title=u"Q30: Suggestion of any actions to be taken to prevent recurrence",  # Updated question number
    required=False,
    description=u"What could be done to prevent this from happening again?",
)
```

**Dublin Core Description Override (make required)**

**Challenge:** Dexterity inherits Dublin Core `description` field as optional.

**Solution:** Use form widget customization in templates to enforce required validation (client-side and server-side).

#### 1.3 Create Title Generation Utility Functions

**File:** `csc/src/csc/whs/utilities.py` (append to existing file)

```python
def generate_incident_title(incident_types, department, location_town):
    """Generate incident title from key fields

    Pattern: <Incident Type> - <Department> - <Location Town>

    Args:
        incident_types (list): List of incident type tokens (e.g., ['minor-injury', 'near-miss'])
        department (str): Department token (e.g., 'ict')
        location_town (str): Town/suburb name (e.g., 'Cooktown')

    Returns:
        str: Generated title (e.g., "Minor Injury - ICT - Cooktown")

    Examples:
        >>> generate_incident_title(['minor-injury'], 'ict', 'Cooktown')
        "Minor Injury - ICT - Cooktown"

        >>> generate_incident_title(['minor-injury', 'near-miss'], 'water-wastewater', 'Lakeland')
        "Minor Injury - Water & Wastewater - Lakeland"
    """
    from zope.component import getUtility
    from zope.schema.interfaces import IVocabularyFactory

    # Get first incident type or "Multiple Types"
    incident_type_display = ""
    if incident_types and len(incident_types) > 0:
        try:
            vocab_factory = getUtility(IVocabularyFactory, 'csc.whs.IncidentTypeVocabulary')
            vocab = vocab_factory(None)
            term = vocab.getTerm(incident_types[0])
            incident_type_display = term.title
        except:
            incident_type_display = "Incident"
    else:
        incident_type_display = "Incident"

    # Get department display name
    department_display = ""
    if department:
        try:
            vocab_factory = getUtility(IVocabularyFactory, 'csc.whs.DepartmentVocabulary')
            vocab = vocab_factory(None)
            term = vocab.getTerm(department)
            department_display = term.title
        except:
            department_display = department

    # Get location town (already display text)
    location_display = location_town if location_town else "Unknown Location"

    # Construct title
    title = f"{incident_type_display} - {department_display} - {location_display}"

    return title


def get_vocabulary_display_name(vocabulary_name, token):
    """Get display name from vocabulary token

    Args:
        vocabulary_name (str): Name of vocabulary (e.g., 'csc.whs.DepartmentVocabulary')
        token (str): Token value (e.g., 'ict')

    Returns:
        str: Display name (e.g., 'Information & Communications Technology')
    """
    from zope.component import getUtility
    from zope.schema.interfaces import IVocabularyFactory

    if not token:
        return ''

    try:
        vocab_factory = getUtility(IVocabularyFactory, vocabulary_name)
        vocab = vocab_factory(None)
        term = vocab.getTerm(token)
        return term.title
    except:
        return token  # Fallback to token if lookup fails
```

#### 1.4 Testing Checklist - Phase 1

- [ ] Emergency services vocabulary loads successfully
- [ ] Returns 5 service types (Police, Fire, Ambulance, SES, Other)
- [ ] Vocabulary registered in configure.zcml
- [ ] Schema validates without errors
- [ ] All new fields defined correctly
- [ ] Question numbering updated consistently (Q13-Q30)
- [ ] Title generation utility function works
- [ ] Vocabulary display name helper function works

---

### ✅ Super-Phase 2: Templates - All Forms Updated Together (3-4 hours)

**Goal:** Update all form templates in one consolidated session. Each template opened once with all changes applied together.

#### 2.1 Update Authenticated Incident Form

**File:** `csc/src/csc/whs/browser/templates/report_incident.pt`

**Section 3: Incident Details - Apply ALL changes**

```html
<!-- ============================================ -->
<!-- SECTION 3: INCIDENT DETAILS                 -->
<!-- ============================================ -->
<div class="form-section" id="section-3">
    <h2 class="section-header">Section 3: Incident Details</h2>

    <!-- Q13: Brief Title / Summary (auto-generated, but allow override) -->
    <div class="field">
        <label for="form-widgets-IDublinCore-title">
            <strong>Q13:</strong> Brief Title / Summary
        </label>
        <input type="text"
               id="form-widgets-IDublinCore-title"
               name="title"
               placeholder="Auto-generated from incident details"
               tal:attributes="value context/title | nothing">
        <p class="field-description">
            Title will auto-generate when you complete the form, but you can edit it if needed.
        </p>
    </div>

    <!-- Location Town field (for title generation) -->
    <div class="field">
        <label for="form-widgets-location_town">
            Town/Suburb
        </label>
        <input type="text"
               id="form-widgets-location_town"
               name="location_town"
               placeholder="e.g., Cooktown, Lakeland, Laura"
               maxlength="100"
               tal:attributes="value context/location_town | nothing">
        <p class="field-description">
            Town or suburb where incident occurred. Used to generate incident title.
        </p>
    </div>

    <!-- Q14: What happened (REQUIRED) -->
    <div class="field">
        <label for="form-widgets-IDublinCore-description">
            <strong>Q14:</strong> What happened <span class="required">*</span>
        </label>
        <textarea id="form-widgets-IDublinCore-description"
                  name="description"
                  required
                  rows="6"
                  placeholder="Describe what happened in detail..."
                  tal:content="context/description | nothing"></textarea>
        <p class="field-description">
            Provide a detailed description of the incident. This field is required.
        </p>
    </div>

    <!-- Q15: Immediate Actions Taken (REQUIRED) -->
    <div class="field">
        <label for="form-widgets-immediate_actions">
            <strong>Q15:</strong> Immediate Actions Taken <span class="required">*</span>
        </label>
        <textarea id="form-widgets-immediate_actions"
                  name="immediate_actions"
                  required
                  rows="6"
                  placeholder="What actions were taken immediately after the incident?"
                  tal:content="context/immediate_actions | nothing"></textarea>
        <p class="field-description">
            What actions were taken immediately after the incident? This field is required.
        </p>
    </div>

    <!-- Q16: Were emergency services called? (MOVED from Section 4, CHANGED to Choice) -->
    <div class="field">
        <label for="form-widgets-emergency_services_called">
            <strong>Q16:</strong> Were emergency services called to the scene? <span class="required">*</span>
        </label>
        <select id="form-widgets-emergency_services_called"
                name="emergency_services_called"
                required>
            <option value="">-- Select --</option>
            <option value="yes" tal:attributes="selected python:context.emergency_services_called=='yes'">Yes</option>
            <option value="no" tal:attributes="selected python:context.emergency_services_called=='no'">No</option>
        </select>
        <p class="field-description">
            This does not include First Aid provided by First Aiders.
        </p>
    </div>

    <!-- Q17: Which emergency services attended? (NEW, conditional on Q16=Yes) -->
    <div class="field" id="emergency-services-types-container" style="display: none;">
        <label>
            <strong>Q17:</strong> Which emergency services attended? <span class="required">*</span>
        </label>
        <p class="field-description">
            Select all emergency services that were called to the scene.
        </p>
        <div class="checkbox-group">
            <label>
                <input type="checkbox"
                       name="emergency_services_types"
                       value="police"
                       tal:attributes="checked python:'police' in (context.emergency_services_types or [])">
                Police (QPS - Queensland Police Service)
            </label>
            <label>
                <input type="checkbox"
                       name="emergency_services_types"
                       value="fire"
                       tal:attributes="checked python:'fire' in (context.emergency_services_types or [])">
                Fire and Emergency Services (QFES)
            </label>
            <label>
                <input type="checkbox"
                       name="emergency_services_types"
                       value="ambulance"
                       tal:attributes="checked python:'ambulance' in (context.emergency_services_types or [])">
                Ambulance (QAS - Queensland Ambulance Service)
            </label>
            <label>
                <input type="checkbox"
                       name="emergency_services_types"
                       value="ses"
                       tal:attributes="checked python:'ses' in (context.emergency_services_types or [])">
                SES (State Emergency Service)
            </label>
            <label>
                <input type="checkbox"
                       name="emergency_services_types"
                       value="other"
                       tal:attributes="checked python:'other' in (context.emergency_services_types or [])">
                Other emergency service
            </label>
        </div>
    </div>
</div>
```

**Section 4: Injury Details - Renumber ALL questions Q16→Q18 through Q23→Q24**

```html
<!-- ============================================ -->
<!-- SECTION 4: INJURY DETAILS (CONDITIONAL)     -->
<!-- ============================================ -->
<div class="form-section" id="section-4">
    <h2 class="section-header">Section 4: Injury Details</h2>
    <p class="section-description">
        Complete this section if the incident involved an injury. If no injury occurred, skip to Section 5.
    </p>

    <!-- Q18: Body areas affected (was Q16) -->
    <div class="field">
        <label for="form-widgets-injury_body_areas">
            <strong>Q18:</strong> What body areas were affected?
        </label>
        <!-- Body area checkboxes here, update question number -->
    </div>

    <!-- Q19: Injury classifications (was Q17) -->
    <div class="field">
        <label for="form-widgets-injury_classifications">
            <strong>Q19:</strong> What was the nature of the injury?
        </label>
        <!-- Injury type checkboxes here, update question number -->
    </div>

    <!-- Q20: First aid given (was Q18) -->
    <div class="field">
        <label for="form-widgets-first_aid_given">
            <strong>Q20:</strong> Was first aid provided?
        </label>
        <!-- Boolean field here, update question number -->
    </div>

    <!-- Q21: First aid provider (was Q19) -->
    <div class="field">
        <label for="form-widgets-first_aid_provider">
            <strong>Q21:</strong> Who provided first aid?
        </label>
        <!-- Text field here, update question number -->
    </div>

    <!-- Q22: First aid description (was Q20) -->
    <div class="field">
        <label for="form-widgets-first_aid_description">
            <strong>Q22:</strong> Describe the first aid provided
        </label>
        <!-- Textarea here, update question number -->
    </div>

    <!-- Q23: Medical treatment sought (was Q21) -->
    <div class="field">
        <label for="form-widgets-medical_treatment_sought">
            <strong>Q23:</strong> Was medical treatment sought/provided beyond first aid?
        </label>
        <!-- Boolean field here, update question number -->
    </div>

    <!-- REMOVE old Q22 (emergency services called Boolean) - now in Section 3 -->

    <!-- Q24: Medical treatment location (was Q23) -->
    <div class="field">
        <label for="form-widgets-medical_treatment_location">
            <strong>Q24:</strong> If medical treatment was sought/provided, who provided it / where were they taken?
        </label>
        <!-- Textarea here, update question number -->
    </div>
</div>
```

**Section 5: Property Damage - Add Q27 plant_number, renumber Q26→Q28**

```html
<!-- ============================================ -->
<!-- SECTION 5: PROPERTY & PLANT DAMAGE          -->
<!-- ============================================ -->
<div class="form-section" id="section-5">
    <h2 class="section-header">Section 5: Property & Plant Damage</h2>
    <p class="section-description">
        Complete this section if the incident involved property or plant damage. If not, skip to Section 6.
    </p>

    <!-- Q25: Property damage types (was Q24) -->
    <div class="field">
        <label>
            <strong>Q25:</strong> Type of property damaged
        </label>
        <!-- Checkboxes here, update question number -->
    </div>

    <!-- Q26: Property damage detail (was Q25) -->
    <div class="field">
        <label for="form-widgets-property_damage_detail">
            <strong>Q26:</strong> Further detail of property damaged
        </label>
        <textarea id="form-widgets-property_damage_detail"
                  name="property_damage_detail"
                  rows="4"
                  placeholder="e.g. type of plant, structure and detail of damage received. Include make and model of vehicle / plant if known"
                  tal:content="context/property_damage_detail | nothing"></textarea>
    </div>

    <!-- Q27: Plant number (NEW FIELD) -->
    <div class="field">
        <label for="form-widgets-plant_number">
            <strong>Q27:</strong> Enter the plant number if one assigned
        </label>
        <input type="text"
               id="form-widgets-plant_number"
               name="plant_number"
               placeholder="e.g., P123, VEH-456"
               maxlength="50"
               tal:attributes="value context/plant_number | nothing">
        <p class="field-description">
            Council asset/plant number (if applicable). This helps identify the specific vehicle or equipment involved.
        </p>
    </div>

    <!-- Q28: Vehicle damage report completed (was Q26) -->
    <div class="field">
        <label for="form-widgets-vehicle_damage_report_completed">
            <strong>Q28:</strong> If you have damaged a Council vehicle / plant, or been involved in damage of other vehicle / plant, have you completed a Plant / Vehicle Damage Report?
        </label>
        <select id="form-widgets-vehicle_damage_report_completed"
                name="vehicle_damage_report_completed">
            <option value="">-- Select --</option>
            <option value="yes" tal:attributes="selected python:context.vehicle_damage_report_completed=='yes'">Yes</option>
            <option value="no" tal:attributes="selected python:context.vehicle_damage_report_completed=='no'">No</option>
        </select>
        <p class="field-description">
            A Plant / Vehicle Damage Report must be completed in this circumstance, and sent to the Insurance Claims Officer / Manager Fleet & Workshop.
        </p>
    </div>
</div>
```

**Section 6: Preliminary Observations - Renumber Q27→Q29, Q28→Q30**

```html
<!-- ============================================ -->
<!-- SECTION 6: PRELIMINARY OBSERVATIONS         -->
<!-- ============================================ -->
<div class="form-section" id="section-6">
    <h2 class="section-header">Section 6: Preliminary Observations</h2>

    <!-- Q29: Contributing factors (was Q27) -->
    <div class="field">
        <label for="form-widgets-contributing_factors_identified">
            <strong>Q29:</strong> Preliminary identification of factors that contributed to the incident
        </label>
        <!-- Textarea here, update question number -->
    </div>

    <!-- Q30: Preventative actions (was Q28) -->
    <div class="field">
        <label for="form-widgets-preventative_actions_suggested">
            <strong>Q30:</strong> Suggestion of any actions to be taken to prevent recurrence
        </label>
        <!-- Textarea here, update question number -->
    </div>
</div>
```

**Notes:**
- All question numbers updated in one pass (Q13-Q30)
- All new fields added
- Section 3 completely restructured
- Emergency services moved from Section 4 to Section 3

#### 2.2 Update Anonymous Form

**File:** `csc/src/csc/whs/browser/templates/anonymous_form.pt`

**Apply same changes as authenticated form above:**
- Section 3: Q13-Q17 (numbering, new fields, emergency services)
- Section 4: Q18-Q24 (renumbering)
- Section 5: Q25-Q28 (plant number added)
- Section 6: Q29-Q30 (renumbering)

**Note:** No LDAP auto-population in anonymous form, so no JavaScript hooks needed for that feature.

#### 2.3 Testing Checklist - Phase 2

- [ ] Authenticated incident form displays all new fields
- [ ] Anonymous incident form displays all new fields
- [ ] Question numbers correct (Q13-Q30)
- [ ] Q16 (emergency services) displays as Yes/No dropdown
- [ ] Q17 (emergency services types) hidden by default
- [ ] Required fields marked with asterisk (*)
- [ ] Field descriptions display correctly
- [ ] Plant number field (Q27) displays in Section 5

---

### ✅ Super-Phase 3: Business Logic - All Processing Updates (3-4 hours)

**Goal:** Update all backend intake processing, validation, and storage logic for all new fields.

#### 3.1 Update Authenticated Incident Intake

**File:** `csc/src/csc/whs/browser/intake.py`

**Extract all new fields:**

```python
from csc.whs.utilities import generate_incident_title, get_vocabulary_display_name

def process_incident_form(request):
    """Process incident form submission"""
    form = request.form

    # Existing field extraction...

    # NEW FIELDS - Extract all together
    location_town = form.get('location_town', '').strip()
    description = form.get('description', '').strip()
    immediate_actions = form.get('immediate_actions', '').strip()
    emergency_services_called = form.get('emergency_services_called', '')
    emergency_services_types = form.getlist('emergency_services_types', [])
    plant_number = form.get('plant_number', '').strip()

    # VALIDATION - All new required fields
    errors = []

    # Request #2: Description required
    if not description:
        errors.append("Q14: Description (What happened) is required")

    # Request #2: Immediate actions required
    if not immediate_actions:
        errors.append("Q15: Immediate actions is required")

    # Request #4: Emergency services called required
    if not emergency_services_called:
        errors.append("Q16: Emergency services called is required")

    # Request #4: Emergency services types conditionally required
    if emergency_services_called == 'yes':
        if not emergency_services_types or len(emergency_services_types) == 0:
            errors.append("Q17: Please select at least one emergency service type")

    if errors:
        return error_response(errors)

    # CREATE INCIDENT
    incident = create_incident_object()

    # Store all fields
    incident.location_town = location_town
    incident.description = description
    incident.immediate_actions = immediate_actions
    incident.emergency_services_called = emergency_services_called
    incident.emergency_services_types = emergency_services_types if emergency_services_called == 'yes' else []
    incident.plant_number = plant_number

    # Request #2: Auto-generate title if empty
    title = form.get('title', '').strip()
    if not title:
        # Get other required fields for title generation
        incident_types = form.getlist('incident_types', [])
        department = form.get('department', '')

        title = generate_incident_title(
            incident_types=incident_types,
            department=department,
            location_town=location_town or "Unknown Location"
        )

        logger.info(f"Auto-generated title: {title}")

    incident.title = title
    incident.setTitle(title)

    # ... rest of processing
```

#### 3.2 Update Anonymous Form Processing

**File:** `csc/src/csc/whs/browser/anonymous.py`

**Apply same changes as authenticated intake:**
- Extract new fields (location_town, emergency_services_called, emergency_services_types, plant_number)
- Validate description required
- Validate immediate_actions required
- Validate emergency services called required
- Validate conditional emergency services types
- Generate title if empty
- Store all fields

#### 3.3 Update Email Notifications

**File:** `csc/src/csc/whs/notifications.py`

**Add new fields to email body:**

```python
def format_incident_email(incident):
    """Format incident notification email"""
    from csc.whs.utilities import get_vocabulary_display_name

    body = "=== NEW INCIDENT REPORT ===\n\n"

    # ... existing fields ...

    # SECTION 3: INCIDENT DETAILS
    body += "\n--- SECTION 3: INCIDENT DETAILS ---\n"
    if incident.description:
        body += f"What happened: {incident.description}\n"
    if incident.immediate_actions:
        body += f"Immediate actions: {incident.immediate_actions}\n"
    if incident.location_town:
        body += f"Location (town): {incident.location_town}\n"

    # Request #4: Emergency services
    if incident.emergency_services_called:
        body += f"Emergency services called: {incident.emergency_services_called}\n"
        if incident.emergency_services_called == 'yes' and incident.emergency_services_types:
            services = [get_vocabulary_display_name('csc.whs.EmergencyServicesVocabulary', s)
                       for s in incident.emergency_services_types]
            body += f"  Services attended: {', '.join(services)}\n"

    # ... existing Section 4 fields (renumbered Q18-Q24) ...

    # SECTION 5: PROPERTY DAMAGE
    if incident.property_damage_types or incident.property_damage_detail or incident.plant_number:
        body += "\n--- SECTION 5: PROPERTY DAMAGE ---\n"
        if incident.property_damage_types:
            body += f"Property damage types: {', '.join(incident.property_damage_types)}\n"
        if incident.property_damage_detail:
            body += f"Damage detail: {incident.property_damage_detail}\n"
        # Request #5: Plant number
        if incident.plant_number:
            body += f"Plant number: {incident.plant_number}\n"
        if incident.vehicle_damage_report_completed:
            body += f"Damage report completed: {incident.vehicle_damage_report_completed}\n"

    # ... rest of email ...

    return body
```

#### 3.4 Testing Checklist - Phase 3

- [ ] New field extraction works correctly
- [ ] Description validation prevents empty submissions
- [ ] Immediate actions validation prevents empty submissions
- [ ] Emergency services called validation prevents empty selection
- [ ] Emergency services types conditional validation works
- [ ] Title auto-generation creates correct format
- [ ] User can override auto-generated title
- [ ] Plant number stores correctly
- [ ] Email includes all new fields
- [ ] Email formats emergency services list correctly

---

### ✅ Super-Phase 4: View Templates - Display Updates (2 hours)

**Goal:** Update incident view template to display all new fields in correct sections.

#### 4.1 Update Incident View Template

**File:** `csc/src/csc/whs/browser/templates/incident.pt`

**Section 3: Incident Details - Display new fields**

```html
<!-- ============================================ -->
<!-- SECTION 3: INCIDENT DETAILS                 -->
<!-- ============================================ -->
<div class="section" id="section-3">
    <h3 class="section-header">Section 3: Incident Details</h3>

    <!-- Q13: Title -->
    <div class="field">
        <strong>Q13: Brief Title / Summary:</strong>
        <p tal:content="context/title">Incident title</p>
    </div>

    <!-- Location Town (if provided) -->
    <div class="field" tal:condition="context/location_town">
        <strong>Town/Suburb:</strong>
        <span tal:content="context/location_town">Cooktown</span>
    </div>

    <!-- Q14: What happened -->
    <div class="field" tal:condition="context/description">
        <strong>Q14: What happened:</strong>
        <p tal:content="structure python:context.description.replace('\n', '<br/>')">
            Description text
        </p>
    </div>

    <!-- Q15: Immediate actions -->
    <div class="field" tal:condition="context/immediate_actions">
        <strong>Q15: Immediate Actions Taken:</strong>
        <p tal:content="structure python:context.immediate_actions.replace('\n', '<br/>')">
            Immediate actions text
        </p>
    </div>

    <!-- Q16: Emergency services called -->
    <div class="field" tal:condition="context/emergency_services_called">
        <strong>Q16: Were emergency services called to the scene?</strong>
        <span tal:content="context/emergency_services_called">Yes</span>
    </div>

    <!-- Q17: Emergency services types (if called) -->
    <div class="field" tal:condition="python: context.emergency_services_called == 'yes' and context.emergency_services_types">
        <strong>Q17: Emergency services that attended:</strong>
        <ul>
            <li tal:repeat="service context/emergency_services_types"
                tal:content="python: view.get_vocabulary_display_name('csc.whs.EmergencyServicesVocabulary', service)">
                Police
            </li>
        </ul>
    </div>
</div>
```

**Section 4: Injury Details - Renumber all questions Q18-Q24**

```html
<!-- ============================================ -->
<!-- SECTION 4: INJURY DETAILS                   -->
<!-- ============================================ -->
<div class="section" id="section-4"
     tal:condition="python: context.injury_body_areas or context.injury_classifications or context.first_aid_given or context.medical_treatment_sought">
    <h3 class="section-header">Section 4: Injury Details</h3>

    <!-- Q18: Body areas (was Q16) -->
    <div class="field" tal:condition="context/injury_body_areas">
        <strong>Q18: Body areas affected:</strong>
        <!-- Display body areas -->
    </div>

    <!-- Q19: Injury classifications (was Q17) -->
    <!-- Q20: First aid given (was Q18) -->
    <!-- Q21: First aid provider (was Q19) -->
    <!-- Q22: First aid description (was Q20) -->
    <!-- Q23: Medical treatment sought (was Q21) -->
    <!-- Q24: Medical treatment location (was Q23) -->
    <!-- All with updated question numbers -->
</div>
```

**Section 5: Property Damage - Display plant number Q27**

```html
<!-- ============================================ -->
<!-- SECTION 5: PROPERTY & PLANT DAMAGE          -->
<!-- ============================================ -->
<div class="section" id="section-5"
     tal:condition="python: context.property_damage_types or context.property_damage_detail or context.plant_number or context.vehicle_damage_report_completed">
    <h3 class="section-header">Section 5: Property & Plant Damage</h3>

    <!-- Q25: Property damage types (was Q24) -->
    <div class="field" tal:condition="context/property_damage_types">
        <strong>Q25: Type of property damaged:</strong>
        <ul>
            <li tal:repeat="damage_type context/property_damage_types"
                tal:content="damage_type">Vehicle</li>
        </ul>
    </div>

    <!-- Q26: Property damage detail (was Q25) -->
    <div class="field" tal:condition="context/property_damage_detail">
        <strong>Q26: Further detail of property damaged:</strong>
        <p tal:content="structure python:context.property_damage_detail.replace('\n', '<br/')">
            Damage detail
        </p>
    </div>

    <!-- Q27: Plant number (NEW) -->
    <div class="field" tal:condition="context/plant_number">
        <strong>Q27: Plant number:</strong>
        <span tal:content="context/plant_number">P123</span>
    </div>

    <!-- Q28: Vehicle damage report (was Q26) -->
    <div class="field" tal:condition="context/vehicle_damage_report_completed">
        <strong>Q28: Plant / Vehicle Damage Report completed:</strong>
        <span tal:content="context/vehicle_damage_report_completed">Yes</span>
    </div>
</div>
```

**Section 6: Preliminary Observations - Renumber Q29-Q30**

```html
<!-- Q29: Contributing factors (was Q27) -->
<!-- Q30: Preventative actions (was Q28) -->
<!-- Update question numbers only -->
```

#### 4.2 Add View Helper Method

**File:** `csc/src/csc/whs/browser/incident_view.py` (or wherever incident view is defined)

```python
from csc.whs.utilities import get_vocabulary_display_name

class IncidentView(BrowserView):
    """Incident view class"""

    def get_vocabulary_display_name(self, vocabulary_name, token):
        """Get display name for vocabulary token

        Used in templates to convert tokens to human-readable names.
        """
        return get_vocabulary_display_name(vocabulary_name, token)
```

#### 4.3 Testing Checklist - Phase 4

- [ ] Section 3 displays all new fields (Q13-Q17)
- [ ] Emergency services types display as human-readable names
- [ ] Emergency services section only shows if called=yes
- [ ] Section 4 question numbers correct (Q18-Q24)
- [ ] Plant number (Q27) displays in Section 5
- [ ] Section 6 question numbers correct (Q29-Q30)
- [ ] Empty fields handled gracefully (don't display if no data)
- [ ] Line breaks preserved in text fields

---

### ✅ Super-Phase 5: JavaScript Enhancements (2 hours)

**Goal:** Add client-side interactivity for title generation and conditional emergency services display.

#### 5.1 Title Auto-Generation JavaScript

**File:** `csc/src/csc/whs/browser/static/incident_form.js`

**Add title generation logic:**

```javascript
/**
 * Auto-generate incident title from key fields
 * Pattern: <Incident Type> - <Department> - <Location Town>
 */
document.addEventListener('DOMContentLoaded', function() {
    const titleField = document.getElementById('form-widgets-IDublinCore-title');
    const incidentTypesCheckboxes = document.querySelectorAll('input[name="incident_types"]');
    const departmentField = document.getElementById('form-widgets-department');
    const locationTownField = document.getElementById('form-widgets-location_town');

    if (!titleField || !departmentField) {
        return; // Fields not present
    }

    // Track if user manually edited title
    let titleManuallyEdited = false;
    titleField.addEventListener('input', function() {
        titleManuallyEdited = true;
    });

    // Generate title function
    function generateTitle() {
        // Skip if user manually edited title
        if (titleManuallyEdited && titleField.value.trim() !== '') {
            return;
        }

        // Get first selected incident type
        let incidentType = 'Incident';
        for (const checkbox of incidentTypesCheckboxes) {
            if (checkbox.checked) {
                incidentType = checkbox.nextElementSibling.textContent.trim();
                break;
            }
        }

        // Get department
        const department = departmentField.options[departmentField.selectedIndex]?.text || '';

        // Get location town
        const locationTown = locationTownField?.value.trim() || 'Unknown Location';

        // Generate title
        if (department && locationTown) {
            const generatedTitle = `${incidentType} - ${department} - ${locationTown}`;
            titleField.value = generatedTitle;
            titleField.classList.add('auto-generated');
            setTimeout(() => titleField.classList.remove('auto-generated'), 2000);
        }
    }

    // Attach event listeners
    incidentTypesCheckboxes.forEach(cb => cb.addEventListener('change', generateTitle));
    if (departmentField) departmentField.addEventListener('change', generateTitle);
    if (locationTownField) locationTownField.addEventListener('blur', generateTitle);
});
```

#### 5.2 Emergency Services Conditional Display

**File:** `csc/src/csc/whs/browser/static/incident_form.js`

**Add conditional logic for Q16/Q17:**

```javascript
/**
 * Show/hide emergency services types (Q17) based on Q16 answer
 */
document.addEventListener('DOMContentLoaded', function() {
    const emergencyCalledField = document.getElementById('form-widgets-emergency_services_called');
    const emergencyTypesContainer = document.getElementById('emergency-services-types-container');
    const emergencyTypesCheckboxes = document.querySelectorAll('input[name="emergency_services_types"]');

    if (!emergencyCalledField || !emergencyTypesContainer) {
        return; // Fields not present
    }

    // Function to toggle display
    function toggleEmergencyServicesTypes() {
        const value = emergencyCalledField.value;

        if (value === 'yes') {
            emergencyTypesContainer.style.display = 'block';
            // Scroll into view for better UX
            emergencyTypesContainer.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        } else {
            emergencyTypesContainer.style.display = 'none';
            // Clear all selections when hiding
            emergencyTypesCheckboxes.forEach(cb => cb.checked = false);
        }
    }

    // Attach event listener
    emergencyCalledField.addEventListener('change', toggleEmergencyServicesTypes);

    // Run on page load (for edit forms)
    toggleEmergencyServicesTypes();
});

/**
 * Validate emergency services types selection
 * If Q16=Yes, at least one service must be selected
 */
function validateEmergencyServices() {
    const emergencyCalled = document.getElementById('form-widgets-emergency_services_called')?.value;

    if (emergencyCalled === 'yes') {
        const checkboxes = document.querySelectorAll('input[name="emergency_services_types"]:checked');
        if (checkboxes.length === 0) {
            alert('Q17: Please select at least one emergency service type.');
            document.getElementById('emergency-services-types-container').scrollIntoView({ behavior: 'smooth' });
            return false;
        }
    }
    return true;
}

// Add to form submit handler
document.addEventListener('DOMContentLoaded', function() {
    const form = document.querySelector('form.incident-form');
    if (form) {
        form.addEventListener('submit', function(e) {
            if (!validateEmergencyServices()) {
                e.preventDefault();
                return false;
            }
        });
    }
});
```

#### 5.3 CSS Enhancements

**File:** `csc/src/csc/whs/browser/static/incident_form.css`

**Add styling for new elements:**

```css
/* Auto-generated title visual feedback */
.auto-generated {
    background-color: #d4edda !important;
    border-color: #28a745 !important;
    transition: background-color 2s ease, border-color 2s ease;
}

/* Emergency services types checkbox group */
.checkbox-group {
    margin: 0.5rem 0;
}

.checkbox-group label {
    display: block;
    margin: 0.5rem 0;
    padding: 0.5rem;
    cursor: pointer;
    transition: background-color 0.2s ease;
}

.checkbox-group label:hover {
    background-color: #f8f9fa;
}

.checkbox-group input[type="checkbox"] {
    margin-right: 0.5rem;
}

/* Emergency services types container */
#emergency-services-types-container {
    margin-top: 1rem;
    padding: 1rem;
    background-color: #fff3cd;
    border-left: 4px solid #ffc107;
    border-radius: 4px;
}

#emergency-services-types-container .field-description {
    margin-bottom: 0.75rem;
}

/* Required field indicators */
.required {
    color: #dc3545;
    font-weight: bold;
    margin-left: 0.25rem;
}

/* Question numbers */
label strong {
    color: #0066cc;
    font-weight: 600;
    margin-right: 0.25rem;
}
```

#### 5.4 Testing Checklist - Phase 5

- [ ] Title auto-generates when incident type, department, or location changes
- [ ] User can manually override auto-generated title
- [ ] Manual edits prevent auto-generation from overwriting
- [ ] Visual feedback shows when title is auto-generated
- [ ] Q17 (emergency services types) hidden by default
- [ ] Q17 shows when Q16 changed to "Yes"
- [ ] Q17 hides when Q16 changed to "No"
- [ ] Changing to "No" clears all checkbox selections
- [ ] Form submission validates at least one service selected if Q16=Yes
- [ ] Smooth scrolling to Q17 when it appears
- [ ] CSS styling looks professional

---

### ✅ Super-Phase 6: Data Migration - Single Upgrade Step (1.5 hours)

**Goal:** Create one upgrade step to handle emergency services Boolean→Choice migration.

#### 6.1 Create Upgrade Step File

**File:** `csc/src/csc/whs/upgrades/v19.py` (create new file)

```python
# -*- coding: utf-8 -*-
"""Upgrade step: Profile 18 → 19 - Form Enhancements"""

from plone import api
import logging

logger = logging.getLogger('csc.whs.upgrades.v19')


def upgrade_form_enhancements(setup_tool):
    """Migrate emergency_services_called from Boolean to Choice field

    This upgrade:
    1. Converts emergency_services_called Boolean (True/False) → Choice ('yes'/'no')
    2. Initializes new fields (location_town, emergency_services_types, plant_number)
    3. Ensures immediate_actions has content (now required)
    4. Reindexes all incidents

    Part of Form Enhancements release (Requests #2-#5)
    """
    catalog = api.portal.get_tool('portal_catalog')

    logger.info("Starting Form Enhancements upgrade (Profile 18 → 19)...")
    incidents = catalog(portal_type='csc.whs.incident')

    migrated_count = 0
    error_count = 0

    for brain in incidents:
        try:
            incident = brain.getObject()

            # 1. Migrate emergency_services_called Boolean → Choice
            old_value = getattr(incident, 'emergency_services_called', None)
            if isinstance(old_value, bool):
                incident.emergency_services_called = 'yes' if old_value else 'no'
                logger.debug(f"Incident {incident.getId()}: emergency_services_called {old_value} → {incident.emergency_services_called}")

            # 2. Initialize new fields if not present
            if not hasattr(incident, 'location_town'):
                incident.location_town = ''

            if not hasattr(incident, 'emergency_services_types'):
                incident.emergency_services_types = []

            if not hasattr(incident, 'plant_number'):
                incident.plant_number = ''

            # 3. Check immediate_actions (now required, but don't fail on old data)
            if not getattr(incident, 'immediate_actions', ''):
                logger.warning(f"Incident {incident.getId()}: immediate_actions is empty (now required for new submissions)")

            # Reindex
            incident.reindexObject()
            migrated_count += 1

        except Exception as e:
            logger.error(f"Error migrating incident {brain.getPath()}: {e}")
            error_count += 1

    # Summary
    logger.info(f"=== FORM ENHANCEMENTS UPGRADE COMPLETE ===")
    logger.info(f"Incidents migrated: {migrated_count}")
    logger.info(f"Errors: {error_count}")
    logger.info(f"Total processed: {len(incidents)}")

    if error_count > 0:
        logger.warning(f"⚠️  {error_count} incidents had errors during migration.")
        logger.warning(f"Review logs and update manually if needed.")
```

#### 6.2 Register Upgrade Step

**File:** `csc/src/csc/whs/profiles/default/upgrades.zcml`

```xml
<genericsetup:upgradeStep
    source="18"
    destination="19"
    title="Form Enhancements (Requests #2-#5)"
    description="Migrate emergency services field to choice, initialize new fields (location_town, emergency_services_types, plant_number), update question numbering"
    handler="csc.whs.upgrades.v19.upgrade_form_enhancements"
    profile="csc.whs:default"
    />
```

#### 6.3 Update Profile Version

**File:** `csc/src/csc/whs/profiles/default/metadata.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <version>19</version>
  <dependencies>
    <dependency>profile-plone.app.dexterity:default</dependency>
    <dependency>profile-pas.plugins.ldap:default</dependency>
  </dependencies>
</metadata>
```

#### 6.4 Testing Checklist - Phase 6

- [ ] Upgrade step appears in Site Setup → Add-ons
- [ ] Upgrade runs without errors
- [ ] Emergency services called migrated from boolean to choice
- [ ] New fields initialized on existing incidents
- [ ] Reindexing completed successfully
- [ ] Check logs for any warnings
- [ ] Verify existing incidents display correctly

---

### ✅ Super-Phase 7: Testing & Deployment (2-3 hours)

**Goal:** Comprehensive testing of all consolidated changes.

#### 7.1 Unit Tests

**Create test file:** `csc/src/csc/whs/tests/test_form_enhancements.py`

```python
# -*- coding: utf-8 -*-
"""Tests for Form Enhancements (Requests #2-#5)"""

import unittest
from csc.whs.utilities import generate_incident_title, get_vocabulary_display_name


class TestTitleGeneration(unittest.TestCase):
    """Test auto-generated incident titles"""

    def test_title_generation(self):
        """Test title generation from incident details"""
        title = generate_incident_title(
            incident_types=['minor-injury'],
            department='ict',
            location_town='Cooktown'
        )
        self.assertIn('Injury', title)
        self.assertIn('ICT', title)
        self.assertIn('Cooktown', title)

    def test_title_with_unknown_location(self):
        """Test title generation with missing location"""
        title = generate_incident_title(
            incident_types=['near-miss'],
            department='water-wastewater',
            location_town=''
        )
        self.assertIn('Unknown Location', title)


class TestEmergencyServicesVocabulary(unittest.TestCase):
    """Test emergency services vocabulary"""

    def test_vocabulary_has_five_terms(self):
        """Emergency services vocabulary should have 5 terms"""
        from zope.component import getUtility
        from zope.schema.interfaces import IVocabularyFactory

        vocab_factory = getUtility(IVocabularyFactory, 'csc.whs.EmergencyServicesVocabulary')
        vocab = vocab_factory(None)

        self.assertEqual(len(vocab), 5)
        self.assertIn('police', [t.token for t in vocab])
        self.assertIn('ambulance', [t.token for t in vocab])
```

#### 7.2 Integration Tests

**Test scenarios:**

- [ ] **Request #2: Title Generation**
  - Submit incident with incident type, department, location town
  - Verify title auto-generates correctly
  - Submit incident with manual title override
  - Verify manual title is preserved

- [ ] **Request #2: Required Fields**
  - Attempt to submit without description → error
  - Attempt to submit without immediate actions → error
  - Submit with both fields → success

- [ ] **Request #3: Question Numbering**
  - Visual inspection: all questions numbered Q13-Q30
  - No gaps or duplicates in numbering
  - Numbers match across authenticated and anonymous forms

- [ ] **Request #4: Emergency Services**
  - Select Q16="No" → Q17 hidden
  - Select Q16="Yes" → Q17 appears
  - Try submit Q16="Yes" with no services → error
  - Submit Q16="Yes" with services selected → success
  - Verify emergency services types stored correctly

- [ ] **Request #5: Plant Number**
  - Submit incident with plant number → stores correctly
  - Submit without plant number → success (optional field)
  - Verify plant number displays in view

- [ ] **Data Migration**
  - Create test incident with old boolean emergency_services_called
  - Run upgrade step
  - Verify field converted to 'yes'/'no' choice

#### 7.3 User Acceptance Testing with WHS Officer

**Test checklist:**

- [ ] Create new incident with all sections filled
- [ ] Verify title auto-generates from details
- [ ] Verify description and immediate actions are required
- [ ] Test emergency services conditional display
- [ ] Add plant number to property damage section
- [ ] Submit form and verify email notification
- [ ] View submitted incident - check all fields display
- [ ] Test with various scenarios (injury, no injury, property damage, etc.)
- [ ] Review old incidents - verify migration successful

#### 7.4 Browser Compatibility

Test in:
- [ ] Chrome (latest) - Desktop
- [ ] Firefox (latest) - Desktop
- [ ] Safari (if Mac users) - Desktop
- [ ] Edge (if Windows users) - Desktop
- [ ] Mobile browser (iOS Safari or Android Chrome)

**Focus areas:**
- JavaScript title generation
- Conditional display of Q17
- Form validation
- Visual feedback animations

#### 7.5 Deployment Steps

**Update package version:**

**File:** `pyproject.toml`
```toml
[project]
name = "csc.whs"
version = "0.10.19"  # Changed from 0.10.18
```

**Deploy to server:**

```bash
cd /home/ceo/Development/WHSPortal
./deploy-systemd.sh csc
```

**Run upgrade step:**
1. Log in to https://whsportal.cook.qld.gov.au as admin
2. Go to: Site Setup → Add-ons
3. Find "csc.whs" → Click "Upgrade"
4. Run upgrade 18 → 19
5. Verify success message

**Post-deployment verification:**
- [ ] Create new incident → verify all features work
- [ ] View existing incident → verify migration successful
- [ ] Check Plone logs for errors: `ssh whsportaldev 'sudo journalctl -u plone -n 200'`
- [ ] Test with WHS Officer for acceptance

#### 7.6 Documentation Updates

**Update README:**

**File:** `csc/README.md`

```markdown
### Version 0.10.19 (October 2025) - Form Enhancements

**Consolidated implementation of WHS Officer Requests #2-#5**

**Section 3 Enhancements:**
- Added question numbers Q13-Q15 for consistency
- Auto-generate incident title from: Incident Type - Department - Location Town
- Made "What happened" (description) required
- Made "Immediate Actions" required
- Added location_town field for title generation
- Moved emergency services from Section 4 to Section 3
- Changed emergency_services_called from Boolean to Choice (Yes/No)
- Added emergency_services_types multi-select (Police, Fire, Ambulance, SES, Other)
- Conditional display: emergency services types only shown if called=Yes

**Section 5 Enhancements:**
- Added plant_number field (Q27) for tracking council assets

**Question Renumbering:**
- Section 3: Q13-Q17 (Incident Details)
- Section 4: Q18-Q24 (Injury Details, +2 shift)
- Section 5: Q25-Q28 (Property Damage, +2 shift)
- Section 6: Q29-Q30 (Preliminary Observations, +2 shift)

**Technical Details:**
- Profile upgrade: 18 → 19
- New vocabulary: EmergencyServicesVocabulary (5 services)
- JavaScript: Title auto-generation, conditional emergency services display
- Data migration: emergency_services_called Boolean → Choice
- Files modified: 15

**Time Tracking:**
- Estimated: 17-20 hours (separate), 12-14 hours (consolidated)
- Actual: [TO BE FILLED]
- Time savings: 30-35% from consolidation
```

**Update PROJECT_STATUS.md:**

**File:** `/home/ceo/Development/WHSPortal/PROJECT_STATUS.md`

```markdown
### Version 0.10.19 - Form Enhancements (October 2025)

**Status:** ✅ Complete
**Priority:** Medium
**WHS Officer Requests:** #2, #3, #4, #5 (consolidated implementation)

**Consolidated Changes:**
- Request #2: Auto-generate titles, required fields (description, immediate actions)
- Request #3: Question numbering Q13-Q15 in Section 3
- Request #4: Emergency services moved to Section 3, Boolean→Choice, multi-select
- Request #5: Plant number field in Section 5

**Key Features:**
- Title auto-generation: `<Type> - <Department> - <Town>`
- Required field validation for description and immediate actions
- Emergency services conditional display (Q16→Q17)
- Plant number tracking for council assets
- Comprehensive question renumbering (Q13-Q30)

**Technical Implementation:**
- Profile upgrade: 18 → 19
- New vocabulary: EmergencyServicesVocabulary
- JavaScript enhancements: title generation, conditional display
- Single upgrade step handles all migrations
- 15 files modified in consolidated effort

**Efficiency Gains:**
- Separate implementation estimated: 17-20 hours
- Consolidated implementation estimated: 12-14 hours
- Time savings: 30-35% (5-6 hours)
- Reason: Templates opened once, question renumbering done once, single deployment

**Time Tracking:**
- Estimated: 12-14 hours (AI-assisted, consolidated)
- Actual: [TO BE FILLED DURING IMPLEMENTATION]
- Breakdown:
  - Super-Phase 1 (Schema & Vocabularies): ___ hours
  - Super-Phase 2 (Templates): ___ hours
  - Super-Phase 3 (Business Logic): ___ hours
  - Super-Phase 4 (View Templates): ___ hours
  - Super-Phase 5 (JavaScript): ___ hours
  - Super-Phase 6 (Data Migration): ___ hours
  - Super-Phase 7 (Testing & Deployment): ___ hours
- Productivity Gain: ___% vs traditional development
```

#### 7.7 Git Commit

```bash
cd /home/ceo/Development/WHSPortal/csc
git add -A
git commit -m "$(cat <<'EOF'
Implement Form Enhancements (v0.10.19)

Consolidated implementation of WHS Officer Requests #2-#5.

Section 3 Enhancements (Requests #2, #3):
- Added question numbering Q13-Q15
- Auto-generate title from incident type, department, location
- Made description (Q14) and immediate actions (Q15) required
- Added location_town field for title generation
- JavaScript auto-title generation with manual override

Emergency Services Enhancements (Request #4):
- Moved emergency services from Section 4 to Section 3 (Q16-Q17)
- Changed emergency_services_called: Boolean → Choice (Yes/No)
- Added emergency_services_types multi-select field
- Conditional display: services shown only if called=Yes
- JavaScript conditional logic and validation
- Data migration: Boolean → Choice field

Property Damage Enhancement (Request #5):
- Added plant_number field (Q27) in Section 5
- Optional field for tracking council assets/vehicles

Question Renumbering:
- Section 4: Q18-Q24 (was Q16-Q23, +2 shift)
- Section 5: Q25-Q28 (was Q24-Q26, +2 shift)
- Section 6: Q29-Q30 (was Q27-Q28, +2 shift)

Implementation Strategy:
- Consolidated 4 separate requests into single release
- Efficiency gain: 30-35% time savings (12-14h vs 17-20h)
- Templates modified once with all changes
- Question renumbering done in single pass
- Single upgrade step (Profile 18 → 19)

Technical Details:
- New vocabulary: EmergencyServicesVocabulary (5 services)
- New utility functions: generate_incident_title()
- JavaScript: title generation, conditional display, validation
- CSS: visual feedback, checkbox styling
- Upgrade step: Migrate emergency_services_called Boolean → Choice
- Files modified: 15

Testing:
- Unit tests: title generation, vocabulary
- Integration tests: all 4 requests validated
- UAT: WHS Officer acceptance testing complete

WHS Officer Requests #2, #3, #4, #5 - Complete

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Push to GitHub:**
```bash
gh repo sync
```

---

## Progress Tracking

### Overall Status: 📋 Ready to Implement

- [ ] Super-Phase 1: Foundation - Schema & Vocabularies (2 hours)
- [ ] Super-Phase 2: Templates - All Forms Updated (3-4 hours)
- [ ] Super-Phase 3: Business Logic - Processing Updates (3-4 hours)
- [ ] Super-Phase 4: View Templates - Display Updates (2 hours)
- [ ] Super-Phase 5: JavaScript Enhancements (2 hours)
- [ ] Super-Phase 6: Data Migration - Upgrade Step (1.5 hours)
- [ ] Super-Phase 7: Testing & Deployment (2-3 hours)

**Total Progress:** 0 / 7 super-phases complete

---

## Files to Modify (15 files)

### Core Schema & Logic (8 files)
- [ ] `csc/src/csc/whs/interfaces.py` - All schema changes consolidated
- [ ] `csc/src/csc/whs/vocabularies.py` - Emergency services vocabulary
- [ ] `csc/src/csc/whs/configure.zcml` - Register vocabulary
- [ ] `csc/src/csc/whs/utilities.py` - Title generation functions (append)
- [ ] `csc/src/csc/whs/browser/intake.py` - Incident intake processing
- [ ] `csc/src/csc/whs/browser/anonymous.py` - Anonymous form processing
- [ ] `csc/src/csc/whs/notifications.py` - Email notifications
- [ ] `csc/src/csc/whs/upgrades/v19.py` - Upgrade step (CREATE NEW)

### Templates (3 files)
- [ ] `csc/src/csc/whs/browser/templates/report_incident.pt` - All changes consolidated
- [ ] `csc/src/csc/whs/browser/templates/anonymous_form.pt` - All changes consolidated
- [ ] `csc/src/csc/whs/browser/templates/incident.pt` - View updates

### JavaScript & CSS (2 files)
- [ ] `csc/src/csc/whs/browser/static/incident_form.js` - Title generation + conditional display
- [ ] `csc/src/csc/whs/browser/static/incident_form.css` - Styling enhancements

### Configuration (2 files)
- [ ] `csc/src/csc/whs/profiles/default/metadata.xml` - Profile version 18→19
- [ ] `csc/src/csc/whs/profiles/default/upgrades.zcml` - Register upgrade step

---

## Time Tracking

**Estimated Time:** 12-14 hours (AI-assisted, consolidated)

**Actual Time:** _[To be filled during implementation]_

**Breakdown:**
- Super-Phase 1: ___ hours (estimated 2h)
- Super-Phase 2: ___ hours (estimated 3-4h)
- Super-Phase 3: ___ hours (estimated 3-4h)
- Super-Phase 4: ___ hours (estimated 2h)
- Super-Phase 5: ___ hours (estimated 2h)
- Super-Phase 6: ___ hours (estimated 1.5h)
- Super-Phase 7: ___ hours (estimated 2-3h)

**Total Actual:** ___ hours

**Comparison:**
- Separate implementation: 17-20 hours estimated
- Consolidated: 12-14 hours estimated
- **Time savings: 30-35%** (5-6 hours saved)

**Productivity Gain:** ___% time savings vs traditional development (estimated 25-30 hours)

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Question renumbering errors | Medium | Comprehensive testing, systematic approach |
| Emergency services migration fails | Medium | Keep old boolean field as backup |
| JavaScript doesn't work in all browsers | Low | Fallback to manual entry always available |
| Title generation produces poor titles | Low | Allow manual override |
| Required fields block old workflows | Medium | Validate only on new submissions |

---

## Success Criteria

✅ All question numbers correct (Q13-Q30)
✅ Title auto-generation works reliably
✅ Description and immediate actions validation prevents empty submissions
✅ Emergency services conditional display works smoothly
✅ Plant number field stores and displays correctly
✅ All existing incidents migrated successfully
✅ Email notifications include all new fields
✅ JavaScript works in all target browsers
✅ WHS Officer approves all enhancements
✅ No errors in Plone logs

---

**Document Created:** October 18, 2025
**Status:** Ready to implement
**Next Action:** Begin Super-Phase 1 - Foundation (Schema & Vocabularies)

---

## Additional Enhancement Requests (Post-Phase A Testing)

During Phase A (Division → Department) testing, three additional UX enhancement requests were identified:

### Enhancement Request #6: Department Dropdown Alphabetical Sorting

**Issue Identified:**
Department dropdown displays in random order, making it difficult to visually locate departments when selecting manually.

**Current Behavior:**
- Department vocabulary returns terms in definition order (not alphabetical)
- 26 departments displayed without consistent ordering
- Users must scan entire list to find their department

**Requested Changes:**
1. Sort department dropdown alphabetically by title
2. Add label hint: "You can start typing to automatically select the department"
3. Apply to ALL usages of Department field:
   - Incident form (authenticated) - report-incident.pt
   - Incident form (anonymous) - anonymous_form.pt
   - Hazard form (authenticated) - report-hazard.pt
   - Hazard form (anonymous) - whs-hazard-intake

**Why This Matters:**
- Not noticeable in authenticated incident form (LDAP auto-populates department)
- Very noticeable in:
  - Anonymous incident reports (no LDAP)
  - All hazard reports (no LDAP auto-population)
  - Manual corrections/overrides

**Implementation Approach:**

**Option A: Sort in Vocabulary Factory (Recommended)**

**File:** `csc/src/csc/whs/vocabularies.py`

Modify `DepartmentVocabularyFactory`:

```python
@provider(IVocabularyFactory)
def DepartmentVocabularyFactory(context):
    """Department vocabulary for Cook Shire Council

    Returns departments sorted alphabetically by title for better UX.
    """
    terms = [
        SimpleTerm(value='ict', title='Information and Communications Technology'),
        SimpleTerm(value='water-wastewater', title='Water & Wastewater'),
        # ... all 26 departments ...
    ]

    # Sort terms alphabetically by title
    sorted_terms = sorted(terms, key=lambda term: term.title)

    return SimpleVocabulary(sorted_terms)
```

**Add typing hint to labels:**

Update all templates that render department field:

```html
<label for="form-widgets-department">
    <strong>Q5:</strong> Department of person injured <span class="required">*</span>
</label>
<select id="form-widgets-department" name="department" required>
    <option value="">-- Select department (or start typing) --</option>
    <!-- Department options here -->
</select>
<p class="field-description">
    Select the department of the person injured. You can start typing to automatically select.
</p>
```

**Files to Modify:**
- `csc/src/csc/whs/vocabularies.py` - Sort DepartmentVocabulary terms
- `csc/src/csc/whs/browser/templates/report_incident.pt` - Update Q5 label hint
- `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Update Q5 label hint
- `csc/src/csc/whs/browser/templates/report_hazard.pt` - Update department label hint
- `csc/src/csc/whs/browser/templates/whs-hazard-intake` (if exists) - Update label hint

**Testing:**
- [ ] Department dropdown displays in alphabetical order in all forms
- [ ] Typing in dropdown auto-selects matching department
- [ ] Label hints display correctly
- [ ] LDAP auto-population still works in authenticated incident form
- [ ] Manual selection works in all other forms

**Priority:** High (UX improvement affecting all users)
**Estimated Effort:** 0.5-1 hour

---

### Enhancement Request #7: Add "Return to Home" Link to Hazard Form

**Issue Identified:**
After submitting a hazard report, there is no "Return to home page" link displayed. This feature exists in the incident report form but is missing from the hazard form, creating an inconsistent user experience.

**Current Behavior:**
- Incident form submission shows success message with "Return to home page" link
- Hazard form submission shows success message WITHOUT return link
- Users must use browser back button or manually navigate

**Requested Change:**
Add "Return to home page" link to hazard form submission success page, matching the pattern used in incident form.

**Implementation Approach:**

**Step 1: Review Incident Form Pattern**

Find where incident form displays "Return to home page" link after submission.

**Likely locations:**
- `csc/src/csc/whs/browser/templates/anonymous_form.pt` - Success message section
- `csc/src/csc/whs/browser/anonymous.py` - Response HTML generation
- `csc/src/csc/whs/browser/intake.py` - Success response

**Step 2: Apply Same Pattern to Hazard Forms**

**Files to check/modify:**
- `csc/src/csc/whs/browser/report_hazard.py` - Hazard form processing (authenticated)
- `csc/src/csc/whs/browser/hazard_intake.py` - Hazard intake processing (anonymous)
- Success response templates for hazard submissions

**Expected Code Pattern (from incident form):**

```html
<div class="success-message">
    <h2>Hazard Report Submitted Successfully</h2>
    <p>Your hazard report has been recorded with ID: <strong tal:content="report_id">HR-123</strong></p>
    <p>The WHS team has been notified and will review your report.</p>

    <!-- Add this link matching incident form -->
    <p>
        <a href="/" class="button">Return to home page</a>
    </p>
</div>
```

**Files to Modify:**
- Hazard form success response templates (locate during implementation)
- Hazard form processing classes (add return link to success response)

**Testing:**
- [ ] Submit hazard report (authenticated) → see "Return to home page" link
- [ ] Submit hazard report (anonymous) → see "Return to home page" link
- [ ] Click link → navigates to home page
- [ ] Visual style matches incident form link
- [ ] Link appears in same position as incident form

**Priority:** Medium (UX consistency improvement)
**Estimated Effort:** 0.5-1 hour

---

### Enhancement Request #8: Improve Mandatory Field Validation Visual Feedback

**Issue Identified:**
When submitting a form with missing required fields, the current validation provides minimal feedback:
- Generic browser alert: "Please fill out this field"
- No visual indication of which section contains the missing field
- No highlighting of the specific missing question
- Users must manually search through collapsed sections to find missing fields

**Current Behavior:**
1. User submits form with missing required field(s)
2. Browser shows default alert (varies by browser)
3. Page may scroll to first missing field (browser-dependent)
4. No visual cues on section headers
5. No highlighting on field labels or questions
6. No persistent error message at top of form

**User's Suggested Approach:**
- Make the section header containing missed field(s) red
- Make the question label for missed field(s) red
- Open for better implementation suggestions

**Recommended Implementation Approach:**

**Option: Enhanced Client-Side Validation with Visual Feedback**

This approach provides comprehensive, professional validation feedback:

**JavaScript Validation (client-side):**

**File:** `csc/src/csc/whs/browser/static/incident_form.js`

```javascript
/**
 * Enhanced form validation with visual feedback
 * Shows clear indicators for missing required fields
 */
function validateFormWithFeedback(formElement) {
    // Clear any previous validation feedback
    clearValidationFeedback();

    let errors = [];
    let firstErrorField = null;

    // Find all required fields
    const requiredFields = formElement.querySelectorAll('[required]');

    requiredFields.forEach(field => {
        const fieldValue = field.value.trim();
        const isEmpty = !fieldValue || fieldValue === '';

        if (isEmpty) {
            // Track first error for scrolling
            if (!firstErrorField) {
                firstErrorField = field;
            }

            // Get field info
            const label = getLabelForField(field);
            const section = getSectionForField(field);
            const questionNumber = getQuestionNumber(label);

            // Add visual feedback
            markFieldAsError(field, label, section);

            // Add to error list
            errors.push({
                questionNumber: questionNumber,
                fieldName: label ? label.textContent.trim() : field.name,
                section: section ? section.querySelector('.section-header').textContent.trim() : 'Unknown Section'
            });
        }
    });

    // If errors found, show summary and prevent submission
    if (errors.length > 0) {
        showValidationSummary(errors);
        scrollToFirstError(firstErrorField);
        return false;
    }

    return true;
}

/**
 * Mark field, label, and section with error styling
 */
function markFieldAsError(field, label, section) {
    // Highlight the field itself
    field.classList.add('field-error');
    field.setAttribute('aria-invalid', 'true');

    // Highlight the label
    if (label) {
        label.classList.add('label-error');

        // Add inline error message
        if (!label.querySelector('.error-indicator')) {
            const errorIndicator = document.createElement('span');
            errorIndicator.className = 'error-indicator';
            errorIndicator.textContent = ' (Required)';
            errorIndicator.setAttribute('role', 'alert');
            label.appendChild(errorIndicator);
        }
    }

    // Highlight the section header
    if (section) {
        const sectionHeader = section.querySelector('.section-header');
        if (sectionHeader && !sectionHeader.classList.contains('section-error')) {
            sectionHeader.classList.add('section-error');

            // Add error badge to section
            const errorBadge = document.createElement('span');
            errorBadge.className = 'section-error-badge';
            errorBadge.textContent = '⚠';
            errorBadge.setAttribute('role', 'alert');
            errorBadge.setAttribute('aria-label', 'This section has missing required fields');
            sectionHeader.insertBefore(errorBadge, sectionHeader.firstChild);
        }

        // Expand section if collapsed
        expandSection(section);
    }
}

/**
 * Show validation summary at top of form
 */
function showValidationSummary(errors) {
    const form = document.querySelector('form.incident-form');
    if (!form) return;

    // Create summary container
    const summary = document.createElement('div');
    summary.className = 'validation-summary';
    summary.setAttribute('role', 'alert');
    summary.setAttribute('aria-live', 'assertive');

    // Add heading
    const heading = document.createElement('h3');
    heading.textContent = `Please complete the following ${errors.length} required field${errors.length > 1 ? 's' : ''}:`;
    summary.appendChild(heading);

    // Add error list
    const errorList = document.createElement('ul');
    errors.forEach(error => {
        const listItem = document.createElement('li');
        listItem.innerHTML = `<strong>${error.questionNumber || error.fieldName}</strong> in ${error.section}`;

        // Make clickable to jump to field
        listItem.style.cursor = 'pointer';
        listItem.addEventListener('click', () => {
            const field = document.querySelector(`[name="${error.fieldName}"]`);
            if (field) {
                field.scrollIntoView({ behavior: 'smooth', block: 'center' });
                field.focus();
            }
        });

        errorList.appendChild(listItem);
    });
    summary.appendChild(errorList);

    // Insert at top of form
    form.insertBefore(summary, form.firstChild);

    // Scroll to summary
    summary.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/**
 * Clear all validation feedback
 */
function clearValidationFeedback() {
    // Remove error summary
    document.querySelectorAll('.validation-summary').forEach(el => el.remove());

    // Remove field error styling
    document.querySelectorAll('.field-error').forEach(el => {
        el.classList.remove('field-error');
        el.removeAttribute('aria-invalid');
    });

    // Remove label error styling
    document.querySelectorAll('.label-error').forEach(el => {
        el.classList.remove('label-error');
    });

    // Remove error indicators
    document.querySelectorAll('.error-indicator').forEach(el => el.remove());

    // Remove section error styling
    document.querySelectorAll('.section-error').forEach(el => {
        el.classList.remove('section-error');
    });

    // Remove section error badges
    document.querySelectorAll('.section-error-badge').forEach(el => el.remove());
}

// Helper functions
function getLabelForField(field) {
    return document.querySelector(`label[for="${field.id}"]`) || field.closest('.field')?.querySelector('label');
}

function getSectionForField(field) {
    return field.closest('.form-section');
}

function getQuestionNumber(label) {
    if (!label) return '';
    const match = label.textContent.match(/Q\d+/);
    return match ? match[0] : '';
}

function scrollToFirstError(field) {
    if (field) {
        field.scrollIntoView({ behavior: 'smooth', block: 'center' });
        setTimeout(() => field.focus(), 500);
    }
}

function expandSection(section) {
    // If section uses collapsible pattern, expand it
    // Implementation depends on your collapsible section structure
    section.classList.add('expanded');
    section.style.display = 'block';
}

// Attach to form submit
document.addEventListener('DOMContentLoaded', function() {
    const forms = document.querySelectorAll('form.incident-form, form.hazard-form');
    forms.forEach(form => {
        form.addEventListener('submit', function(e) {
            // Clear previous feedback
            clearValidationFeedback();

            // Run validation
            const isValid = validateFormWithFeedback(form);

            if (!isValid) {
                e.preventDefault();
                return false;
            }
        });

        // Also clear validation when user starts fixing errors
        form.addEventListener('input', function(e) {
            if (e.target.classList.contains('field-error')) {
                e.target.classList.remove('field-error');
                e.target.removeAttribute('aria-invalid');

                const label = getLabelForField(e.target);
                if (label) {
                    label.classList.remove('label-error');
                    label.querySelector('.error-indicator')?.remove();
                }
            }
        });
    });
});
```

**CSS Styling:**

**File:** `csc/src/csc/whs/browser/static/incident_form.css`

```css
/* Validation Summary */
.validation-summary {
    background-color: #f8d7da;
    border: 2px solid #dc3545;
    border-radius: 4px;
    padding: 1rem 1.5rem;
    margin-bottom: 2rem;
    color: #721c24;
}

.validation-summary h3 {
    margin-top: 0;
    color: #dc3545;
    font-size: 1.1rem;
}

.validation-summary ul {
    margin: 0.75rem 0 0 0;
    padding-left: 1.5rem;
}

.validation-summary li {
    margin: 0.5rem 0;
    cursor: pointer;
    transition: color 0.2s ease;
}

.validation-summary li:hover {
    color: #dc3545;
    text-decoration: underline;
}

/* Field Error Styling */
.field-error {
    border: 2px solid #dc3545 !important;
    background-color: #fff5f5 !important;
    box-shadow: 0 0 0 0.2rem rgba(220, 53, 69, 0.25);
}

.field-error:focus {
    border-color: #dc3545 !important;
    box-shadow: 0 0 0 0.3rem rgba(220, 53, 69, 0.4) !important;
}

/* Label Error Styling */
.label-error {
    color: #dc3545 !important;
    font-weight: bold;
}

.error-indicator {
    color: #dc3545;
    font-weight: bold;
    font-size: 0.9rem;
    margin-left: 0.25rem;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.6; }
}

/* Section Header Error Styling */
.section-error {
    color: #dc3545 !important;
    background-color: #fff5f5;
    padding: 0.75rem;
    border-left: 4px solid #dc3545;
    border-radius: 4px;
}

.section-error-badge {
    display: inline-block;
    font-size: 1.2rem;
    margin-right: 0.5rem;
    animation: shake 0.5s;
}

@keyframes shake {
    0%, 100% { transform: translateX(0); }
    25% { transform: translateX(-5px); }
    75% { transform: translateX(5px); }
}

/* Expanded section visibility */
.form-section.expanded {
    display: block !important;
}

/* Accessibility improvements */
[aria-invalid="true"] {
    /* Additional styling for screen readers */
}

/* Focus states for error fields */
.field-error:focus-visible {
    outline: 3px solid #dc3545;
    outline-offset: 2px;
}
```

**Files to Modify:**
- `csc/src/csc/whs/browser/static/incident_form.js` - Add comprehensive validation logic
- `csc/src/csc/whs/browser/static/hazard_form.js` - Same validation logic (or create shared validation.js)
- `csc/src/csc/whs/browser/static/incident_form.css` - Add error styling
- `csc/src/csc/whs/browser/static/hazard_form.css` - Add error styling (or create shared forms.css)

**Alternative/Fallback: Server-Side Validation**

For cases where JavaScript is disabled, enhance server-side validation in intake processing:

**File:** `csc/src/csc/whs/browser/intake.py`

```python
def validate_required_fields(form_data):
    """Validate required fields and return detailed error messages"""
    errors = []

    # Check each required field
    if not form_data.get('description', '').strip():
        errors.append({
            'field': 'description',
            'question': 'Q14',
            'message': 'Description (What happened) is required',
            'section': 'Section 3: Incident Details'
        })

    if not form_data.get('immediate_actions', '').strip():
        errors.append({
            'field': 'immediate_actions',
            'question': 'Q15',
            'message': 'Immediate Actions Taken is required',
            'section': 'Section 3: Incident Details'
        })

    # ... more validation ...

    return errors

def render_error_response(errors):
    """Render detailed error page with section/field highlighting"""
    html = """
    <div class="validation-errors">
        <h2>Please complete the following required fields:</h2>
        <ul>
    """

    for error in errors:
        html += f"""
            <li>
                <strong>{error['question']}</strong> {error['message']}
                <br><small>In {error['section']}</small>
            </li>
        """

    html += """
        </ul>
        <p><a href="javascript:history.back()">Return to form</a></p>
    </div>
    """

    return html
```

**Testing:**
- [ ] Submit form with missing required field → validation summary appears at top
- [ ] Section header shows error badge and red styling
- [ ] Field label shows red styling with "(Required)" indicator
- [ ] Field itself has red border and background tint
- [ ] Click error in summary → scrolls to field and focuses it
- [ ] Validation summary lists all missing fields with section names
- [ ] Start typing in error field → error styling clears
- [ ] All section error badges clear when form is valid
- [ ] Test with multiple missing fields across different sections
- [ ] Test accessibility: screen reader announces errors
- [ ] Test without JavaScript: server-side validation still works

**Priority:** High (usability and accessibility improvement)
**Estimated Effort:** 2-3 hours

**Accessibility Considerations:**
- Use `role="alert"` and `aria-live="assertive"` for validation summary
- Use `aria-invalid="true"` on error fields
- Ensure error messages are programmatically associated with fields
- Provide keyboard navigation to error fields
- Test with screen readers (NVDA, JAWS, VoiceOver)

**Benefits:**
- Clear visual feedback on exactly what's missing
- Reduces user frustration and form abandonment
- Improves accessibility for all users
- Professional, modern UX matching industry best practices
- Helps users complete forms correctly on first attempt

---

## Summary of Additional Enhancement Requests

| # | Enhancement | Priority | Estimated Effort | Affects |
|---|-------------|----------|------------------|---------|
| #6 | Department dropdown alphabetical sorting | High | 0.5-1 hour | All forms (Incident & Hazard, authenticated & anonymous) |
| #7 | Add "Return to home" link to hazard form | Medium | 0.5-1 hour | Hazard forms only |
| #8 | Improve mandatory field validation feedback | High | 2-3 hours | All forms with required fields |

**Total Estimated Effort:** 3-5 hours

**When to Implement:**
These enhancements should be implemented after completing the current Form Enhancement Implementation (Phase B, Requests #2-#5). They can be grouped as:
- **Quick Wins (1-2 hours):** #6 and #7 together
- **Major UX Enhancement (2-3 hours):** #8 as separate implementation

**Version Planning:**
- Current plan: v0.10.18 → v0.10.19 (Requests #2-#5)
- These enhancements: v0.10.19 → v0.10.20 (Requests #6-#8)

**Profile Version:**
- Profile 18 → 19 (Current Form Enhancements)
- Profile 19 → 20 (Additional UX Enhancements) - OR -
- Profile 19 (no upgrade needed if only JS/CSS/template changes)

**Note:** Requests #6 and #7 require no schema changes or data migration, so may not need profile version bump. Request #8 is purely client-side (JS/CSS), also no profile change needed. Consider releasing as v0.10.19.1 or v0.10.20 with same profile version (19).
