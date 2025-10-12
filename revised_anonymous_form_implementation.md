# CSC.WHS Revised Anonymous Incident Reporting Implementation Plan

## Executive Summary

This plan outlines the implementation of an anonymous incident reporting system for the CSC WHS Portal (Plone 6.1 Classic). The system will enable outdoor workers without email or AD accounts to submit WHS incidents while maintaining security and data integrity within an internal-only deployment.

## Context & Requirements

### Environment
- **Platform**: Plone 6.1 Classic (version 0.7.3 of csc.whs addon)
- **Authentication**: Active Directory via plone.pas.ldap for authenticated users
- **Access**: Internal network only (no internet exposure)
- **Users**: Mix of AD-authenticated staff and non-AD outdoor workers

### Key Requirements
- Anonymous submission capability for workers without accounts
- Mobile-friendly interface for field reporting
- File/photo upload capability (unlimited attachments)
- Reference tracking system for anonymous submissions
- Integration with existing workflow and notification systems

---

## Phase 1: Core Anonymous Submission Infrastructure

### Step 1.1: Enhance intake.py with Complete Field Mapping
**Version: 0.7.4**

#### Implementation Tasks:
1. Extend field mappings to cover all 20+ incident schema fields
2. Implement reference code generation utility
3. Add datetime parsing with timezone handling
4. Implement vocabulary value resolution (handle both tokens and titles)
5. Add comprehensive logging for debugging

#### Technical Implementation:

```python
# Reference code generation utility
from persistent.mapping import PersistentMapping
from zope.annotation.interfaces import IAnnotations

ANNOTATION_KEY = 'csc.whs.incident_counter'

def generate_reference_code(context):
    """Generate unique reference code INC-YYYY-00001"""
    portal = api.portal.get()
    annotations = IAnnotations(portal)

    if ANNOTATION_KEY not in annotations:
        annotations[ANNOTATION_KEY] = PersistentMapping()

    year = datetime.now().year
    year_key = str(year)

    if year_key not in annotations[ANNOTATION_KEY]:
        annotations[ANNOTATION_KEY][year_key] = 0

    counter = annotations[ANNOTATION_KEY][year_key] + 1
    annotations[ANNOTATION_KEY][year_key] = counter

    return f"INC-{year}-{counter:05d}"
```

#### Field Mapping Extensions:
- Parse datetime fields with multiple format support
- Map vocabulary display values to stored tokens
- Handle optional fields with sensible defaults
- Set `reported_at` to current timestamp
- Auto-generate reference_code on creation

#### Files to Modify:
- `src/csc/whs/browser/intake.py`
- `src/csc/whs/utilities.py` (new file for reference generation)

#### Testing Checklist:
- [ ] All 20+ fields map correctly from form data
- [ ] Reference codes generate sequentially (INC-2025-00001, etc.)
- [ ] Vocabulary fields accept both tokens and display titles
- [ ] DateTime parsing handles ISO, US, and AU formats
- [ ] Missing optional fields don't cause errors

---

### Step 1.2: Implement Anonymous Submission Handler
**Version: 0.7.5**

#### Implementation Tasks:
1. Configure permissions for anonymous access to @@whs-intake
2. Detect anonymous vs authenticated submissions
3. Store reporter contact details in annotations
4. Set appropriate workflow state based on submission type
5. Implement basic email notification

#### Anonymous Data Storage Strategy:

```python
# Store in annotations (not in main object fields)
REPORTER_ANNOTATION_KEY = 'csc.whs.anonymous_reporter'

reporter_data = {
    'name': request.form.get('reporter_name'),
    'email': request.form.get('reporter_email'),
    'phone': request.form.get('reporter_phone'),
    'ip_address': request.get('HTTP_X_FORWARDED_FOR', request.get('REMOTE_ADDR')),
    'submission_timestamp': datetime.now().isoformat(),
    'user_agent': request.get('HTTP_USER_AGENT'),
}

annotations = IAnnotations(incident_obj)
annotations[REPORTER_ANNOTATION_KEY] = PersistentMapping(reporter_data)
```

#### Permission Configuration:
```xml
<!-- configure.zcml -->
<browser:view
    name="whs-intake"
    for="*"
    class=".intake.IntakeView"
    permission="zope2.View"
    />
```

#### Email Notification:
- Send immediate notification to WHS Officer role members
- Include severity flag in subject for critical incidents
- Provide incident summary and reference code

#### Files to Modify:
- `src/csc/whs/browser/intake.py`
- `src/csc/whs/configure.zcml`
- `src/csc/whs/notifications.py` (new)

#### Testing Checklist:
- [ ] Anonymous users can access @@whs-intake
- [ ] Reporter information stored in annotations
- [ ] Authenticated submissions maintain owner
- [ ] Email sent to WHS Officers on submission
- [ ] Reference code returned to submitter

---

### Step 1.3: Implement RelationList for Unlimited File Attachments
**Version: 0.7.6**

#### Implementation Tasks:
1. Modify incident schema to use RelationList for attachments
2. Create File/Image content items for uploads
3. Link attachments via relations
4. Implement file validation (type, size, count)
5. Add virus scanning hook point

#### Schema Modification:

```python
from z3c.relationfield.schema import RelationList, RelationChoice
from plone.app.vocabularies.catalog import CatalogSource

class IIncident(model.Schema):
    # Replace photo_1, photo_2, photo_3 with:

    attachments = RelationList(
        title=u"Attachments",
        description=u"Related files and images",
        required=False,
        value_type=RelationChoice(
            source=CatalogSource(portal_type=['File', 'Image']),
        ),
        default=[],
    )
```

#### File Upload Processing:

```python
def process_file_uploads(incident, request):
    """Process uploaded files and create relations"""
    attachments = []

    # Handle multiple file inputs
    for key in request.form.keys():
        if key.startswith('attachment_') or key == 'files':
            file_uploads = request.form.get(key)
            if not isinstance(file_uploads, list):
                file_uploads = [file_uploads]

            for file_upload in file_uploads:
                if hasattr(file_upload, 'filename'):
                    # Create File or Image based on mimetype
                    content_type = 'Image' if 'image' in file_upload.headers.get('content-type', '') else 'File'

                    # Create in incident container or dedicated folder
                    attachment = api.content.create(
                        container=incident,
                        type=content_type,
                        title=file_upload.filename,
                        file=file_upload,
                    )

                    # Create relation
                    from z3c.relationfield.relation import RelationValue
                    from zope.component import getUtility
                    from zope.intid.interfaces import IIntIds

                    intids = getUtility(IIntIds)
                    attachments.append(RelationValue(intids.getId(attachment)))

    if attachments:
        incident.attachments = attachments
```

#### Validation Rules:
- Maximum file size: 10MB per file
- Maximum total upload: 50MB
- Allowed types: Images (jpg, png, gif), PDFs, Office docs
- Maximum files: 10 per submission

#### Files to Modify:
- `src/csc/whs/interfaces.py` (schema change)
- `src/csc/whs/browser/intake.py` (file processing)
- `src/csc/whs/profiles/default/types/csc.whs.incident.xml`

#### Testing Checklist:
- [ ] Multiple file upload works
- [ ] Files stored as related content items
- [ ] File size limits enforced
- [ ] Invalid file types rejected
- [ ] Relations properly established

---

## Phase 2: Mobile-Friendly Anonymous Form Interface

### Step 2.1: Create Responsive HTML Form
**Version: 0.7.7**

#### Implementation Tasks:
1. Create mobile-first responsive HTML template
2. Implement progressive disclosure for complex fields
3. Add client-side validation
4. Include camera/file integration for mobile
5. Implement offline detection with user feedback

#### Form Structure:

```html
<!-- Progressive disclosure sections -->
<form id="incident-form" action="@@whs-intake" method="post" enctype="multipart/form-data">

    <!-- Section 1: Critical Information -->
    <fieldset class="form-section active" data-step="1">
        <legend>What Happened?</legend>

        <div class="form-group required">
            <label for="occurred_at">When did it occur?</label>
            <input type="datetime-local" id="occurred_at" name="occurred_at" required>
        </div>

        <div class="form-group required">
            <label for="location">Location</label>
            <select id="location" name="location" required>
                <!-- Populate from vocabulary -->
            </select>
        </div>

        <div class="form-group required">
            <label for="severity">Severity</label>
            <select id="severity" name="severity" required>
                <!-- Populate from vocabulary -->
            </select>
        </div>

        <div class="form-group required">
            <label for="description">Description</label>
            <textarea id="description" name="description" required rows="4"></textarea>
        </div>
    </fieldset>

    <!-- Section 2: Reporter Information -->
    <fieldset class="form-section" data-step="2">
        <legend>Your Contact Information</legend>

        <div class="form-group required">
            <label for="reporter_name">Your Name</label>
            <input type="text" id="reporter_name" name="reporter_name" required>
        </div>

        <div class="form-group">
            <label for="reporter_email">Email (for confirmation)</label>
            <input type="email" id="reporter_email" name="reporter_email">
        </div>

        <div class="form-group">
            <label for="reporter_phone">Phone</label>
            <input type="tel" id="reporter_phone" name="reporter_phone">
        </div>
    </fieldset>

    <!-- Section 3: Incident Details (Conditional) -->
    <fieldset class="form-section" data-step="3">
        <legend>Incident Details</legend>

        <!-- Show/hide based on category selection -->
        <div class="conditional-fields" data-show-when="category:injury">
            <!-- Injury-specific fields -->
        </div>

        <div class="conditional-fields" data-show-when="category:property_damage">
            <!-- Property damage fields -->
        </div>
    </fieldset>

    <!-- Section 4: Evidence -->
    <fieldset class="form-section" data-step="4">
        <legend>Photos & Documents</legend>

        <div class="file-upload-area">
            <input type="file"
                   id="attachments"
                   name="attachments"
                   multiple
                   accept="image/*,.pdf,.doc,.docx"
                   capture="environment">
            <label for="attachments">
                <span>Take Photo or Choose Files</span>
            </label>
        </div>

        <div id="file-preview" class="file-preview"></div>
    </fieldset>

    <!-- Navigation -->
    <div class="form-navigation">
        <button type="button" class="btn-prev">Previous</button>
        <button type="button" class="btn-next">Next</button>
        <button type="submit" class="btn-submit" style="display:none;">Submit Report</button>
    </div>
</form>
```

#### Mobile Optimizations:
- Touch-friendly input sizes (min 44x44px)
- Progressive disclosure reduces cognitive load
- Camera integration for direct photo capture
- Offline detection with localStorage draft saving
- GPS location detection (with permission)

#### Files to Create:
- `src/csc/whs/browser/templates/anonymous_form.pt`
- `src/csc/whs/browser/static/css/anonymous_form.css`
- `src/csc/whs/browser/static/js/anonymous_form.js`
- `src/csc/whs/browser/anonymous_form.py` (view class)

#### Testing Checklist:
- [ ] Form renders correctly on mobile devices
- [ ] Camera capture works on iOS/Android
- [ ] Offline detection shows appropriate message
- [ ] Form saves draft to localStorage
- [ ] Progressive disclosure works smoothly

---

### Step 2.2: Add CAPTCHA Protection
**Version: 0.7.8**

#### Implementation Tasks:
1. Integrate plone.formwidget.recaptcha
2. Configure CAPTCHA for anonymous submissions only
3. Add honeypot fields as secondary protection
4. Implement rate limiting by IP

#### CAPTCHA Integration:

```python
# In anonymous_form.py
from plone.formwidget.recaptcha import ReCaptchaFieldWidget
from z3c.form import form, button

class AnonymousIncidentForm(form.Form):

    def update(self):
        super().update()
        # Only show CAPTCHA for anonymous users
        if api.user.is_anonymous():
            self.fields['captcha'].widgetFactory = ReCaptchaFieldWidget
```

#### Honeypot Implementation:
```html
<!-- Hidden field that bots will fill -->
<div style="position:absolute;left:-9999px;">
    <input type="text" name="website" tabindex="-1" autocomplete="off">
</div>
```

#### Rate Limiting:
- 5 submissions per IP per hour
- Store in volatile cache to avoid persistence overhead

#### Files to Modify:
- `pyproject.toml` (add plone.formwidget.recaptcha)
- `src/csc/whs/browser/anonymous_form.py`
- `src/csc/whs/browser/templates/anonymous_form.pt`

#### Testing Checklist:
- [ ] CAPTCHA appears for anonymous users
- [ ] CAPTCHA not shown for authenticated users
- [ ] Honeypot field catches automated submissions
- [ ] Rate limiting prevents spam
- [ ] Error messages are user-friendly

---

## Phase 3: Success Handling & Notifications

### Step 3.1: Success & Error Pages
**Version: 0.7.9**

#### Implementation Tasks:
1. Create success confirmation page with reference number
2. Implement error handling with form data preservation
3. Add QR code generation for reference number
4. Provide print-friendly confirmation option
5. Optional SMS/email confirmation

#### Success Page Features:

```html
<div class="success-page">
    <h1>Incident Report Submitted Successfully</h1>

    <div class="reference-box">
        <h2>Your Reference Number</h2>
        <div class="reference-code">INC-2025-00042</div>
        <div class="qr-code">
            <!-- Generated QR code -->
        </div>
        <p>Please save this number to track your report</p>
    </div>

    <div class="next-steps">
        <h3>What Happens Next?</h3>
        <ul>
            <li>WHS Officer has been notified</li>
            <li>You will be contacted within 24 hours</li>
            <li>Investigation will commence if required</li>
        </ul>
    </div>

    <div class="actions">
        <button onclick="window.print()">Print Confirmation</button>
        <button onclick="sendEmail()">Email Confirmation</button>
    </div>
</div>
```

#### Error Handling:
- Preserve form data in session
- Display specific error messages
- Provide recovery options
- Log errors for debugging

#### Files to Create:
- `src/csc/whs/browser/templates/submission_success.pt`
- `src/csc/whs/browser/templates/submission_error.pt`
- `src/csc/whs/browser/confirmation.py`

#### Testing Checklist:
- [ ] Success page displays reference prominently
- [ ] QR code generates correctly
- [ ] Print view formats properly
- [ ] Email confirmation sends if requested
- [ ] Error recovery preserves form data

---

### Step 3.2: Enhanced Notification System
**Version: 0.8.0**

#### Implementation Tasks:
1. Immediate email to WHS Officers for critical incidents
2. Daily digest for Site Managers
3. Confirmation emails to reporters (if email provided)
4. Escalation rules for critical incidents
5. Integration with existing workflow notifications

#### Notification Rules:

```python
NOTIFICATION_RULES = {
    'critical': {
        'recipients': ['whs_officer', 'elt'],
        'timing': 'immediate',
        'method': 'email',
    },
    'major': {
        'recipients': ['whs_officer', 'site_manager'],
        'timing': 'immediate',
        'method': 'email',
    },
    'moderate': {
        'recipients': ['whs_officer'],
        'timing': 'immediate',
        'method': 'email',
    },
    'minor': {
        'recipients': ['whs_officer'],
        'timing': 'digest',
        'method': 'email',
    },
}
```

#### Email Templates:
- Critical incident alert (high priority)
- Standard incident notification
- Reporter confirmation
- Daily digest summary

#### Files to Create/Modify:
- `src/csc/whs/notifications.py`
- `src/csc/whs/browser/intake.py`
- `src/csc/whs/email_templates/` (directory for templates)

#### Testing Checklist:
- [ ] Critical incidents trigger immediate alerts
- [ ] Appropriate roles receive notifications
- [ ] Reporter confirmations sent when email provided
- [ ] Daily digest compiles correctly
- [ ] No duplicate notifications

---

## Phase 4: Testing & Documentation

### Step 4.1: Comprehensive Testing Suite
**Version: 0.8.1**

#### Test Coverage Requirements:
1. Unit tests for intake.py enhancements
2. Integration tests for anonymous submission flow
3. Functional tests for form validation
4. Performance tests for file uploads
5. Security tests for CAPTCHA and rate limiting

#### Test Scenarios:
- Anonymous submission end-to-end
- All field mapping variations
- File upload edge cases (size, type, quantity)
- Error conditions and recovery
- Concurrent submissions
- Rate limiting effectiveness

#### Files to Create:
- `src/csc/whs/tests/test_intake_enhanced.py`
- `src/csc/whs/tests/test_anonymous_submission.py`
- `src/csc/whs/tests/test_notifications.py`
- `src/csc/whs/tests/test_file_uploads.py`

---

### Step 4.2: Documentation
**Version: 0.8.2**

#### Documentation Deliverables:
1. User guide for anonymous submission
2. Administrator guide for configuration
3. API documentation for intake.py
4. Troubleshooting guide
5. Training materials for WHS Officers

#### Files to Create:
- `docs/user_guide_anonymous_submission.md`
- `docs/admin_guide_anonymous_form.md`
- `docs/api_intake.md`
- `docs/troubleshooting.md`

---

## Implementation Timeline

| Phase | Version | Description | Priority | Estimated Time |
|-------|---------|-------------|----------|----------------|
| **Phase 1: Core Infrastructure** |
| 1.1 | 0.7.4 | Enhanced field mapping & reference codes | HIGH | 4 hours |
| 1.2 | 0.7.5 | Anonymous submission handler | HIGH | 3 hours |
| 1.3 | 0.7.6 | RelationList file attachments | HIGH | 4 hours |
| **Phase 2: Form Interface** |
| 2.1 | 0.7.7 | Mobile-friendly HTML form | HIGH | 5 hours |
| 2.2 | 0.7.8 | CAPTCHA & security | HIGH | 3 hours |
| **Phase 3: User Experience** |
| 3.1 | 0.7.9 | Success/error handling | MEDIUM | 3 hours |
| 3.2 | 0.8.0 | Enhanced notifications | MEDIUM | 3 hours |
| **Phase 4: Quality Assurance** |
| 4.1 | 0.8.1 | Testing suite | HIGH | 4 hours |
| 4.2 | 0.8.2 | Documentation | MEDIUM | 3 hours |

**Total Implementation Time: 32 hours**

---

## Risk Mitigation

### Technical Risks
- **File Upload Performance**: Implement async processing for large files
- **Anonymous Abuse**: Rate limiting + CAPTCHA + internal network only
- **Data Loss**: Save drafts to localStorage, server-side session backup

### Organizational Risks
- **User Adoption**: Clear training, simple interface, reference tracking
- **Support Burden**: Comprehensive docs, clear error messages
- **Compliance**: Ensure WorkSafe notification requirements met

---

## Success Metrics

### Functional Requirements
- ✅ Anonymous users can submit incidents without authentication
- ✅ All incident fields properly captured and mapped
- ✅ Unlimited file attachments supported
- ✅ Mobile-friendly interface works on all devices
- ✅ Reference numbers generated for tracking
- ✅ Notifications sent to appropriate parties

### Performance Requirements
- ✅ Form submission completes in <3 seconds
- ✅ File uploads handle 50MB total
- ✅ System handles 100 concurrent users
- ✅ 99.9% uptime during business hours

### Security Requirements
- ✅ CAPTCHA prevents automated abuse
- ✅ Rate limiting prevents DoS
- ✅ No data leakage to anonymous users
- ✅ Audit trail maintained

---

## Future Enhancements

### Phase 5 (Future)
- Integration with Content Manager 10 for closed incidents
- Mobile app using Plone REST API
- Offline-first PWA implementation
- Advanced analytics dashboard
- Integration with existing RT queue migration

---

## Conclusion

This revised implementation plan addresses the specific requirements of the CSC WHS Portal while leveraging existing Plone 6.1 capabilities. The phased approach ensures rapid delivery of core functionality while maintaining quality and security standards.

Key improvements from the original plan:
- Removed archived z3c.form.wizard dependency
- Incorporated AD/LDAP authentication context
- Implemented RelationList for unlimited attachments
- Added CAPTCHA for internal network security
- Maintained focus on outdoor workers without accounts

The plan delivers a production-ready anonymous incident reporting system optimized for mobile use within an internal corporate environment.