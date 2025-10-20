# Hazard Enhancement Implementation Plan

## Executive Summary

This document outlines the implementation plan for enhancing the WHS Hazard content type to support before/after risk scoring, control measure tracking, and monitoring requirements. This addresses both the WHS Officer's request for dual risk assessment (initial vs residual risk) and corrects missing fields discovered in the CSV export functionality.

**Estimated Total Effort:** 6-8 hours
**Priority:** Medium-High (WHS Officer request + data integrity issue)
**Version Target:** csc.whs v0.10.20, Profile v20

---

## Business Context

### Current Limitations

1. **Single Risk Assessment Only**: Current hazard form only captures initial risk (before controls), with no ability to track residual risk after control implementation
2. **Missing Fields**: CSV export references 11 fields that don't exist in the schema, resulting in blank columns
3. **No Control Tracking**: No structured way to track what controls were applied, when, or who is responsible
4. **No Monitoring Framework**: No fields for ongoing monitoring requirements or review schedules
5. **Incomplete Location Data**: Hazards lack the `location_town` field that incidents have, making geographic analysis difficult

### WHS Officer Requirements

From the WHS Officer's request:
> "Section 4. Is it possible to get a risk matrix score and colour (see picture below) – when we look at control of risks we assign a before risk score, and after risk score."

The WHS Officer has provided a standard 5×5 risk matrix example showing:
- **Likelihood levels:** Rare, Unlikely, Possible, Likely, Almost Certain
- **Consequence levels:** Insignificant, Minor, Moderate, Major, Catastrophic
- **Risk ratings:** Low (L1-L4), Medium (M5-M12), High (H15-H20), Extreme (H25)
- **Color coding:** Green (Low), Orange (Medium), Red (High/Extreme)

### Proposed Solution

Implement a **dual risk assessment framework**:

1. **Initial Risk Assessment** (completed by reporter):
   - Assess hazard before any controls applied
   - Visible in report-hazard form

2. **Residual Risk Assessment** (completed by WHS Officer):
   - Assess hazard after controls implemented
   - Only visible/editable in hazard edit form (WHS Officers)
   - Provides before/after comparison

3. **Control Measure Tracking**:
   - Document recommended controls
   - Track implementation actions and dates
   - Define monitoring requirements
   - Schedule review dates

---

## Implementation Phases

### Phase 1: Schema Updates & Data Migration (2-3 hours)

**Objective:** Add new fields to IHazard schema and migrate existing risk assessment fields

#### 1.1 Add New Schema Fields

**File:** `csc/src/csc/whs/interfaces.py` (IHazard class)

**New Fields to Add:**

```python
# ========================================
# SECTION 3A: PEOPLE AT RISK & LOCATION
# ========================================

# Add after hazard_description field (line ~387)

# Town/locality field (matches incidents)
location_town = schema.TextLine(
    title=u"Town / locality of hazard",
    required=False,  # Not required for existing hazards
    description=u"Enter the town or locality where the hazard is located (e.g., Cooktown, Laura, Rossville)",
)

# Q8: Who is at risk?
people_at_risk = schema.Text(
    title=u"Who is at risk from this hazard?",
    required=False,
    description=u"Identify the people, roles, or groups who could be affected by this hazard (e.g., depot staff, visitors to facility, contractors working on site)",
)

# ========================================
# SECTION 4: INITIAL RISK ASSESSMENT (BEFORE CONTROLS)
# ========================================
# Rename existing fields by adding "initial_" prefix

# RENAME: risk_likelihood -> initial_risk_likelihood
initial_risk_likelihood = schema.Choice(
    title=u"Initial Risk Likelihood (before controls)",
    required=False,
    description=u"How likely is it that this hazard will cause an incident? (Assessment BEFORE any control measures applied)",
    vocabulary="csc.whs.RiskLikelihoodVocabulary",
)

# RENAME: risk_consequence -> initial_risk_consequence
initial_risk_consequence = schema.Choice(
    title=u"Initial Risk Consequence (before controls)",
    required=False,
    description=u"What would be the consequence if an incident occurred? (Assessment BEFORE any control measures applied)",
    vocabulary="csc.whs.RiskConsequenceVocabulary",
)

# RENAME: risk_rating -> initial_risk_rating
initial_risk_rating = schema.TextLine(
    title=u"Initial Risk Rating",
    required=False,
    description=u"Computed initial risk rating (extreme, high, medium, low) based on likelihood and consequence BEFORE controls",
)

# ========================================
# SECTION 5: CONTROL MEASURES (WHS OFFICER)
# ========================================
# These fields are for WHS Officer use during hazard management

# Rename existing field: suggested_controls -> recommended_controls
recommended_controls = schema.Text(
    title=u"Recommended Control Measures",
    required=False,
    description=u"Control measures recommended by WHS Officer to eliminate or minimize the hazard (hierarchy of controls: elimination, substitution, engineering, administrative, PPE)",
)

# NEW: Immediate actions taken
immediate_actions = schema.Text(
    title=u"Immediate Actions Taken",
    required=False,
    description=u"Immediate actions taken to mitigate the hazard upon identification (temporary measures, signage, barriers, work restrictions)",
)

# NEW: Control measures applied (final)
control_measures = schema.Text(
    title=u"Control Measures Applied",
    required=False,
    description=u"Final control measures that have been implemented (completed by WHS Officer)",
)

# NEW: Control implementation date
directives.widget('control_implementation_date', pattern_options={
    'date': {'format': 'DD/MM/YYYY', 'firstDay': 1}
})
control_implementation_date = schema.Date(
    title=u"Control Implementation Date",
    required=False,
    description=u"Date when control measures were fully implemented (DD/MM/YYYY format)",
)

# ========================================
# SECTION 6: RESIDUAL RISK ASSESSMENT (AFTER CONTROLS)
# ========================================
# This assessment is completed AFTER control measures have been applied

residual_risk_likelihood = schema.Choice(
    title=u"Residual Risk Likelihood (after controls)",
    required=False,
    description=u"How likely is it that this hazard will cause an incident AFTER control measures have been applied?",
    vocabulary="csc.whs.RiskLikelihoodVocabulary",
)

residual_risk_consequence = schema.Choice(
    title=u"Residual Risk Consequence (after controls)",
    required=False,
    description=u"What would be the consequence if an incident occurred AFTER control measures have been applied?",
    vocabulary="csc.whs.RiskConsequenceVocabulary",
)

residual_risk_rating = schema.TextLine(
    title=u"Residual Risk Rating",
    required=False,
    description=u"Computed residual risk rating (extreme, high, medium, low) based on likelihood and consequence AFTER controls",
)

# ========================================
# SECTION 7: MONITORING & REVIEW
# ========================================

monitoring_requirements = schema.Text(
    title=u"Monitoring Requirements",
    required=False,
    description=u"Ongoing monitoring requirements for this hazard and its controls (frequency, responsible person, inspection checklist items)",
)

directives.widget('review_date', pattern_options={
    'date': {'format': 'DD/MM/YYYY', 'firstDay': 1}
})
review_date = schema.Date(
    title=u"Review Date",
    required=False,
    description=u"Date when this hazard assessment should be reviewed (DD/MM/YYYY format)",
)
```

#### 1.2 Hide Legacy Fields

**File:** `csc/src/csc/whs/interfaces.py`

Add directives to hide old field names (keep for backwards compatibility):

```python
# LEGACY FIELDS - Keep for backwards compatibility but hide in forms
directives.omitted('risk_likelihood')
directives.omitted('risk_consequence')
directives.omitted('risk_rating')
directives.omitted('suggested_controls')

# Keep old fields for data migration
risk_likelihood = schema.Choice(
    title=u"Risk Likelihood (Legacy)",
    required=False,
    description=u"This field is deprecated, use initial_risk_likelihood instead",
    vocabulary="csc.whs.RiskLikelihoodVocabulary",
)

risk_consequence = schema.Choice(
    title=u"Risk Consequence (Legacy)",
    required=False,
    description=u"This field is deprecated, use initial_risk_consequence instead",
    vocabulary="csc.whs.RiskConsequenceVocabulary",
)

risk_rating = schema.TextLine(
    title=u"Risk Rating (Legacy)",
    required=False,
    description=u"This field is deprecated, use initial_risk_rating instead",
)

suggested_controls = schema.Text(
    title=u"Suggested Controls (Legacy)",
    required=False,
    description=u"This field is deprecated, use recommended_controls instead",
)
```

#### 1.3 Update Catalog Indexes

**File:** `csc/src/csc/whs/profiles/default/catalog.xml`

Add new indexes for filtering/searching:

```xml
<!-- Add to existing catalog.xml -->

<!-- New hazard fields -->
<index name="location_town" meta_type="FieldIndex">
    <indexed_attr value="location_town"/>
</index>

<index name="people_at_risk" meta_type="ZCTextIndex">
    <indexed_attr value="people_at_risk"/>
</index>

<index name="initial_risk_likelihood" meta_type="FieldIndex">
    <indexed_attr value="initial_risk_likelihood"/>
</index>

<index name="initial_risk_consequence" meta_type="FieldIndex">
    <indexed_attr value="initial_risk_consequence"/>
</index>

<index name="initial_risk_rating" meta_type="FieldIndex">
    <indexed_attr value="initial_risk_rating"/>
</index>

<index name="residual_risk_likelihood" meta_type="FieldIndex">
    <indexed_attr value="residual_risk_likelihood"/>
</index>

<index name="residual_risk_consequence" meta_type="FieldIndex">
    <indexed_attr value="residual_risk_consequence"/>
</index>

<index name="residual_risk_rating" meta_type="FieldIndex">
    <indexed_attr value="residual_risk_rating"/>
</index>

<index name="control_implementation_date" meta_type="DateIndex">
    <indexed_attr value="control_implementation_date"/>
</index>

<index name="review_date" meta_type="DateIndex">
    <indexed_attr value="review_date"/>
</index>

<metadata name="location_town"/>
<metadata name="initial_risk_rating"/>
<metadata name="residual_risk_rating"/>
<metadata name="control_implementation_date"/>
<metadata name="review_date"/>
```

#### 1.4 Create Data Migration Upgrade Step

**File:** `csc/src/csc/whs/upgrades/v20.py` (NEW FILE)

```python
"""Upgrade to Profile v20 - Hazard Enhancement with Dual Risk Assessment"""

from plone import api
import logging

logger = logging.getLogger('csc.whs.upgrades.v20')


def upgrade_to_20(context):
    """
    Upgrade to profile version 20:
    - Migrate risk assessment fields (risk_* -> initial_risk_*)
    - Migrate suggested_controls -> recommended_controls
    - Add new catalog indexes
    - Reindex affected hazards
    """
    logger.info('Starting upgrade to profile v20...')

    # Update catalog
    setup = api.portal.get_tool('portal_setup')
    setup.runImportStepFromProfile(
        'profile-csc.whs:default',
        'catalog',
        run_dependencies=False
    )
    logger.info('Catalog indexes updated')

    # Migrate existing hazards
    catalog = api.portal.get_tool('portal_catalog')
    brains = catalog.searchResults(portal_type='csc.whs.hazard')

    migrated_count = 0
    for brain in brains:
        try:
            obj = brain.getObject()
            modified = False

            # Migrate risk_likelihood -> initial_risk_likelihood
            if hasattr(obj, 'risk_likelihood') and obj.risk_likelihood:
                if not hasattr(obj, 'initial_risk_likelihood') or not obj.initial_risk_likelihood:
                    obj.initial_risk_likelihood = obj.risk_likelihood
                    modified = True
                    logger.info(f'{obj.getId()}: Migrated risk_likelihood -> initial_risk_likelihood')

            # Migrate risk_consequence -> initial_risk_consequence
            if hasattr(obj, 'risk_consequence') and obj.risk_consequence:
                if not hasattr(obj, 'initial_risk_consequence') or not obj.initial_risk_consequence:
                    obj.initial_risk_consequence = obj.risk_consequence
                    modified = True
                    logger.info(f'{obj.getId()}: Migrated risk_consequence -> initial_risk_consequence')

            # Migrate risk_rating -> initial_risk_rating
            if hasattr(obj, 'risk_rating') and obj.risk_rating:
                if not hasattr(obj, 'initial_risk_rating') or not obj.initial_risk_rating:
                    obj.initial_risk_rating = obj.risk_rating
                    modified = True
                    logger.info(f'{obj.getId()}: Migrated risk_rating -> initial_risk_rating')

            # Migrate suggested_controls -> recommended_controls
            if hasattr(obj, 'suggested_controls') and obj.suggested_controls:
                if not hasattr(obj, 'recommended_controls') or not obj.recommended_controls:
                    obj.recommended_controls = obj.suggested_controls
                    modified = True
                    logger.info(f'{obj.getId()}: Migrated suggested_controls -> recommended_controls')

            if modified:
                obj.reindexObject()
                migrated_count += 1

        except Exception as e:
            logger.error(f'Error migrating hazard {brain.getId()}: {e}', exc_info=True)

    logger.info(f'Upgrade to v20 complete: {migrated_count}/{len(brains)} hazards migrated')
```

**File:** `csc/src/csc/whs/profiles/default/upgrades.zcml`

Add upgrade step registration:

```xml
<!-- Add to existing upgrades.zcml -->

<genericsetup:upgradeStep
    title="Upgrade to Profile v20 - Hazard Enhancement"
    description="Migrate risk assessment fields, add dual risk scoring, control tracking, and monitoring"
    source="19"
    destination="20"
    handler="csc.whs.upgrades.v20.upgrade_to_20"
    profile="csc.whs:default"
    />
```

**File:** `csc/src/csc/whs/profiles/default/metadata.xml`

Update version number:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <version>20</version>
  <dependencies>
    <dependency>profile-plone.app.dexterity:default</dependency>
  </dependencies>
</metadata>
```

---

### Phase 2: Form Templates & JavaScript (2-3 hours)

**Objective:** Update report-hazard form and hazard edit form to support dual risk assessment

#### 2.1 Update Report Hazard Form Template

**File:** `csc/src/csc/whs/browser/templates/report_hazard.pt`

**Changes Needed:**

1. Add `location_town` field after `location` field
2. Add `people_at_risk` field after `hazard_description`
3. Update risk assessment section to use `initial_*` fields
4. Update field labels to clarify "before controls"

**Key Sections to Update:**

```xml
<!-- Section 2: Location (add town field) -->
<div class="field">
    <label for="location_town">Town / locality of hazard <span class="required">*</span></label>
    <input type="text"
           id="location_town"
           name="location_town"
           required="required"
           placeholder="e.g., Cooktown, Laura, Rossville"
           tal:attributes="value python:request.form.get('location_town', '')" />
    <p class="help">Enter the town or locality where the hazard is located</p>
</div>

<!-- Section 3: Hazard Details (add people at risk) -->
<div class="field">
    <label for="people_at_risk">Who is at risk from this hazard?</label>
    <textarea id="people_at_risk"
              name="people_at_risk"
              rows="3"
              placeholder="e.g., depot staff, visitors to facility, contractors working on site"
              tal:content="python:request.form.get('people_at_risk', '')"></textarea>
    <p class="help">Identify the people, roles, or groups who could be affected by this hazard</p>
</div>

<!-- Section 4: Initial Risk Assessment (rename from "Risk Assessment") -->
<div class="form-section risk-assessment-section">
    <h2>Section 4: Initial Risk Assessment (Before Controls)</h2>
    <p class="section-help">
        Assess the risk of this hazard <strong>before any control measures are applied</strong>.
        After controls are implemented, the WHS Officer will complete a residual risk assessment.
    </p>

    <div class="field">
        <label for="initial_risk_likelihood">Risk Likelihood (before controls)</label>
        <select id="initial_risk_likelihood"
                name="initial_risk_likelihood"
                tal:attributes="data-selected python:request.form.get('initial_risk_likelihood', '')">
            <option value="">-- Select likelihood --</option>
            <!-- Vocabulary options populated by JavaScript -->
        </select>
        <p class="help">How likely is it that this hazard will cause an incident?</p>
    </div>

    <div class="field">
        <label for="initial_risk_consequence">Risk Consequence (before controls)</label>
        <select id="initial_risk_consequence"
                name="initial_risk_consequence"
                tal:attributes="data-selected python:request.form.get('initial_risk_consequence', '')">
            <option value="">-- Select consequence --</option>
            <!-- Vocabulary options populated by JavaScript -->
        </select>
        <p class="help">What would be the consequence if an incident occurred?</p>
    </div>

    <!-- Risk Matrix Display -->
    <div id="initial-risk-matrix-container" class="risk-matrix-container" style="display: none;">
        <h3>Calculated Initial Risk Rating</h3>
        <div id="initial-risk-matrix" class="risk-matrix"></div>
        <input type="hidden" id="initial_risk_rating" name="initial_risk_rating" value="" />
    </div>
</div>
```

#### 2.2 Update Hazard Form JavaScript

**File:** `csc/src/csc/whs/browser/static/hazard_form.js`

**Changes Needed:**

1. Update field IDs from `risk_*` to `initial_risk_*`
2. Add dual risk matrix support (initial + residual)
3. Add risk matrix calculation function
4. Add visual matrix display similar to incident form

**New JavaScript Functions:**

```javascript
// Risk Matrix Definitions (matching WHS Officer's example)
const RISK_MATRIX = {
    likelihood: {
        'rare': 1,
        'unlikely': 2,
        'possible': 3,
        'likely': 4,
        'almost_certain': 5
    },
    consequence: {
        'insignificant': 1,
        'minor': 2,
        'moderate': 3,
        'major': 4,
        'catastrophic': 5
    },
    ratings: {
        // Matrix[likelihood][consequence] = {rating, color, score}
        1: {1: {rating: 'low', color: '#90EE90', score: 'L1', label: 'Low'},
            2: {rating: 'low', color: '#90EE90', score: 'L2', label: 'Low'},
            3: {rating: 'low', color: '#90EE90', score: 'L3', label: 'Low'},
            4: {rating: 'low', color: '#90EE90', score: 'L4', label: 'Low'},
            5: {rating: 'medium', color: '#FFA500', score: 'M5', label: 'Medium'}},
        2: {1: {rating: 'low', color: '#90EE90', score: 'L2', label: 'Low'},
            2: {rating: 'low', color: '#90EE90', score: 'L4', label: 'Low'},
            3: {rating: 'medium', color: '#FFA500', score: 'M6', label: 'Medium'},
            4: {rating: 'medium', color: '#FFA500', score: 'M8', label: 'Medium'},
            5: {rating: 'medium', color: '#FFA500', score: 'M10', label: 'Medium'}},
        3: {1: {rating: 'low', color: '#90EE90', score: 'L3', label: 'Low'},
            2: {rating: 'medium', color: '#FFA500', score: 'M6', label: 'Medium'},
            3: {rating: 'medium', color: '#FFA500', score: 'M9', label: 'Medium'},
            4: {rating: 'medium', color: '#FFA500', score: 'M12', label: 'Medium'},
            5: {rating: 'high', color: '#FF0000', score: 'H15', label: 'High'}},
        4: {1: {rating: 'low', color: '#90EE90', score: 'L4', label: 'Low'},
            2: {rating: 'medium', color: '#FFA500', score: 'M8', label: 'Medium'},
            3: {rating: 'medium', color: '#FFA500', score: 'M12', label: 'Medium'},
            4: {rating: 'high', color: '#FF0000', score: 'H16', label: 'High'},
            5: {rating: 'high', color: '#FF0000', score: 'H20', label: 'High'}},
        5: {1: {rating: 'medium', color: '#FFA500', score: 'M5', label: 'Medium'},
            2: {rating: 'medium', color: '#FFA500', score: 'M10', label: 'Medium'},
            3: {rating: 'high', color: '#FF0000', score: 'H15', label: 'High'},
            4: {rating: 'high', color: '#FF0000', score: 'H20', label: 'High'},
            5: {rating: 'extreme', color: '#8B0000', score: 'H25', label: 'Extreme'}}
    }
};

/**
 * Calculate risk rating from likelihood and consequence
 */
function calculateRiskRating(likelihood, consequence) {
    if (!likelihood || !consequence) {
        return null;
    }

    const likelihoodNum = RISK_MATRIX.likelihood[likelihood];
    const consequenceNum = RISK_MATRIX.consequence[consequence];

    if (!likelihoodNum || !consequenceNum) {
        return null;
    }

    return RISK_MATRIX.ratings[likelihoodNum][consequenceNum];
}

/**
 * Update risk matrix display
 */
function updateRiskMatrix(matrixType) {
    const prefix = matrixType === 'initial' ? 'initial_risk_' : 'residual_risk_';

    const likelihoodSelect = document.getElementById(prefix + 'likelihood');
    const consequenceSelect = document.getElementById(prefix + 'consequence');
    const matrixContainer = document.getElementById(prefix.replace('_', '-') + 'matrix-container');
    const matrixDiv = document.getElementById(prefix.replace('_', '-') + 'matrix');
    const ratingInput = document.getElementById(prefix + 'rating');

    if (!likelihoodSelect || !consequenceSelect) {
        return;
    }

    const likelihood = likelihoodSelect.value;
    const consequence = consequenceSelect.value;

    if (!likelihood || !consequence) {
        matrixContainer.style.display = 'none';
        ratingInput.value = '';
        return;
    }

    const riskData = calculateRiskRating(likelihood, consequence);

    if (!riskData) {
        return;
    }

    // Update hidden field
    ratingInput.value = riskData.rating;

    // Display risk matrix
    matrixDiv.innerHTML = `
        <div class="risk-result" style="background: ${riskData.color}; color: ${riskData.rating === 'extreme' ? 'white' : 'black'}; padding: 20px; border-radius: 8px; text-align: center; margin-top: 10px;">
            <div class="risk-score" style="font-size: 2em; font-weight: bold;">${riskData.score}</div>
            <div class="risk-label" style="font-size: 1.5em; margin-top: 10px;">${riskData.label} Risk</div>
            <div class="risk-detail" style="margin-top: 10px; font-size: 0.9em;">
                ${getLikelihoodLabel(likelihood)} likelihood × ${getConsequenceLabel(consequence)} consequence
            </div>
        </div>
    `;

    matrixContainer.style.display = 'block';
}

// Initialize risk matrix listeners
document.addEventListener('DOMContentLoaded', function() {
    // Initial risk assessment listeners
    const initialLikelihood = document.getElementById('initial_risk_likelihood');
    const initialConsequence = document.getElementById('initial_risk_consequence');

    if (initialLikelihood && initialConsequence) {
        initialLikelihood.addEventListener('change', () => updateRiskMatrix('initial'));
        initialConsequence.addEventListener('change', () => updateRiskMatrix('initial'));

        // Calculate on page load if values are set
        if (initialLikelihood.value && initialConsequence.value) {
            updateRiskMatrix('initial');
        }
    }

    // Residual risk assessment listeners (for edit form only)
    const residualLikelihood = document.getElementById('residual_risk_likelihood');
    const residualConsequence = document.getElementById('residual_risk_consequence');

    if (residualLikelihood && residualConsequence) {
        residualLikelihood.addEventListener('change', () => updateRiskMatrix('residual'));
        residualConsequence.addEventListener('change', () => updateRiskMatrix('residual'));

        // Calculate on page load if values are set
        if (residualLikelihood.value && residualConsequence.value) {
            updateRiskMatrix('residual');
        }
    }
});
```

#### 2.3 Update Hazard Edit Form (Dexterity Auto-Form)

The hazard edit form is auto-generated by Dexterity. We need to create a custom edit form widget for the residual risk assessment section to show both matrices side-by-side for WHS Officers.

**File:** `csc/src/csc/whs/browser/hazard_edit.py` (NEW FILE)

```python
"""Custom hazard edit form for WHS Officers"""

from plone.dexterity.browser import edit
from csc.whs.interfaces import IHazard


class HazardEditForm(edit.DefaultEditForm):
    """Custom edit form for hazards with dual risk assessment display"""

    portal_type = 'csc.whs.hazard'
    schema = IHazard

    def updateWidgets(self):
        super(HazardEditForm, self).updateWidgets()

        # Add custom CSS class for dual matrix display
        if 'initial_risk_likelihood' in self.widgets:
            self.widgets['initial_risk_likelihood'].klass += ' risk-assessment-field'
        if 'residual_risk_likelihood' in self.widgets:
            self.widgets['residual_risk_likelihood'].klass += ' risk-assessment-field'
```

**File:** `csc/src/csc/whs/configure.zcml`

Register custom edit form:

```xml
<!-- Custom hazard edit form with dual risk assessment -->
<browser:page
    for="csc.whs.interfaces.IHazard"
    name="edit"
    class=".browser.hazard_edit.HazardEditForm"
    permission="cmf.ModifyPortalContent"
    />
```

---

### Phase 3: View Templates (1-2 hours)

**Objective:** Update hazard view template to display before/after risk comparison

#### 3.1 Update Hazard View Template

**File:** `csc/src/csc/whs/browser/templates/hazard.pt`

**Changes Needed:**

1. Add `location_town` display
2. Add `people_at_risk` display
3. Update Section 4 to show "Initial Risk Assessment (Before Controls)"
4. Add Section 5: Control Measures (conditional)
5. Add Section 6: Residual Risk Assessment (conditional)
6. Add Section 7: Monitoring & Review (conditional)
7. Display dual risk matrices side-by-side if both exist

**Key Sections to Add:**

```xml
<!-- Add after location display -->
<dt>Town / Locality</dt>
<dd tal:content="context/location_town | string:-">Cooktown</dd>

<!-- Add after hazard description -->
<dt>Who is at risk?</dt>
<dd tal:content="context/people_at_risk | string:-">Depot staff, contractors</dd>

<!-- Section 4: Initial Risk Assessment -->
<section class="hazard-section" id="initial-risk-section">
    <h2>Section 4: Initial Risk Assessment (Before Controls)</h2>

    <dl class="hazard-details">
        <dt>Likelihood (before controls)</dt>
        <dd tal:content="python: getattr(context, 'initial_risk_likelihood', '-').replace('_', ' ').title() if getattr(context, 'initial_risk_likelihood', None) else '-'">Likely</dd>

        <dt>Consequence (before controls)</dt>
        <dd tal:content="python: getattr(context, 'initial_risk_consequence', '-').replace('_', ' ').title() if getattr(context, 'initial_risk_consequence', None) else '-'">Major</dd>

        <dt>Initial Risk Rating</dt>
        <dd tal:condition="context/initial_risk_rating">
            <span tal:attributes="class python: 'risk-badge risk-' + getattr(context, 'initial_risk_rating', 'unknown')"
                  tal:content="python: getattr(context, 'initial_risk_rating', 'Unknown').upper()">
                HIGH
            </span>
        </dd>
        <dd tal:condition="not: context/initial_risk_rating">-</dd>
    </dl>

    <!-- Visual risk matrix for initial assessment -->
    <div class="risk-matrix-display" tal:condition="python: context.initial_risk_likelihood and context.initial_risk_consequence">
        <!-- Matrix visualization here -->
    </div>
</section>

<!-- Section 5: Control Measures (conditional on data) -->
<section class="hazard-section" id="control-measures-section"
         tal:condition="python: context.recommended_controls or context.immediate_actions or context.control_measures">
    <h2>Section 5: Control Measures</h2>

    <dl class="hazard-details">
        <dt tal:condition="context/recommended_controls">Recommended Controls</dt>
        <dd tal:condition="context/recommended_controls"
            tal:content="structure python: context.recommended_controls.replace('\n', '<br/>')">
            Engineering controls, Administrative procedures
        </dd>

        <dt tal:condition="context/immediate_actions">Immediate Actions Taken</dt>
        <dd tal:condition="context/immediate_actions"
            tal:content="structure python: context.immediate_actions.replace('\n', '<br/>')">
            Area cordoned off, signage installed
        </dd>

        <dt tal:condition="context/control_measures">Control Measures Applied</dt>
        <dd tal:condition="context/control_measures"
            tal:content="structure python: context.control_measures.replace('\n', '<br/>')">
            Guard installed, new procedure implemented
        </dd>

        <dt tal:condition="context/control_implementation_date">Implementation Date</dt>
        <dd tal:condition="context/control_implementation_date"
            tal:content="python: context.control_implementation_date.strftime('%d/%m/%Y')">
            15/10/2025
        </dd>
    </dl>
</section>

<!-- Section 6: Residual Risk Assessment (conditional on data) -->
<section class="hazard-section" id="residual-risk-section"
         tal:condition="python: context.residual_risk_likelihood and context.residual_risk_consequence">
    <h2>Section 6: Residual Risk Assessment (After Controls)</h2>

    <dl class="hazard-details">
        <dt>Likelihood (after controls)</dt>
        <dd tal:content="python: context.residual_risk_likelihood.replace('_', ' ').title()">Unlikely</dd>

        <dt>Consequence (after controls)</dt>
        <dd tal:content="python: context.residual_risk_consequence.replace('_', ' ').title()">Minor</dd>

        <dt>Residual Risk Rating</dt>
        <dd tal:condition="context/residual_risk_rating">
            <span tal:attributes="class python: 'risk-badge risk-' + context.residual_risk_rating"
                  tal:content="python: context.residual_risk_rating.upper()">
                LOW
            </span>
        </dd>
    </dl>

    <!-- Visual risk matrix for residual assessment -->
    <div class="risk-matrix-display">
        <!-- Matrix visualization here -->
    </div>

    <!-- Before/After Comparison -->
    <div class="risk-comparison" style="margin-top: 20px; padding: 15px; background: #f0f8ff; border-left: 4px solid #007bff;">
        <h3>Risk Reduction Achieved</h3>
        <p>
            <strong>Before Controls:</strong>
            <span tal:attributes="class python: 'risk-badge risk-' + getattr(context, 'initial_risk_rating', 'unknown')"
                  tal:content="python: getattr(context, 'initial_risk_rating', 'Unknown').upper()">HIGH</span>
            →
            <strong>After Controls:</strong>
            <span tal:attributes="class python: 'risk-badge risk-' + context.residual_risk_rating"
                  tal:content="python: context.residual_risk_rating.upper()">LOW</span>
        </p>
    </div>
</section>

<!-- Section 7: Monitoring & Review (conditional on data) -->
<section class="hazard-section" id="monitoring-section"
         tal:condition="python: context.monitoring_requirements or context.review_date">
    <h2>Section 7: Monitoring & Review</h2>

    <dl class="hazard-details">
        <dt tal:condition="context/monitoring_requirements">Monitoring Requirements</dt>
        <dd tal:condition="context/monitoring_requirements"
            tal:content="structure python: context.monitoring_requirements.replace('\n', '<br/>')">
            Monthly inspections, quarterly review
        </dd>

        <dt tal:condition="context/review_date">Next Review Date</dt>
        <dd tal:condition="context/review_date"
            tal:content="python: context.review_date.strftime('%d/%m/%Y')">
            15/04/2026
        </dd>
    </dl>
</section>

<!-- Add CSS for risk badges -->
<style>
    .risk-badge {
        padding: 4px 12px;
        border-radius: 4px;
        font-weight: 600;
        font-size: 14px;
        display: inline-block;
    }

    .risk-badge.risk-low {
        background: #90EE90;
        color: #000;
    }

    .risk-badge.risk-medium {
        background: #FFA500;
        color: #000;
    }

    .risk-badge.risk-high {
        background: #FF0000;
        color: #fff;
    }

    .risk-badge.risk-extreme {
        background: #8B0000;
        color: #fff;
    }

    .risk-comparison {
        animation: fadeIn 0.5s;
    }

    @keyframes fadeIn {
        from { opacity: 0; }
        to { opacity: 1; }
    }
</style>
```

---

### Phase 4: CSV Export Updates (30 minutes)

**Objective:** Update CSV export to use correct field names

#### 4.1 Update Hazard CSV Export

**File:** `csc/src/csc/whs/browser/hazard_listing.py`

**Changes in `_hazard_to_csv_row()` method:**

```python
def _hazard_to_csv_row(self, obj):
    """Convert hazard object to CSV row dict - UPDATED for v20 schema"""

    # ... existing helper functions ...

    # Get hazard type display (use hazard_categories)
    hazard_categories = getattr(obj, 'hazard_categories', []) or []
    if hazard_categories:
        category_names = []
        # Map category tokens to display names
        for category in hazard_categories:
            # Use vocabulary to get proper names
            category_names.append(category.replace('-', ' ').title())
        hazard_type_display = ' / '.join(category_names)
    else:
        hazard_type_display = ''

    # Get workflow state (already implemented correctly)
    try:
        wf_tool = api.portal.get_tool('portal_workflow')
        state = wf_tool.getInfoFor(obj, 'review_state')
        state_titles = {
            'submitted': 'Submitted',
            'under_review': 'Under Review',
            'controls_applied': 'Controls Applied',
            'monitoring': 'Monitoring',
            'closed': 'Closed'
        }
        workflow_state = state_titles.get(state, state.replace('_', ' ').title())
    except:
        workflow_state = ''

    # Update field mappings
    return {
        'Reference Code': getattr(obj, 'reference_code', ''),
        'Title': getattr(obj, 'title', ''),
        'Date Identified': format_date_au(getattr(obj, 'identified_date', None)),
        'Identified By Name': getattr(obj, 'identified_by_name', ''),
        'Identified By Username': getattr(obj, 'identified_by_username', ''),
        'Department': department_name,
        'Location Town': getattr(obj, 'location_town', ''),  # NOW EXISTS
        'Location Description': getattr(obj, 'location', ''),
        'GPS Latitude': getattr(obj, 'location_latitude', ''),
        'GPS Longitude': getattr(obj, 'location_longitude', ''),
        'Hazard Type': hazard_type_display,  # FROM hazard_categories
        'Hazard Description': getattr(obj, 'hazard_description', ''),
        'People at Risk': getattr(obj, 'people_at_risk', ''),  # NOW EXISTS

        # Initial Risk Assessment (renamed fields)
        'Initial Likelihood': likelihood_display,  # FROM initial_risk_likelihood
        'Initial Consequence': consequence_display,  # FROM initial_risk_consequence
        'Initial Risk Rating': getattr(obj, 'initial_risk_rating', '').upper() if getattr(obj, 'initial_risk_rating', '') else '',

        # Control Measures
        'Recommended Controls': getattr(obj, 'recommended_controls', ''),  # NOW EXISTS
        'Immediate Actions Taken': getattr(obj, 'immediate_actions', ''),  # NOW EXISTS
        'Control Measures Applied': getattr(obj, 'control_measures', ''),  # NOW EXISTS
        'Control Implementation Date': format_date_au(getattr(obj, 'control_implementation_date', None)),  # NOW EXISTS

        # Residual Risk Assessment
        'Residual Likelihood': residual_likelihood_display,  # NEW
        'Residual Consequence': residual_consequence_display,  # NEW
        'Residual Risk Rating': getattr(obj, 'residual_risk_rating', '').upper() if getattr(obj, 'residual_risk_rating', '') else '',  # NEW

        # Monitoring & Review
        'Monitoring Requirements': getattr(obj, 'monitoring_requirements', ''),  # NOW EXISTS
        'Review Date': format_date_au(getattr(obj, 'review_date', None)),  # NOW EXISTS

        'Workflow State': workflow_state,
        'Last Modified': format_date_au(obj.modified()),
    }
```

**Update fieldnames list in `export_csv()` method:**

```python
fieldnames = [
    'Reference Code',
    'Title',
    'Date Identified',
    'Identified By Name',
    'Identified By Username',
    'Department',
    'Location Town',  # NEW
    'Location Description',
    'GPS Latitude',
    'GPS Longitude',
    'Hazard Type',  # FROM hazard_categories
    'Hazard Description',
    'People at Risk',  # NEW

    # Initial Risk Assessment
    'Initial Likelihood',  # RENAMED
    'Initial Consequence',  # RENAMED
    'Initial Risk Rating',  # RENAMED

    # Control Measures
    'Recommended Controls',  # RENAMED
    'Immediate Actions Taken',  # NEW
    'Control Measures Applied',  # NEW
    'Control Implementation Date',  # NEW

    # Residual Risk Assessment
    'Residual Likelihood',  # NEW
    'Residual Consequence',  # NEW
    'Residual Risk Rating',  # NEW

    # Monitoring & Review
    'Monitoring Requirements',  # NEW
    'Review Date',  # NEW

    'Workflow State',
    'Last Modified',
]
```

---

### Phase 5: Testing (1 hour)

**Objective:** Comprehensive testing of all new functionality

#### 5.1 Test Plan

**Test Case 1: New Hazard Submission (Reporter)**
1. Navigate to /hazards/@@report-hazard
2. Fill in all fields including new `location_town` and `people_at_risk`
3. Select initial risk likelihood and consequence
4. Verify risk matrix displays with correct color coding
5. Verify initial_risk_rating is calculated correctly
6. Submit form
7. Verify hazard is created with correct reference code (HAZ-2025-NNNN)
8. Verify all fields are saved

**Test Case 2: Hazard Edit (WHS Officer)**
1. Navigate to existing hazard
2. Click "Edit" tab
3. Verify initial risk assessment fields are pre-filled
4. Add control measures in Section 5
5. Complete residual risk assessment in Section 6
6. Verify both risk matrices display
7. Add monitoring requirements and review date
8. Save changes
9. Verify all fields are saved

**Test Case 3: Hazard View (Before/After Display)**
1. Navigate to hazard with both initial and residual assessments
2. Verify Section 4 shows initial risk assessment with matrix
3. Verify Section 5 shows control measures
4. Verify Section 6 shows residual risk assessment with matrix
5. Verify before/after comparison shows risk reduction
6. Verify Section 7 shows monitoring requirements

**Test Case 4: Data Migration**
1. Run upgrade step v19 → v20
2. Verify existing hazards have risk_* fields migrated to initial_risk_*
3. Verify suggested_controls migrated to recommended_controls
4. Check logs for migration count
5. Verify no data loss

**Test Case 5: CSV Export**
1. Navigate to /hazards
2. Click "Export to CSV"
3. Open CSV in Excel
4. Verify all new columns are present with correct headers
5. Verify location_town, people_at_risk, control measures are populated
6. Verify initial and residual risk columns are correctly labeled
7. Verify no blank columns for non-existent fields

**Test Case 6: Risk Matrix Calculations**
1. Test all 25 combinations of likelihood × consequence
2. Verify correct risk ratings for each:
   - L1-L4 = Low (green)
   - M5-M12 = Medium (orange)
   - H15-H20 = High (red)
   - H25 = Extreme (dark red)
3. Verify matrix matches WHS Officer's example image

---

### Phase 6: Documentation & Deployment (30 minutes)

**Objective:** Update documentation and deploy to development server

#### 6.1 Update Documentation Files

**File:** `csc/README.md`

Add to version history:

```markdown
### Version 0.10.20 (Profile v20) - Hazard Enhancement with Dual Risk Assessment

**Date:** October 2025

**WHS Officer Request:** Before/after risk scoring with control measure tracking

**Changes:**
- Added dual risk assessment framework (initial vs residual risk)
- Added 11 new hazard fields:
  - location_town (geographic tracking)
  - people_at_risk (risk exposure identification)
  - immediate_actions, control_measures, control_implementation_date
  - residual_risk_likelihood, residual_risk_consequence, residual_risk_rating
  - monitoring_requirements, review_date
- Renamed existing risk fields to initial_* for clarity
- Enhanced risk matrix visualization with color coding (L/M/H/E)
- Added before/after risk comparison in hazard view
- Updated CSV export with all new fields and correct mappings
- Data migration: risk_* → initial_risk_*, suggested_controls → recommended_controls

**Files Modified:** 15
**Files Added:** 3 (v20.py, hazard_edit.py, updated hazard_form.js)
**Effort:** 6-8 hours
```

#### 6.2 Update PROJECT_STATUS.md

Add to recent changes:

```markdown
### Hazard Enhancement (v0.10.20, Profile v20) - October 2025

**Status:** Development / Testing
**WHS Officer Request:** Before/after risk scoring for hazard management

**Implementation:**
- Dual risk assessment framework (25-point matrix with color coding)
- Control measure tracking with implementation dates
- Monitoring and review scheduling
- Enhanced CSV export with correct field mappings
- Data migration from legacy field names

**Benefits:**
- Demonstrates effectiveness of control measures (risk reduction)
- Structured control implementation tracking
- Supports continuous improvement and monitoring
- Aligns with AS/NZS ISO 31000 risk management standard
```

#### 6.3 Deploy to Development Server

```bash
# Build package
cd /home/ceo/Development/WHSPortal/csc
python -m build

# Deploy
cd /home/ceo/Development/WHSPortal
./deploy-systemd.sh csc

# Run upgrade step
# Navigate to: Site Setup → Add-ons → csc.whs → Upgrade tab
# Click "Upgrade" button for v19 → v20

# Verify deployment
# 1. Check new hazard form has all fields
# 2. Edit existing hazard - verify migration worked
# 3. Test risk matrix calculations
# 4. Export CSV and verify columns
```

---

## Risk Assessment & Mitigation

### Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Data migration fails for existing hazards | High | Low | Robust error handling, transaction rollback, backup before upgrade |
| Field name changes break existing code | Medium | Medium | Comprehensive grep for old field names, thorough testing |
| Risk matrix calculations incorrect | High | Low | Match WHS Officer's example exactly, extensive calculation testing |
| CSV export breaks with new fields | Medium | Low | Test export before and after migration |
| Performance impact from complex calculations | Low | Low | JavaScript calculations are lightweight, no backend impact |

### User Experience Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Users confused by before/after terminology | Medium | Medium | Clear labels: "Before Controls" / "After Controls", help text |
| WHS Officers don't understand when to complete residual assessment | Medium | Medium | Only show residual fields in edit form, add guidance text |
| Too many fields overwhelm users | Low | Medium | Organize into clear sections, conditional display, progressive disclosure |
| Risk matrix colors don't match expectations | Low | Low | Use WHS Officer's exact color scheme from example image |

---

## Success Metrics

### Functional Success Criteria

- ✅ All 11 new fields can be added and saved
- ✅ Risk matrix calculations match WHS Officer's example 100%
- ✅ Data migration completes with 0% data loss
- ✅ CSV export includes all new fields with correct data
- ✅ Before/after risk comparison displays correctly
- ✅ Form validation works for all new fields

### User Acceptance Criteria

- ✅ WHS Officer can complete initial risk assessment in report form
- ✅ WHS Officer can add control measures in edit form
- ✅ WHS Officer can complete residual risk assessment in edit form
- ✅ Risk reduction is clearly visible in hazard view
- ✅ Export to Excel includes all data for risk analysis

### Business Value Metrics

- **Risk Management Effectiveness**: Ability to demonstrate risk reduction through quantified before/after scores
- **Compliance**: Alignment with AS/NZS ISO 31000 risk management standard
- **Control Tracking**: Structured approach to documenting control implementation
- **Continuous Improvement**: Monitoring requirements and review dates support ongoing hazard management
- **Data Analysis**: CSV export enables trend analysis and reporting on control effectiveness

---

## Future Enhancements (Post v0.10.20)

### Phase 7: Risk Register Integration (Future)

- Link hazards to organizational risk register
- Assign control ownership and responsibilities
- Track control implementation status (planned/in-progress/complete)
- Integration with task management system (RT)

### Phase 8: Automated Notifications (Future)

- Email alerts when review date approaches
- Notification to control owners when controls are assigned
- Escalation for overdue control implementations

### Phase 9: Dashboard & Analytics (Future)

- Before/after risk trending charts
- Control effectiveness metrics
- Hazard heatmap by department and location
- Risk reduction statistics

---

## Appendix

### A. Risk Matrix Reference (from WHS Officer Example)

**5×5 Risk Matrix:**

| Likelihood / Consequence | Insignificant | Minor | Moderate | Major | Catastrophic |
|--------------------------|---------------|-------|----------|-------|--------------|
| **Almost Certain (5)**   | M5 🟠         | M10 🟠 | H15 🔴   | H20 🔴 | H25 ⛔       |
| **Likely (4)**           | L4 🟢         | M8 🟠  | M12 🟠   | H16 🔴 | H20 🔴       |
| **Possible (3)**         | L3 🟢         | M6 🟠  | M9 🟠    | M12 🟠 | H15 🔴       |
| **Unlikely (2)**         | L2 🟢         | L4 🟢  | M6 🟠    | M8 🟠  | M10 🟠       |
| **Rare (1)**             | L1 🟢         | L2 🟢  | L3 🟢    | L4 🟢  | M5 🟠        |

**Risk Rating Categories:**
- **Low (L1-L4):** 🟢 Green - Manage by routine procedures
- **Medium (M5-M12):** 🟠 Orange - Management responsibility specified
- **High (H15-H20):** 🔴 Red - Senior management attention needed
- **Extreme (H25):** ⛔ Dark Red - Immediate action required

### B. Field Mapping Summary

| CSV Column | Old Field Name | New Field Name | Status |
|------------|----------------|----------------|--------|
| Location Town | *(none)* | location_town | NEW |
| People at Risk | *(none)* | people_at_risk | NEW |
| Likelihood | risk_likelihood | initial_risk_likelihood | RENAMED |
| Consequence | risk_consequence | initial_risk_consequence | RENAMED |
| Risk Rating | risk_rating | initial_risk_rating | RENAMED |
| Recommended Controls | suggested_controls | recommended_controls | RENAMED |
| Immediate Actions Taken | *(none)* | immediate_actions | NEW |
| Control Measures Applied | *(none)* | control_measures | NEW |
| Control Implementation Date | *(none)* | control_implementation_date | NEW |
| Residual Likelihood | *(none)* | residual_risk_likelihood | NEW |
| Residual Consequence | *(none)* | residual_risk_consequence | NEW |
| Residual Risk Rating | *(none)* | residual_risk_rating | NEW |
| Monitoring Requirements | *(none)* | monitoring_requirements | NEW |
| Review Date | *(none)* | review_date | NEW |

### C. Vocabulary Definitions

**Risk Likelihood Vocabulary** (existing):
- rare: Rare - May occur only in exceptional circumstances (< 10%)
- unlikely: Unlikely - Could occur at some time (≈ 10% & <30%)
- possible: Possible - Might occur at some time (≈ 30% & <60%)
- likely: Likely - Will probably occur in most circumstances (≈ 60% & < 90%)
- almost_certain: Almost Certain - Expected to occur (≈ 90%)

**Risk Consequence Vocabulary** (existing):
- insignificant: Insignificant - No injuries or disruptions
- minor: Minor - First aid required, minor disruption
- moderate: Moderate - Medical treatment required, moderate disruption
- major: Major - Serious injury or significant disruption
- catastrophic: Catastrophic - Death, permanent disability, or major damage

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-20 | AI Assistant | Initial implementation plan created |

**Review Status:** Draft - Pending user approval
**Approval Required:** Project Manager / WHS Officer
**Target Start Date:** TBD
**Target Completion Date:** TBD

---

*End of Implementation Plan*
