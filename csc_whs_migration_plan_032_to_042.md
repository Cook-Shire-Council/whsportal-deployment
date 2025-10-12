# CSC WHS Addon Migration Plan: Version 0.3.2 to 0.4.2

## Executive Summary

This document outlines a step-by-step plan to rebuild the CSC WHS Portal addon from the working version 0.3.2 to reach the functionality of version 0.4.2. The critical issue identified is that version 0.4.2 has a **broken package structure** that prevents it from being installed correctly in Plone 6.1.

### Critical Issue Identified
**Root Cause**: The package structure was changed from `src/csc/whs/` to `csc/whs/` but the packaging configuration (pyproject.toml) was not properly updated, resulting in an addon that cannot be installed.

## Key Differences Between Versions

### 1. Package Structure (CRITICAL)
- **v0.3.2**: Uses standard Plone structure: `src/csc/whs/`
- **v0.4.2**: Changed to non-standard structure: `csc/whs/`
- **Impact**: Package cannot be found during installation

### 2. Build Configuration
- **v0.3.2**: Complete pyproject.toml with proper package configuration
- **v0.4.2**: Incomplete pyproject.toml + separate setup.py (mixing build systems)

### 3. Installation Profile Changes
- **v0.3.2**: Direct GenericSetup import step registration in configure.zcml
- **v0.4.2**: Separate import_steps.xml file (more complex)

### 4. New Features Added in 0.4.2
- Custom permissions system
- Vocabularies for categories, severity, and injury types
- Custom workflows
- Role management (WHS Officer, Site Manager, Reporter, HR, ELT)
- Catalog indexes
- Uninstall profile handlers
- Reference code generation
- Enhanced incident schema fields

## Recommended Migration Strategy

### Phase 1: Fix Package Structure (CRITICAL - Do First)

#### Step 1.1: Restore Proper Package Structure
```
Action: Keep the src/csc/whs structure from 0.3.2
Reason: This is the standard Plone package structure
Testing: Ensure addon appears in Site Setup -> Add-ons
```

#### Step 1.2: Update Build Configuration
```
Action: Use the pyproject.toml from 0.3.2 as base
Update: Increment version to 0.4.0
Add: Any new dependencies from 0.4.2 (collective.z3cform.datagridfield)
Testing: Build package and verify it can be pip installed
```

### Phase 2: Core Functionality (Install/Uninstall)

#### Step 2.1: Simplify Installation Handler
```
Action: Start with minimal setuphandlers.py
- Add logging
- Create only the roles initially
- Remove folder/collection creation temporarily
Testing: Install addon, check logs, verify roles created
```

#### Step 2.2: Add Uninstall Profile
```
Action: Create profiles/uninstall directory
- Add minimal uninstall handler
- Test uninstall/reinstall cycle
Testing: Install, uninstall, reinstall - verify no errors
```

### Phase 3: Permissions and Security

#### Step 3.1: Add Custom Permissions
```
Action: Add permission declarations to configure.zcml
- csc.whs.AddIncident
- csc.whs.ViewIncident
- csc.whs.EditIncident
- csc.whs.ManageIncident
Testing: Verify permissions appear in ZMI security tab
```

#### Step 3.2: Implement Role Mappings
```
Action: Add rolemap.xml to profiles/default
- Map permissions to roles
Testing: Check role assignments in Site Setup
```

### Phase 4: Content Type Enhancements

#### Step 4.1: Expand Incident Schema
```
Action: Update interfaces.py incrementally
- Add basic fields first (reference_code, category, severity)
- Then add complex fields (injured_persons, witnesses)
- Finally add file attachments
Testing: Create test incidents after each field group addition
```

#### Step 4.2: Add Vocabularies
```
Action: Create vocabularies.py
- Implement CategoryVocabularyFactory
- Implement SeverityVocabularyFactory
- Implement InjuryTypeVocabularyFactory
Testing: Verify dropdowns populate in add/edit forms
```

### Phase 5: Workflow Implementation

#### Step 5.1: Create Workflow Definition
```
Action: Add workflows directory to profiles/default
- Create csc_incident_workflow.xml
- Define states and transitions
Testing: Check workflow appears in portal_workflow
```

#### Step 5.2: Bind Workflow to Content Type
```
Action: Create workflows.xml in profiles/default
- Bind csc.whs.incident to csc_incident_workflow
Testing: Create incident, verify workflow states available
```

### Phase 6: Catalog and Search

#### Step 6.1: Add Catalog Indexes
```
Action: Create catalog.xml in profiles/default
- Add indexes for searchable fields
- Add metadata columns
Testing: Reindex catalog, verify search works
```

#### Step 6.2: Create Collections
```
Action: Update setuphandlers.py
- Add collection creation logic
- Create predefined queries
Testing: Verify collections display correct incidents
```

### Phase 7: UI and Templates

#### Step 7.1: Update View Templates
```
Action: Update browser/templates/incident.pt
- Add new field displays
- Implement workflow state indicators
Testing: View incidents, verify all fields display
```

#### Step 7.2: Enhance Intake Form
```
Action: Update browser/intake.py
- Add email notification logic
- Implement reference code generation
Testing: Submit test incidents via intake form
```

## Testing Protocol for Each Step

### After Each Step:
1. **Build Package**: `./create_package.sh`
2. **Install in Test Instance**: `pip install csc.whs-{version}.zip`
3. **Restart Plone**: `./bin/instance restart`
4. **Check Logs**: Look for any errors during startup
5. **Install Addon**: Site Setup -> Add-ons -> Install csc.whs
6. **Verify Functionality**: Test the specific feature added
7. **Uninstall Test**: Ensure clean uninstall
8. **Document Issues**: Note any problems encountered

## Risk Mitigation

### Backup Strategy
- Keep 0.3.2 as fallback
- Create incremental versions (0.3.3, 0.3.4, etc.)
- Test each version thoroughly before proceeding

### Common Pitfalls to Avoid
1. **Don't change package structure** - Keep src/csc/whs
2. **Don't mix build systems** - Use either pyproject.toml OR setup.py, not both
3. **Test installation after every change** - Don't accumulate untested changes
4. **Keep import steps simple** - Complex logic in setuphandlers causes silent failures
5. **Log everything** - Add extensive logging to debug installation issues

## Implementation Timeline

### Week 1: Foundation (Steps 1-2)
- Fix package structure
- Ensure basic install/uninstall works
- **Deliverable**: Version 0.3.3 with working install/uninstall

### Week 2: Security (Steps 3-4)
- Add permissions and roles
- Expand content type schema
- **Deliverable**: Version 0.3.4 with enhanced schema

### Week 3: Workflow (Steps 5-6)
- Implement custom workflow
- Add catalog configuration
- **Deliverable**: Version 0.3.5 with workflow

### Week 4: UI and Polish (Step 7)
- Update templates
- Add email notifications
- Final testing
- **Deliverable**: Version 0.4.0 matching original requirements

## Validation Checklist

Before considering migration complete, verify:

- [ ] Addon appears in Site Setup -> Add-ons
- [ ] Can install without errors
- [ ] Can uninstall cleanly
- [ ] Can reinstall after uninstall
- [ ] All roles created (WHS Officer, Site Manager, Reporter, HR, ELT)
- [ ] Incident content type available
- [ ] All fields present in add/edit forms
- [ ] Workflow states functional
- [ ] Collections display incidents correctly
- [ ] Email notifications sent on submission
- [ ] Reference codes generated (INC-YYYY-00001)
- [ ] File attachments working
- [ ] Search/catalog indexing functional
- [ ] No errors in instance.log during any operation

## Conclusion

The primary issue with version 0.4.2 is the broken package structure. By maintaining the correct structure from 0.3.2 and incrementally adding features with thorough testing at each step, we can achieve all the functionality of 0.4.2 while maintaining a working, installable addon.

The key to success is:
1. **Never break the package structure**
2. **Test installation after every change**
3. **Add features incrementally**
4. **Keep detailed logs**
5. **Maintain fallback versions**

This methodical approach will ensure we reach Phase 1 requirements while maintaining a stable, installable addon throughout the development process.