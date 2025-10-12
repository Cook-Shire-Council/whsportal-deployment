 CSC.WHS Revised Anonymous Incident Reporting Implementation Plan

  Phase 7, Step 2: Anonymous Form Building on Existing intake.py

  Overview

  Leverage the existing intake.py bridge to enable anonymous incident reporting by enhancing its capabilities and creating a mobile-friendly form interface.

  ---
  Step 7.2.1: Enhance intake.py Field Mapping

  Version: 0.7.4

  Implementation Tasks:

  1. Add field mappings for all 20+ incident fields
  2. Handle vocabulary field values (map display values to stored values)
  3. Add datetime parsing for occurred_at and reported_at
  4. Set default values for missing fields
  5. Add logging for debugging

  Files to Modify:

  - src/csc/whs/browser/intake.py
  - README.md - Document changes

  Enhanced Field Mappings:

  # Existing fields (keep):
  - title, description, occurred_at, location, severity, category

  # Add new field mappings:
  - reported_at (default to now)
  - immediate_actions
  - persons_involved
  - witnesses
  - injury_type
  - body_part
  - treatment
  - equipment_plant
  - property_damage
  - root_cause
  - corrective_actions
  - notifiable_to_regulator
  - regulator_reference
  - confidential
  - reference_code (auto-generate)

  Testing Checklist:

  - All fields map correctly from form data
  - Vocabulary fields accept both values and labels
  - DateTime parsing handles multiple formats
  - Missing fields don't cause errors
  - Logging provides useful debugging info

  ---
  Step 7.2.2: Add Anonymous Reporter Handling

  Version: 0.7.5

  Implementation Tasks:

  1. Detect anonymous vs authenticated submissions
  2. Store reporter contact info in annotations
  3. Set appropriate workflow state for anonymous
  4. Generate reference codes for tracking
  5. Add permission checks for anonymous access

  Files to Modify:

  - src/csc/whs/browser/intake.py - Add anonymous handling
  - src/csc/whs/configure.zcml - Update permissions

  Anonymous Data Storage:

  # Store in annotations:
  - reporter_name (from form)
  - reporter_email (from form)
  - reporter_phone (from form)
  - submission_ip (from request)
  - submission_timestamp

  # Workflow handling:
  - Anonymous → state: "reported"
  - Authenticated → state: "reported" + owner role

  Testing Checklist:

  - Anonymous can access @@whs-intake
  - Reporter info stored in annotations
  - Reference code generated and returned
  - Workflow state set correctly
  - Anonymous cannot view created incident

  ---
  Step 7.2.3: Implement File Upload Handling

  Version: 0.7.6

  Implementation Tasks:

  1. Accept file uploads in intake.py
  2. Map to photo_1, photo_2, photo_3 fields
  3. Validate file types and sizes
  4. Handle multiple file scenarios
  5. Add virus scanning hook (if available)

  Files to Modify:

  - src/csc/whs/browser/intake.py - Add file processing

  File Handling Logic:

  # Process uploads:
  - Extract from request.form['photo_1'] etc.
  - Or from request.form['files'] array
  - Create NamedBlobFile objects
  - Attach to incident object
  - Validate: images only, max 10MB each
  - Generate thumbnails if needed

  Testing Checklist:

  - Single file upload works
  - Multiple files handled correctly
  - File size limits enforced
  - Invalid file types rejected
  - Files attached to incident object

  ---
  Step 7.2.4: Create Mobile-Friendly HTML Form

  Version: 0.7.7

  Implementation Tasks:

  1. Create responsive HTML form template
  2. Implement multi-step navigation (JavaScript)
  3. Add client-side validation
  4. Include camera integration for mobile
  5. Add offline detection

  Files to Create:

  - src/csc/whs/browser/templates/incident_form.pt
  - src/csc/whs/browser/static/incident_form.css
  - src/csc/whs/browser/static/incident_form.js
  - src/csc/whs/browser/views.py - Form view class

  Form Structure:

  Step 1: What Happened
  - occurred_at (datetime-local input)
  - location (select with vocabulary)
  - category (select with vocabulary)
  - severity (select with vocabulary)
  - description (textarea)

  Step 2: People Involved
  - reporter_name (required)
  - reporter_email (required)
  - reporter_phone (optional)
  - persons_involved (textarea)
  - witnesses (textarea)

  Step 3: Incident Details
  - [Conditional fields based on category]
  - injury_type, body_part, treatment
  - equipment_plant, property_damage
  - immediate_actions

  Step 4: Evidence
  - photo_1, photo_2, photo_3 (file inputs)
  - Additional notes

  Step 5: Review & Submit
  - Summary of entered data
  - Edit buttons for each section
  - Submit button

  Testing Checklist:

  - Form displays correctly on mobile
  - Navigation between steps works
  - Validation prevents incomplete submission
  - Camera capture works on mobile
  - Form submits to @@whs-intake

  ---
  Step 7.2.5: Add Success & Error Handling

  Version: 0.7.8

  Implementation Tasks:

  1. Create success confirmation page
  2. Display reference number prominently
  3. Implement error handling and display
  4. Add email confirmation option
  5. Provide print-friendly confirmation

  Files to Create/Modify:

  - src/csc/whs/browser/templates/incident_success.pt
  - src/csc/whs/browser/templates/incident_error.pt
  - src/csc/whs/browser/intake.py - Return success/error views

  Success Flow Enhancement:

  # intake.py returns:
  - Success: Redirect to success page with reference
  - Error: Display error page with form data retained
  - Include QR code for reference number
  - Option to email/SMS confirmation

  Testing Checklist:

  - Success page shows reference number
  - Error messages are helpful
  - Form data preserved on error
  - Confirmation can be printed
  - Email confirmation works

  ---
  Step 7.2.6: Optimize intake.py Performance

  Version: 0.7.9

  Implementation Tasks:

  1. Add caching for vocabulary lookups
  2. Implement async file processing
  3. Add rate limiting for anonymous
  4. Optimize database writes
  5. Add monitoring hooks

  Files to Modify:

  - src/csc/whs/browser/intake.py
  - src/csc/whs/configure.zcml

  Performance Enhancements:

  # Add to intake.py:
  - Vocabulary caching (RAM cache)
  - Batch field updates
  - Async file processing for large uploads
  - Rate limiting: 5 submissions per IP/hour
  - Performance logging

  Testing Checklist:

  - Form submission < 2 seconds
  - Large files don't block response
  - Rate limiting prevents spam
  - Vocabularies cached properly
  - No memory leaks

  ---
  Step 7.2.7: Add Notification System

  Version: 0.8.0

  Implementation Tasks:

  1. Send email to WHS Officer on submission
  2. SMS notification option (if configured)
  3. Dashboard notification for new incidents
  4. Configurable escalation rules
  5. Confirmation to reporter (if email provided)

  Files to Create/Modify:

  - src/csc/whs/notifications.py - Notification module
  - src/csc/whs/browser/intake.py - Trigger notifications
  - src/csc/whs/profiles/default/registry.xml - Config settings

  Notification Features:

  # Notifications sent:
  - WHS Officer: Immediate email with severity flag
  - Site Manager: Daily digest
  - Reporter: Confirmation with reference
  - Escalation: Critical incidents to ELT

  Testing Checklist:

  - WHS Officer receives notifications
  - Reporter confirmations sent
  - Escalation rules work
  - Notifications configurable
  - No duplicate notifications

  ---
  Step 7.2.8: Security Hardening

  Version: 0.8.1

  Implementation Tasks:

  1. Add CSRF protection
  2. Implement CAPTCHA for anonymous
  3. Add honeypot fields
  4. Secure file upload validation
  5. Add audit logging

  Files to Modify:

  - src/csc/whs/browser/intake.py
  - src/csc/whs/browser/templates/incident_form.pt
  - src/csc/whs/security.py - Security utilities

  Security Measures:

  # Implement:
  - CSRF token validation
  - reCAPTCHA after 2 attempts
  - Honeypot fields (hidden from users)
  - File type whitelist (images only)
  - Audit log all submissions
  - IP-based rate limiting

  Testing Checklist:

  - CSRF protection active
  - CAPTCHA displays correctly
  - Honeypot catches bots
  - Malicious files rejected
  - Audit trail complete

  ---
  Step 7.2.9: Integration Testing & Documentation

  Version: 0.8.2

  Implementation Tasks:

  1. Comprehensive test suite
  2. User documentation
  3. Admin guide
  4. API documentation for intake.py
  5. Performance benchmarks

  Files to Create:

  - src/csc/whs/tests/test_intake.py
  - src/csc/whs/tests/test_anonymous_form.py
  - docs/anonymous_submission_guide.md
  - docs/intake_api.md

  Test Coverage:

  # Test scenarios:
  - Anonymous submission end-to-end
  - All field mappings
  - File upload edge cases
  - Error handling
  - Performance under load
  - Security measures
  - Mobile devices

  Testing Checklist:

  - 100% code coverage for intake.py
  - All user journeys tested
  - Documentation complete
  - Performance acceptable
  - Security review passed

  ---
  Optional Step 7.2.10: Add collective.easyform Integration

  Version: 0.9.0

  Implementation Tasks:

  1. Add collective.easyform dependency
  2. Create EasyForm GenericSetup profile
  3. Configure to post to @@whs-intake
  4. Document form builder usage
  5. Training for WHS Officer

  Why This Is Optional:

  - intake.py already works with any form
  - HTML form may be sufficient
  - Adds complexity and dependencies
  - Only needed if WHS Officer needs to modify forms

  Files to Create (if implemented):

  - src/csc/whs/profiles/default/structure/incident-easyform.xml
  - Update pyproject.toml - Add dependency
  - docs/easyform_guide.md

  ---
  Implementation Timeline

  | Step   | Version | Description           | Priority | Est. Time |
  |--------|---------|-----------------------|----------|-----------|
  | 7.2.1  | 0.7.4   | Enhance field mapping | HIGH     | 3 hours   |
  | 7.2.2  | 0.7.5   | Anonymous handling    | HIGH     | 2 hours   |
  | 7.2.3  | 0.7.6   | File uploads          | HIGH     | 3 hours   |
  | 7.2.4  | 0.7.7   | HTML form             | HIGH     | 4 hours   |
  | 7.2.5  | 0.7.8   | Success/Error pages   | HIGH     | 2 hours   |
  | 7.2.6  | 0.7.9   | Performance           | MEDIUM   | 2 hours   |
  | 7.2.7  | 0.8.0   | Notifications         | MEDIUM   | 3 hours   |
  | 7.2.8  | 0.8.1   | Security              | HIGH     | 3 hours   |
  | 7.2.9  | 0.8.2   | Testing/Docs          | HIGH     | 4 hours   |
  | 7.2.10 | 0.9.0   | EasyForm              | LOW      | 3 hours   |

  Total Core Features: 26 hours
  Optional EasyForm: +3 hours

  ---
  Key Advantages of This Approach

  1. Builds on Existing Code - intake.py already handles form→incident
  2. No New Dependencies - Works with current addon
  3. Incremental Enhancement - Each step adds value
  4. Flexible Form Options - HTML now, EasyForm later
  5. Fast Initial Deployment - Basic anonymous form in ~12 hours

  ---
  Success Metrics

  - ✅ Anonymous users can submit incidents
  - ✅ All fields properly mapped
  - ✅ File uploads work
  - ✅ Mobile-friendly interface
  - ✅ Reference numbers for tracking
  - ✅ Notifications to WHS team
  - ✅ Secure against abuse
  - ✅ Well-tested and documented

  ---
  Migration Path

  1. Phase 1 (Steps 7.2.1-7.2.5): Basic anonymous submission
  2. Phase 2 (Steps 7.2.6-7.2.8): Production hardening
  3. Phase 3 (Step 7.2.9): Testing & documentation
  4. Future (Step 7.2.10): EasyForm if needed

  This revised plan leverages your existing intake.py investment and provides a faster path to anonymous incident reporting.

