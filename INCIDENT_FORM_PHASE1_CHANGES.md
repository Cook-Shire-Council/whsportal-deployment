# Incident Form Enhancement - Phase 1 Changes

**Version**: csc.whs 0.10.0 (Profile v17)
**Date**: 2025-10-15
**Status**: Ready for Testing

## Overview

Phase 1 adds all missing fields from the Microsoft Forms incident report to match the complete WHS Officer requirements. This implements Questions 16-28 from the three additional form pages that were previously missing.

## Changes Made

### 1. New Vocabularies Added

#### Injury Detail Vocabularies
- **InjuryBodyAreaVocabulary**: 38 specific anatomical locations with left/right differentiation
  - Supports future body map visual component (Phase 2)
  - Examples: "Ankle (left)", "Hand (right front / palm side)", "Back (upper)"

- **InjuryClassificationVocabulary**: 13 medical injury classifications
  - Amputation, Burn, Fracture, Heat stress, Infectious disease
  - Intercranial, Internal organ, Joint/ligament/muscle/tendon
  - Respiratory, Nerve/spinal cord, Superficial, Wound/laceration, Other

- **YesNoUncertainVocabulary**: For first aid and medical treatment questions

#### Property Damage Vocabularies
- **PropertyDamageTypeVocabulary**: 9 property damage categories
  - Council Plant/Vehicle, Power Tools, Buildings, Safety Equipment
  - Signage, Services, Other

- **YesNoVocabulary**: For vehicle damage report completion tracking

### 2. New Schema Fields - Injury Detail Section

Corresponds to INCIDENT_REPORT_injury_detail.pdf (Q16-Q23):

| Field | Type | Description |
|-------|------|-------------|
| `injury_body_areas` | List (multi-select) | Q16: Select area(s) of injury (38 options) |
| `injury_classifications` | List (multi-select) | Q17: Injury classification (13 types) |
| `first_aid_given` | Choice | Q18: Was First Aid given? (Yes/No/Uncertain) |
| `first_aid_provider` | TextLine | Q19: Who provided first aid? |
| `first_aid_description` | Text | Q20: What first aid was provided? |
| `medical_treatment_sought` | Choice | Q21: Was medical treatment sought? (Yes/No/Uncertain) |
| `emergency_services_called` | Bool | Q22: Were emergency services called? |
| `medical_treatment_location` | Text | Q23: Where was medical treatment provided? |

**Legacy fields preserved**: `injury_type`, `body_part`, `treatment` (marked as deprecated but kept for backwards compatibility)

### 3. New Schema Fields - Property Damage Section

Corresponds to INCIDENT_REPORT_property_plant_damage.pdf (Q24-Q26):

| Field | Type | Description |
|-------|------|-------------|
| `property_damage_types` | List (multi-select) | Q24: Type of property damaged (9 categories) |
| `property_damage_detail` | Text | Q25: Further detail of property damaged |
| `vehicle_damage_report_completed` | Choice | Q26: Vehicle Damage Report completed? (Yes/No) |

**Legacy fields preserved**: `equipment_plant`, `property_damage` (marked as deprecated)

### 4. New Schema Fields - Preliminary Observations Section

Corresponds to INCIDENT_REPORT_corrective_actions.pdf (Q27-Q28):

| Field | Type | Description |
|-------|------|-------------|
| `contributing_factors_identified` | Text | Q27: Contributing factors to incident |
| `preventative_actions_suggested` | Text | Q28: Suggested preventative/corrective actions |

**Note**: These are reporter-facing fields, separate from the WHS Officer investigation fields (`root_cause` and `corrective_actions`)

### 5. Australian Date Format Implementation

**Applied to all datetime fields**:
- `occurred_at` (Incident)
- `reported_at` (Incident)
- `identified_date` (Hazard)

**Format**: DD/MM/YYYY HH:mm (24-hour time)
**Week start**: Monday (Australian standard)
**Implementation**: Widget pattern_options directive in schema

### 6. Version Updates

- **Package version**: 0.9.20 → 0.10.0
- **Profile version**: 16 → 17
- **Upgrade step**: v16 → v17 created with reindexing logic

## Files Modified

### Core Schema and Vocabularies
1. `csc/src/csc/whs/interfaces.py` - Added 11 new fields to IIncident schema
2. `csc/src/csc/whs/vocabularies.py` - Added 5 new vocabulary factories
3. `csc/src/csc/whs/configure.zcml` - Registered 5 new vocabularies
4. `csc/src/csc/whs/widgets.py` - Created Australian date widget (for future use)

### Version Control and Upgrades
5. `csc/pyproject.toml` - Bumped version to 0.10.0
6. `csc/src/csc/whs/profiles/default/metadata.xml` - Profile version 16 → 17
7. `csc/src/csc/whs/profiles/default/upgrades.zcml` - Added v17 upgrade step
8. `csc/src/csc/whs/upgrades/v17.py` - Upgrade handler for v16 → v17

## Deployment Instructions

### 1. Build the Package

```bash
cd /home/ceo/Development/WHSPortal
./deploy.sh csc --no-restart
```

### 2. Deploy to Dev Server

Package will be automatically copied to whsportaldev and installed.

### 3. Restart Plone Instance

```bash
ssh whsportaldev
sudo systemctl restart plone.service
# OR if using screen session:
# screen -r plone
# Ctrl+C to stop, then restart with start command
```

### 4. Run the Upgrade Step

1. Navigate to: https://whsportal.cook.qld.gov.au/portal_setup
2. Go to "Upgrades" tab
3. Select profile "csc.whs"
4. Click "Show old upgrades" if needed
5. Run upgrade from v16 to v17
6. Verify success in upgrade log

### 5. Verify New Fields

1. Navigate to an existing incident or create a new one
2. Edit the incident
3. Verify new fieldsets are visible:
   - Injury Detail section with body areas and classifications
   - Property Damage section with types and detail
   - Preliminary Observations section
4. Check that date fields show DD/MM/YYYY format

## Testing Checklist

- [ ] Package builds without errors
- [ ] Package installs on dev server
- [ ] Plone instance starts without errors
- [ ] Upgrade step v16 → v17 runs successfully
- [ ] Existing incidents are not affected (no data loss)
- [ ] New incident form shows all new fields
- [ ] Date fields display in DD/MM/YYYY format
- [ ] Multi-select fields (body areas, injury classifications, property types) work
- [ ] First aid yes/no/uncertain dropdown works
- [ ] Medical treatment yes/no/uncertain dropdown works
- [ ] Emergency services checkbox works
- [ ] Vehicle damage report yes/no dropdown works
- [ ] All text fields accept input
- [ ] Legacy fields still function (if visible)
- [ ] Form saves successfully with new fields populated
- [ ] Saved data displays correctly in view mode

## Known Limitations (Phase 1)

1. **No Body Map Visual**: The `injury_body_areas` field currently displays as checkboxes. The interactive SVG body map will be implemented in Phase 2.

2. **No Conditional Visibility**: All sections are always visible. Conditional display (e.g., show injury section only when injury reported) will be added in Phase 2 if needed.

3. **No Fieldset Organization**: Fields appear in schema order. Custom fieldset grouping for better UX will be considered in Phase 2.

## Phase 2 Planning

Next steps after Phase 1 testing is successful:

1. **SVG Body Map Component**
   - Create or source front/back body diagram SVG
   - Build custom widget for interactive selection
   - Add JavaScript for click-to-select functionality
   - Add fallback checkbox list for accessibility

2. **Conditional Field Visibility** (optional)
   - Show injury section only when injury type selected
   - Show property damage section only when property damage type selected
   - Improve form flow and reduce clutter

3. **Fieldset Organization** (optional)
   - Group related fields into collapsible fieldsets
   - Improve mobile responsiveness
   - Add help text and tooltips

## Backwards Compatibility

This upgrade is **100% backwards compatible**:

- All existing data is preserved
- Legacy fields (`injury_type`, `body_part`, `treatment`, `equipment_plant`, `property_damage`) remain functional
- No data migration required
- Existing incidents can be edited and saved
- New fields are optional (not required)

## Support

For issues or questions:
- Check Plone instance logs: `/opt/plone/instance/var/log/instance.log`
- Check upgrade logs in portal_setup
- Contact: Manager of Information and Communication, Cook Shire Council
