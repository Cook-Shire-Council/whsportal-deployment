# Phase 2: WHS Incident Form Enhancement - Implementation Plan

**Version**: csc.whs 0.10.3 → 0.11.x
**Status**: Planning / In Progress
**Started**: 2025-10-15
**Phase 1 Complete**: 2025-10-15 (v0.10.3)

## Executive Summary

Phase 2 focuses on improving the user experience and visual presentation of the Phase 1 enhancements while maintaining the functional completeness achieved. The primary goals are to make the form more intuitive, visually appealing, and easier to use, particularly for the 38 body area selections.

---

## Phase 2 Goals (Priority Order)

### **1. Enhanced CSS Checkbox Grid Layout** 🔥 **HIGHEST PRIORITY**
**Status**: In Progress
**Effort**: Low
**Impact**: Medium
**Priority**: Changed from High to HIGHEST

**Why Highest Priority:**
- Low implementation effort
- Immediate visual improvement
- Better use of screen space
- Test bed for evaluating need for SVG body map
- Can be deployed quickly for user feedback

### **2. SVG Body Map Visual Component**
**Status**: Planning (Pending feedback on grid layout)
**Effort**: Medium-High
**Impact**: High
**Priority**: High (Deferred until grid layout evaluated)

**Decision Point:** Implement grid layout first, then evaluate with WHS Office whether SVG body map is necessary or if grid layout is sufficient.

### **3. Hide Legacy Fields from Dexterity Forms**
**Status**: Planning
**Effort**: Low
**Impact**: Low-Medium
**Priority**: Medium

### **4. Conditional Field Visibility Enhancement**
**Status**: Planning
**Effort**: Medium
**Impact**: Medium
**Priority**: Low

### **5. Additional Fieldset Organization**
**Status**: Planning
**Effort**: Medium
**Impact**: Medium
**Priority**: Low

---

## Feature 1: Enhanced CSS Checkbox Grid Layout

### Overview
Improve the display of checkbox lists for better scannability and space efficiency.

### Target Fields
1. **Injury Body Areas** (38 checkboxes) - Section 4
2. **Injury Classifications** (13 checkboxes) - Section 4
3. **Property Damage Types** (9 checkboxes) - Section 5

### Current State
- Checkboxes displayed as vertical list
- Each checkbox on its own line
- Takes up significant vertical space
- Difficult to scan quickly
- Not optimized for horizontal screen space

### Proposed Implementation

#### CSS Changes
Create multi-column grid layout with the following features:

**Grid Container:**
```css
.whs-checkbox-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 8px;
    max-height: 400px;
    overflow-y: auto;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    background-color: #f9f9f9;
}
```

**Grid Items:**
```css
.whs-checkbox-grid .whs-checkbox-label {
    margin: 0;
    padding: 6px 10px;
    background: #ffffff;
    border: 1px solid #e0e0e0;
    border-radius: 3px;
    cursor: pointer;
    transition: all 0.2s ease;
}

.whs-checkbox-grid .whs-checkbox-label:hover {
    background: #e8f4f8;
    border-color: #007bff;
}

.whs-checkbox-grid .whs-checkbox-label input[type="checkbox"] {
    margin-right: 6px;
}

.whs-checkbox-grid .whs-checkbox-label input[type="checkbox"]:checked + span {
    font-weight: 600;
    color: #007bff;
}
```

**Responsive Breakpoints:**
```css
/* Mobile: Single column */
@media (max-width: 576px) {
    .whs-checkbox-grid {
        grid-template-columns: 1fr;
        max-height: 300px;
    }
}

/* Tablet: Two columns */
@media (min-width: 577px) and (max-width: 768px) {
    .whs-checkbox-grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

/* Desktop: Auto-fill based on 200px minimum */
@media (min-width: 769px) {
    .whs-checkbox-grid {
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    }
}
```

#### Files to Modify
1. **`src/csc/whs/browser/static/incident_form.css`**
   - Add `.whs-checkbox-grid` styles
   - Add responsive breakpoints
   - Add hover/checked states

2. **`src/csc/whs/browser/templates/report_incident.pt`** (Already has classes)
   - Verify `whs-checkbox-grid` class is applied to:
     - Injury body areas container (line ~497)
     - Injury classifications container (line ~520)
     - Property damage types container (line ~636)

### Expected Benefits
- ✅ **Better space utilization**: 2-4 columns instead of 1
- ✅ **Improved scannability**: Related options grouped visually
- ✅ **Faster selection**: Less scrolling required
- ✅ **Professional appearance**: Modern grid layout
- ✅ **Mobile responsive**: Adapts to screen size
- ✅ **Quick deployment**: CSS-only change, no JavaScript

### Testing Requirements
1. **Desktop (1920x1080):**
   - Should show 3-4 columns
   - Max height 400px with scroll if needed
   - Hover effects working

2. **Tablet (768x1024):**
   - Should show 2-3 columns
   - Touch targets adequate (min 44x44px)

3. **Mobile (375x667):**
   - Should show 1 column
   - Max height 300px with scroll
   - Easy touch selection

4. **All Devices:**
   - Checked items visually distinct
   - Border/background colors appropriate
   - Scrolling smooth if needed

### Deployment Steps
1. Update CSS file
2. Build and deploy v0.10.4 (minor version bump)
3. Test on whsportaldev
4. Gather feedback from WHS Office
5. Evaluate need for SVG body map based on feedback

### Success Metrics
- Reduced vertical space usage (target: 50% reduction)
- Positive feedback from WHS Office on usability
- No accessibility regressions
- Mobile usability maintained or improved

---

## Feature 2: SVG Body Map Visual Component

### Status: DEFERRED
**Decision:** Implement after grid layout is deployed and evaluated.

### Evaluation Criteria
Proceed with SVG body map if:
- WHS Office finds 38 checkboxes difficult even with grid layout
- Feedback indicates visual selection would be significantly better
- Medical accuracy requires anatomical diagram
- Time/resources available for medium-high effort implementation

### Proposed Implementation (When/If Approved)

#### Technical Approach
1. **Source SVG Diagrams:**
   - Front and back human body outline
   - Anatomically accurate regions
   - Scalable vector graphics
   - License-compliant (open source or purchased)

2. **Widget Development:**
   - Custom z3c.form widget class
   - Extends plone.app.z3cform base widget
   - Renders SVG with clickable regions
   - Syncs with hidden checkbox inputs

3. **JavaScript Functionality:**
   - Click to select/deselect body region
   - Hover highlights with body part name
   - Touch-friendly for mobile (min 44x44px targets)
   - Keyboard navigation support (accessibility)
   - Visual feedback for selected regions (color change)

4. **Fallback Mechanism:**
   - "Use list view" toggle for accessibility
   - Checkbox grid as fallback
   - Screen reader announces selections

#### Files to Create/Modify
**New Files:**
- `src/csc/whs/widgets.py` - BodyMapWidget class
- `src/csc/whs/browser/static/body_map.js` - Interactive functionality
- `src/csc/whs/browser/static/body_map.css` - SVG styling
- `src/csc/whs/browser/static/body_diagram_front.svg` - Front view
- `src/csc/whs/browser/static/body_diagram_back.svg` - Back view

**Modified Files:**
- `src/csc/whs/interfaces.py` - Apply widget directive
- `src/csc/whs/configure.zcml` - Register widget
- `src/csc/whs/browser/anonymous.py` - Render body map in anonymous form

#### SVG Region Mapping
Map 38 vocabulary terms to SVG regions:
```python
BODY_MAP_REGIONS = {
    'head-front': 'Head (front)',
    'head-back': 'Head (back)',
    'neck': 'Neck',
    'shoulder-left': 'Shoulder (left)',
    'shoulder-right': 'Shoulder (right)',
    # ... (all 38 regions)
}
```

#### Expected Effort
- SVG sourcing/creation: 4-8 hours
- Widget development: 8-12 hours
- JavaScript implementation: 6-10 hours
- Testing & accessibility: 4-6 hours
- **Total: 22-36 hours**

---

## Feature 3: Hide Legacy Fields from Dexterity Forms

### Overview
Hide deprecated fields from authenticated user forms while keeping them in the schema for backwards compatibility.

### Implementation
Add omitted directives to `src/csc/whs/interfaces.py`:

```python
from plone.autoform import directives

# Hide legacy fields from forms (keep in schema for data)
directives.omitted('injury_type')
directives.omitted('body_part')
directives.omitted('treatment')
directives.omitted('equipment_plant')
directives.omitted('property_damage')
```

### Considerations
- Fields remain in schema (backwards compatible)
- Existing data preserved
- May want conditional display for old incidents
- Anonymous form unaffected (doesn't use these fields)

### Effort: 30 minutes
### Impact: Cleaner authenticated forms

---

## Feature 4: Conditional Field Visibility Enhancement

### Current State (Phase 1)
✅ Sections auto-skip based on incident type
✅ Injury section shows only for FAI/LTI/MTI
✅ Property damage section shows only when selected

### Potential Enhancements
1. Visual indicators for skipped sections
2. "Why am I seeing this?" tooltips
3. Summary of completed/skipped sections
4. Smoother animations/transitions
5. "Show all sections" override option

### Effort: 4-6 hours
### Impact: Incremental UX improvement

---

## Feature 5: Additional Fieldset Organization

### Proposed Improvements
1. Collapsible subsections within main sections
2. Progress indicators for multi-field groups
3. Field dependency visualization
4. Help text expand/collapse
5. "Quick tips" sidebar

### Technical Approach
- Use plone.autoform fieldsets
- Custom CSS for collapsible sections
- JavaScript for enhanced interactions
- Optional: progress bars per section

### Effort: 6-10 hours
### Impact: Better organization for complex forms

---

## Implementation Timeline

### Phase 2.1 - Grid Layout (Week 1) ⏳ **IN PROGRESS**
- **Day 1:** Implement CSS grid layout
- **Day 1-2:** Deploy and test on whsportaldev
- **Day 2-3:** Gather WHS Office feedback
- **Day 3:** Document results and decide on SVG body map

### Phase 2.2 - Legacy Field Cleanup (Week 1-2)
- **Day 1:** Add omitted directives
- **Day 1:** Test authenticated forms
- **Day 1:** Deploy

### Phase 2.3 - SVG Body Map (Week 2-4) *IF APPROVED*
- **Week 2:** Source/create SVG diagrams
- **Week 3:** Develop widget and JavaScript
- **Week 4:** Testing and deployment

### Phase 2.4 - Polish (Week 4-5) *OPTIONAL*
- Conditional visibility enhancements
- Fieldset organization improvements
- User testing refinements

---

## Version Planning

| Version | Features | Status |
|---------|----------|--------|
| 0.10.3 | Phase 1 complete | ✅ Deployed |
| 0.10.4 | Grid layout CSS | 🔄 In Progress |
| 0.10.5 | Hide legacy fields | 📋 Planned |
| 0.11.0 | SVG body map (if approved) | ⏸️ Pending evaluation |
| 0.11.x | Additional polish | 📋 Planned |

---

## Decision Points

### Immediate Decisions
1. ✅ **Grid Layout First:** Implement before SVG body map
2. ⏳ **Evaluate Grid Layout:** Get user feedback before proceeding with SVG

### Pending Decisions
1. **SVG Body Map:** Proceed based on grid layout feedback
2. **Legacy Field Visibility:** Hide completely or show in advanced mode?
3. **Polish Features:** Which enhancements provide best ROI?

### Deferred from Phase 1
- ❌ **Australian Date Format:** Too complex, deferred indefinitely

---

## Risk Assessment

### Low Risk
- ✅ Grid layout CSS (easy rollback)
- ✅ Hide legacy fields (schema unchanged)

### Medium Risk
- ⚠️ SVG body map (complex, accessibility concerns)
- ⚠️ Conditional visibility changes (could confuse users)

### Mitigation Strategies
1. Deploy incrementally (one feature at a time)
2. Test thoroughly on dev server
3. Get WHS Office feedback early
4. Maintain rollback capability
5. Document all changes

---

## Success Criteria

### Phase 2.1 (Grid Layout)
- ✅ Deployed to whsportaldev
- ✅ 38 checkboxes display in multi-column grid
- ✅ Responsive on mobile/tablet/desktop
- ✅ WHS Office feedback positive
- ✅ No accessibility regressions

### Phase 2 Overall
- ✅ Improved form usability (user feedback)
- ✅ Reduced completion time (if measurable)
- ✅ Positive WHS Office reception
- ✅ No data loss or compatibility issues
- ✅ Maintained accessibility standards

---

## Stakeholder Communication

### WHS Office Feedback Points
1. **After Grid Layout:** Is this sufficient or do we need visual body map?
2. **After Feature Completion:** Overall form usability assessment
3. **Ongoing:** Any pain points or suggestions

### IT Team Review
- Code review for CSS changes
- Security review for any JavaScript changes
- Performance testing for larger datasets

---

## Open Questions

1. **Grid Layout Columns:**
   - Is 200px minimum column width appropriate?
   - Should we adjust based on label length?

2. **SVG Body Map:**
   - Source existing diagram or create custom?
   - Front/back views sufficient or need side views?
   - How to handle ambiguous regions (e.g., "shoulder" vs specific muscles)?

3. **Mobile Experience:**
   - Is scrollable grid acceptable on mobile?
   - Should mobile have different layout entirely?

4. **Accessibility:**
   - Do we need high-contrast mode?
   - Screen reader testing required?

---

## References

- **Phase 1 Documentation:** `INCIDENT_FORM_PHASE1_CHANGES.md`
- **Phase 1 Deployment Summary:** `ANONYMOUS_FORM_UPDATE_SUMMARY.md`
- **Project Status:** `PROJECT_STATUS.md`
- **Microsoft Forms Reference:** Original PDFs in project root

---

**Last Updated:** 2025-10-15
**Next Review:** After grid layout deployment
**Owner:** Cook Shire Council IT Department
