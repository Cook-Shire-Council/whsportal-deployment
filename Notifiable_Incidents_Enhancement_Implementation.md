# Notifiable Incidents Enhancement - Implementation Plan

**Created:** 2025-10-23
**Status:** Planning
**Priority:** High (Legal Compliance)
**Target Version:** csc.whs v0.11.0 (Priority 1), v0.12.0 (Priority 2), v0.13.0 (Priority 3)

## Executive Summary

This implementation plan addresses the management of **notifiable incidents** as defined under Queensland's Work Health and Safety Act 2011. The enhancements will improve compliance with WorkSafe Queensland notification requirements, provide better visual indicators for urgent incidents, and implement workflow automation to ensure timely responses to legally-mandated incidents.

**Legal Context:**
- Notifiable incidents must be reported to WorkSafe QLD **immediately** by phone (1300 369 915)
- Written notification required within **48 hours**
- Incident scene must be preserved until WorkSafe authorizes disturbance
- Cook Shire Council as a PCBU has heightened compliance obligations

## Implementation Priorities

### Priority 1: Visual Improvements & UI Enhancement (v0.11.0)
**Goal:** Make notifiable incidents immediately visible to reviewers
**Estimated Time:** 4-6 hours (AI-assisted)
**Risk Level:** Low (UI-only changes, no workflow modifications)
**Target Deployment:** Immediate (can deploy independently)

### Priority 2: Workflow Enhancement (v0.12.0)
**Goal:** Implement dedicated workflow states and auto-transitions for compliance
**Estimated Time:** 12-16 hours (AI-assisted)
**Risk Level:** Medium (workflow changes require careful testing)
**Target Deployment:** After Priority 1 testing complete

### Priority 3: Compliance Tracking Features (v0.13.0)
**Goal:** Full compliance tracking with WorkSafe notification details
**Estimated Time:** 8-12 hours (AI-assisted)
**Risk Level:** Medium (schema changes, new fields)
**Target Deployment:** After Priority 2 stabilized

---

## Priority 1: Visual Improvements & UI Enhancement

### Objectives
1. Move "Notifiable to Regulator" to top of incident view
2. Add visual warning banner for notifiable incidents
3. Add notifiable indicator in incident listing
4. Add notifiable count to listing dashboard
5. Improve visual hierarchy for urgent incidents

### Implementation Steps

#### Phase 1.1: Incident View Template Enhancement

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/browser/templates/incident.pt`

**Changes Required:**
1. **Move notifiable field to Section 1** (after incident reference/date)
   - Currently in Section 2 (Details)
   - Move to top of template (lines ~50-80)
   - Add prominent visual styling

2. **Add warning banner for notifiable incidents**
   ```html
   <div class="notifiable-warning-banner"
        tal:condition="python: context.notifiable_to_regulator">
       <div class="banner-icon">⚠️</div>
       <div class="banner-content">
           <h3>NOTIFIABLE INCIDENT - IMMEDIATE ACTION REQUIRED</h3>
           <p><strong>Legal Requirement:</strong> This incident must be reported to WorkSafe Queensland immediately.</p>
           <ul>
               <li><strong>Phone:</strong> 1300 369 915 (24/7)</li>
               <li><strong>Written notification:</strong> Required within 48 hours</li>
               <li><strong>Scene preservation:</strong> Do not disturb incident site</li>
           </ul>
           <p><a href="https://www.worksafe.qld.gov.au/notify" target="_blank">
              WorkSafe QLD Notification Form →</a></p>
       </div>
   </div>
   ```

3. **Update field display styling**
   - Make "Notifiable to Regulator" field more prominent
   - Use color coding: Red badge for "Yes", standard for "No"
   - Add icon indicator (⚠️ for Yes)

**Estimated Lines:** ~80 lines of HTML/TAL

#### Phase 1.2: Incident Listing Template Enhancement

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/browser/templates/incident_listing.pt`

**Changes Required:**
1. **Add notifiable count to dashboard header**
   ```html
   <div class="listing-stats">
       <div class="stat-item">
           <span class="stat-label">Total Incidents:</span>
           <span class="stat-value" tal:content="total_count">0</span>
       </div>
       <div class="stat-item stat-notifiable">
           <span class="stat-label">⚠️ Notifiable:</span>
           <span class="stat-value notifiable-count"
                 tal:content="notifiable_count">0</span>
       </div>
   </div>
   ```

2. **Add visual indicator to each notifiable incident row**
   - Add warning icon (⚠️) before incident reference
   - Highlight row with background color
   - Add CSS class for styling

3. **Add optional "Notifiable" filter**
   - Filter button to show only notifiable incidents
   - Consider making this default sort to top

**Estimated Lines:** ~60 lines of HTML/TAL

#### Phase 1.3: Backend Support for Listing Counts

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/browser/incident_listing.py`

**Changes Required:**
1. **Add notifiable count calculation**
   ```python
   def get_notifiable_count(self):
       """Return count of notifiable incidents."""
       catalog = api.portal.get_tool('portal_catalog')
       results = catalog(
           portal_type='csc.whs.incident',
           notifiable_to_regulator=True,
           sort_on='created',
           sort_order='descending'
       )
       return len(results)
   ```

2. **Add notifiable indicator to incident items**
   ```python
   def get_incidents(self):
       """Enhanced to include notifiable flag."""
       # ... existing code ...
       for brain in results:
           item = {
               # ... existing fields ...
               'is_notifiable': brain.notifiable_to_regulator,
           }
           incidents.append(item)
       return incidents
   ```

3. **Make available to template**
   - Add `notifiable_count` to template context
   - Add `is_notifiable` flag to each incident item

**Estimated Lines:** ~30 lines of Python

#### Phase 1.4: CSS Styling

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/browser/static/incident_form.css`

**New Styles Required:**
1. **Warning banner styling**
   ```css
   .notifiable-warning-banner {
       background: #fff3cd;
       border: 3px solid #ff6b6b;
       border-radius: 8px;
       padding: 20px;
       margin: 20px 0 30px 0;
       display: flex;
       gap: 15px;
       box-shadow: 0 4px 6px rgba(0,0,0,0.1);
   }

   .notifiable-warning-banner .banner-icon {
       font-size: 48px;
       line-height: 1;
   }

   .notifiable-warning-banner h3 {
       color: #c92a2a;
       margin: 0 0 10px 0;
       font-size: 18px;
       font-weight: 700;
   }

   /* ... additional styles ... */
   ```

2. **Listing view notifiable styling**
   ```css
   .incident-row.notifiable {
       background-color: #fff3cd;
       border-left: 4px solid #ff6b6b;
   }

   .notifiable-indicator {
       color: #c92a2a;
       font-size: 20px;
       margin-right: 8px;
   }

   .stat-notifiable {
       background: #fff3cd;
       border: 2px solid #ff6b6b;
       padding: 10px;
       border-radius: 4px;
   }
   ```

3. **Field prominence styling**
   ```css
   .field-notifiable-yes {
       background: #ff6b6b;
       color: white;
       padding: 8px 16px;
       border-radius: 4px;
       font-weight: bold;
       display: inline-block;
   }

   .field-notifiable-no {
       background: #e9ecef;
       color: #495057;
       padding: 8px 16px;
       border-radius: 4px;
       display: inline-block;
   }
   ```

**Estimated Lines:** ~150 lines of CSS

#### Phase 1.5: Print View Styling

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/browser/static/print_view.css`

**Changes Required:**
1. Ensure notifiable banner prints correctly
2. Add print-specific styling for warning banner
3. Ensure notifiable indicator is clear in printed documents

**Estimated Lines:** ~40 lines of CSS

### Files Modified (Priority 1)
- `csc/src/csc/whs/browser/templates/incident.pt` (~80 lines added/modified)
- `csc/src/csc/whs/browser/templates/incident_listing.pt` (~60 lines added/modified)
- `csc/src/csc/whs/browser/incident_listing.py` (~30 lines added)
- `csc/src/csc/whs/browser/static/incident_form.css` (~150 lines added)
- `csc/src/csc/whs/browser/static/print_view.css` (~40 lines added)

**Total Code Impact:** ~360 lines

### Testing Requirements (Priority 1)
1. **Visual Testing**
   - [ ] Notifiable banner displays correctly on notifiable incidents
   - [ ] Notifiable field is prominent at top of incident view
   - [ ] Banner does NOT display on non-notifiable incidents
   - [ ] Listing count shows correct number of notifiable incidents
   - [ ] Notifiable incidents have visual indicator in listing
   - [ ] Print view displays notifiable information correctly

2. **Responsive Testing**
   - [ ] Banner displays correctly on mobile devices
   - [ ] Listing indicators work on tablets/phones
   - [ ] All text is readable at different viewport sizes

3. **Browser Testing**
   - [ ] Chrome/Edge (primary)
   - [ ] Firefox
   - [ ] Safari (if available)

### Deployment Strategy (Priority 1)
- **Version:** csc.whs v0.11.0
- **Profile Version:** No change (v19) - no schema changes
- **Deployment Type:** Standard wheel deployment
- **Rollback Risk:** Very low (UI-only changes)
- **Testing Window:** 2-3 days with WHS Officer feedback

---

## Priority 2: Workflow Enhancement

### Objectives
1. Create dedicated workflow states for notifiable incidents
2. Implement auto-transition when notifiable = True
3. Add review/confirmation workflow step
4. Add downgrade path for incorrectly classified incidents
5. Implement time-based SLA tracking

### Workflow Design

#### Current Workflow (csc_incident_workflow)
```
[Create] → "reported" → "under_review" → "investigating" → "resolved" → "closed"
                          ↓
                    "requires_action"
```

#### Enhanced Workflow with Notifiable States
```
[Create - Regular] → "reported" → (existing workflow)

[Create - Notifiable] → "notifiable_pending" → [WHS Officer Reviews]
                              ↓                         ↓
                              ↓                   [Confirms]
                              ↓                         ↓
                              ↓              "notifiable_confirmed"
                              ↓                         ↓
                              ↓              [Phone Notification Logged]
                              ↓                         ↓
                              ↓              "notifiable_worksafe_contacted"
                              ↓                         ↓
                              ↓              [Written Notification Submitted]
                              ↓                         ↓
                              ↓              "notifiable_fully_notified"
                              ↓                         ↓
                              ↓              (joins standard workflow at investigating)
                              ↓
                        [Not Actually Notifiable]
                              ↓
                        Transition to "reported"
                              ↓
                        (standard workflow continues)
```

#### State Definitions

**1. notifiable_pending**
- **Title:** "Notifiable - Pending Review"
- **Description:** "Incident reported as notifiable, requires immediate WHS Officer review"
- **Color:** Orange/Yellow
- **Permissions:** WHS Officers can view/edit, Reporter can view
- **Time Limit:** Must review within 2 hours (SLA)
- **Auto-transition:** Yes (from intake when notifiable_to_regulator = True)

**2. notifiable_confirmed**
- **Title:** "Notifiable - Confirmed"
- **Description:** "WHS Officer confirmed this is notifiable to WorkSafe QLD"
- **Color:** Red
- **Permissions:** WHS Officers can view/edit
- **Time Limit:** Phone notification required immediately
- **Next Step:** Log phone notification details

**3. notifiable_worksafe_contacted**
- **Title:** "Notifiable - WorkSafe Contacted"
- **Description:** "WorkSafe QLD notified by phone, written notification pending"
- **Color:** Orange
- **Permissions:** WHS Officers can view/edit
- **Time Limit:** Written notification within 48 hours of incident
- **Next Step:** Submit written notification

**4. notifiable_fully_notified**
- **Title:** "Notifiable - Fully Notified"
- **Description:** "WorkSafe QLD fully notified (phone + written), investigation proceeding"
- **Color:** Blue
- **Permissions:** Standard investigation permissions
- **Next Step:** Standard investigation workflow

### Implementation Steps

#### Phase 2.1: Workflow XML Configuration

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/profiles/default/workflows/csc_incident_workflow/definition.xml`

**Changes Required:**
1. **Add new workflow states**
   - Define 4 new states (notifiable_pending, notifiable_confirmed, notifiable_worksafe_contacted, notifiable_fully_notified)
   - Set permissions for each state
   - Define worklist entries

2. **Add new transitions**
   - `auto_set_notifiable_pending` (automatic on create)
   - `confirm_notifiable` (notifiable_pending → notifiable_confirmed)
   - `log_phone_notification` (notifiable_confirmed → notifiable_worksafe_contacted)
   - `submit_written_notification` (notifiable_worksafe_contacted → notifiable_fully_notified)
   - `begin_investigation` (notifiable_fully_notified → investigating)
   - `downgrade_not_notifiable` (notifiable_pending → reported)

3. **Define transition guards**
   - Guards to ensure proper workflow progression
   - Validation for required fields at each step

**Estimated Lines:** ~300 lines of XML

#### Phase 2.2: Automatic Workflow Transition on Create

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/browser/intake.py`

**Changes Required:**
1. **Add auto-transition after incident creation** (around line 350-360)
   ```python
   # Create the incident object
   incident = api.content.create(
       container=folder,
       type='csc.whs.incident',
       id=reference_code,
       title=title
   )

   # ... set fields ...

   # NEW: Auto-transition to notifiable_pending if notifiable
   if incident.notifiable_to_regulator:
       try:
           api.content.transition(
               obj=incident,
               transition='auto_set_notifiable_pending'
           )
           logger.warning(
               f"Auto-transitioned incident {reference_code} to "
               f"notifiable_pending state (requires immediate review)"
           )
       except Exception as e:
           logger.error(
               f"Failed to auto-transition {reference_code} to "
               f"notifiable_pending: {e}"
           )
   ```

2. **Add email notification for urgent review**
   ```python
   if incident.notifiable_to_regulator:
       # Send urgent notification to WHS Officers
       send_urgent_notifiable_notification(incident)
   ```

**Estimated Lines:** ~40 lines of Python

#### Phase 2.3: Enhanced Email Notifications

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/notifications.py`

**Changes Required:**
1. **Create new urgent notification function**
   ```python
   def send_urgent_notifiable_notification(incident):
       """
       Send URGENT notification for notifiable incidents.
       Uses high priority email flags and urgent subject line.
       """
       # Get WHS Officers (all of them)
       # Send with URGENT flag
       # Include legal requirements in email
       # Include direct link to incident
       # Add deadline information
   ```

2. **Enhance email template**
   - Add "URGENT - NOTIFIABLE INCIDENT" to subject
   - Include WorkSafe QLD contact information
   - Add legal requirements checklist
   - Include time-sensitive deadlines

**Estimated Lines:** ~80 lines of Python

#### Phase 2.4: Workflow Transition Views

**New File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/browser/notifiable_workflow.py`

**Purpose:** Browser views for workflow transitions with forms

**Views to Create:**
1. **ConfirmNotifiableView** - Review and confirm incident is notifiable
   - Display incident details
   - Confirmation form
   - Option to downgrade if not actually notifiable
   - Records reviewer and timestamp

2. **LogPhoneNotificationView** - Record phone notification details
   - Date/time of call
   - Contact person at WorkSafe
   - Reference number (if provided)
   - Notes field

3. **SubmitWrittenNotificationView** - Record written notification
   - Submission date/time
   - Method (online form, email, etc.)
   - Reference number
   - Upload confirmation document

4. **DowngradeNotifiableView** - Downgrade incident to regular
   - Reason for downgrade
   - Reviewer notes
   - Automatic transition to "reported"

**Estimated Lines:** ~250 lines of Python

#### Phase 2.5: Workflow Action Templates

**New Files:**
- `csc/src/csc/whs/browser/templates/confirm_notifiable.pt` (~100 lines)
- `csc/src/csc/whs/browser/templates/log_phone_notification.pt` (~80 lines)
- `csc/src/csc/whs/browser/templates/submit_written_notification.pt` (~80 lines)
- `csc/src/csc/whs/browser/templates/downgrade_notifiable.pt` (~60 lines)

**Common Template Features:**
- Display current incident details
- Form for required information
- Validation
- Cancel button
- Submit button with confirmation
- Display legal requirements and deadlines

**Estimated Lines:** ~320 lines of TAL/HTML

#### Phase 2.6: Browser View Registration

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/browser/configure.zcml`

**Changes Required:**
Add browser view registrations for workflow transition views

**Estimated Lines:** ~40 lines of XML

#### Phase 2.7: Profile Upgrade Step

**New File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/upgrades/v20.py`

**Purpose:** Upgrade existing incidents to new workflow

**Tasks:**
1. Update workflow definition
2. Update security settings for new states
3. Re-map existing incidents to new workflow
4. Handle existing notifiable incidents (optional migration to new states)

**Estimated Lines:** ~120 lines of Python

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/profiles/default/metadata.xml`

**Change version to:** `<version>20</version>`

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/profiles/default/upgrades.zcml`

**Add upgrade step:** v19 → v20

### Files Modified/Created (Priority 2)
**Modified:**
- `csc/src/csc/whs/profiles/default/workflows/csc_incident_workflow/definition.xml` (~300 lines)
- `csc/src/csc/whs/browser/intake.py` (~40 lines added)
- `csc/src/csc/whs/notifications.py` (~80 lines added)
- `csc/src/csc/whs/browser/configure.zcml` (~40 lines added)
- `csc/src/csc/whs/profiles/default/metadata.xml` (version bump)
- `csc/src/csc/whs/profiles/default/upgrades.zcml` (new upgrade step)

**Created:**
- `csc/src/csc/whs/browser/notifiable_workflow.py` (~250 lines)
- `csc/src/csc/whs/browser/templates/confirm_notifiable.pt` (~100 lines)
- `csc/src/csc/whs/browser/templates/log_phone_notification.pt` (~80 lines)
- `csc/src/csc/whs/browser/templates/submit_written_notification.pt` (~80 lines)
- `csc/src/csc/whs/browser/templates/downgrade_notifiable.pt` (~60 lines)
- `csc/src/csc/whs/upgrades/v20.py` (~120 lines)

**Total Code Impact:** ~1,150 lines

### Testing Requirements (Priority 2)
1. **Workflow Transition Testing**
   - [ ] New incident with notifiable=True auto-transitions to notifiable_pending
   - [ ] New incident with notifiable=False stays in reported state
   - [ ] Confirm notifiable transition works correctly
   - [ ] Log phone notification transition works correctly
   - [ ] Submit written notification transition works correctly
   - [ ] Downgrade to regular incident works correctly
   - [ ] All workflow permissions are correct

2. **Email Notification Testing**
   - [ ] Urgent notifications sent for notifiable incidents
   - [ ] Email contains correct information and links
   - [ ] Email priority flags work correctly

3. **Upgrade Testing**
   - [ ] Profile upgrade v19→v20 completes successfully
   - [ ] Existing incidents still accessible
   - [ ] Existing notifiable incidents display correctly
   - [ ] No permission errors after upgrade

4. **Integration Testing**
   - [ ] Workflow states display correctly in listing view
   - [ ] Incident view shows current workflow state
   - [ ] Workflow actions available in correct states
   - [ ] Transitions recorded in workflow history

### Deployment Strategy (Priority 2)
- **Version:** csc.whs v0.12.0
- **Profile Version:** v20 (requires upgrade step)
- **Deployment Type:** Wheel deployment + profile upgrade
- **Rollback Risk:** Medium (workflow changes)
- **Testing Window:** 5-7 days with thorough WHS Officer testing
- **Deployment Steps:**
  1. Deploy wheel to dev server
  2. Run profile upgrade: v19 → v20
  3. Test all workflow transitions
  4. Verify email notifications
  5. Test with WHS Officer
  6. Production deployment after approval

---

## Priority 3: Compliance Tracking Features

### Objectives
1. Add schema fields for WorkSafe notification tracking
2. Implement notification status dashboard
3. Add compliance reporting/export
4. Implement SLA time tracking
5. Add automated deadline reminders

### Schema Enhancements

#### New Fields for IIncident

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/content/incident.py`

**Fields to Add:**

```python
# WorkSafe Notification Tracking
phone_notification_date = schema.Datetime(
    title="Phone Notification Date/Time",
    description="Date and time WorkSafe QLD was notified by phone",
    required=False,
)

phone_notification_contact = schema.TextLine(
    title="WorkSafe Contact Person",
    description="Name of WorkSafe QLD officer who took the notification",
    required=False,
)

phone_notification_reference = schema.TextLine(
    title="Phone Notification Reference",
    description="Reference number provided by WorkSafe (if any)",
    required=False,
)

written_notification_date = schema.Datetime(
    title="Written Notification Date/Time",
    description="Date and time written notification was submitted to WorkSafe QLD",
    required=False,
)

written_notification_method = schema.Choice(
    title="Written Notification Method",
    vocabulary="csc.whs.vocabularies.notification_methods",
    required=False,
)

written_notification_reference = schema.TextLine(
    title="Written Notification Reference Number",
    description="Reference number from WorkSafe QLD written notification",
    required=False,
)

written_notification_document = NamedBlobFile(
    title="Written Notification Confirmation",
    description="Upload confirmation email or document from WorkSafe QLD",
    required=False,
)

scene_preservation_status = schema.Choice(
    title="Scene Preservation Status",
    vocabulary="csc.whs.vocabularies.scene_preservation_status",
    required=False,
)

scene_release_date = schema.Datetime(
    title="Scene Release Date/Time",
    description="Date and time WorkSafe authorized disturbance of incident scene",
    required=False,
)

scene_release_contact = schema.TextLine(
    title="Scene Release Authorized By",
    description="WorkSafe QLD officer who authorized scene disturbance",
    required=False,
)

investigation_officer_assigned = schema.TextLine(
    title="WorkSafe Investigation Officer",
    description="Name of WorkSafe QLD officer assigned to investigate (if applicable)",
    required=False,
)

compliance_notes = schema.Text(
    title="Compliance Notes",
    description="Internal notes regarding WorkSafe QLD notifications and compliance",
    required=False,
)
```

**Estimated Lines:** ~120 lines of Python

#### New Vocabularies

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/vocabularies.py`

**Vocabularies to Add:**

1. **notification_methods**
   - Online form (worksafe.qld.gov.au)
   - Email
   - Fax
   - Post

2. **scene_preservation_status**
   - Scene secured - awaiting WorkSafe
   - Scene partially preserved
   - WorkSafe attended
   - Scene released by WorkSafe
   - Scene disturbance authorized
   - Not applicable (no scene to preserve)

**Estimated Lines:** ~40 lines of Python

### Implementation Steps

#### Phase 3.1: Schema Updates

**Tasks:**
1. Add new fields to IIncident schema (incident.py)
2. Add new vocabularies (vocabularies.py)
3. Update form fieldsets to organize new fields
4. Update incident view template to display tracking information

**Files Modified:**
- `csc/src/csc/whs/content/incident.py` (~120 lines)
- `csc/src/csc/whs/vocabularies.py` (~40 lines)

#### Phase 3.2: Workflow View Enhancements

Update workflow transition views from Priority 2 to save notification data:

**File:** `csc/src/csc/whs/browser/notifiable_workflow.py`

**Enhancements:**
- LogPhoneNotificationView saves to new schema fields
- SubmitWrittenNotificationView saves to new schema fields
- Add file upload handling for confirmation documents

**Estimated Lines:** ~60 lines of Python (modifications)

#### Phase 3.3: Incident View Template Enhancement

**File:** `csc/src/csc/whs/browser/templates/incident.pt`

**Add new section:** "WorkSafe QLD Notification Status"

Display:
- Phone notification details (if completed)
- Written notification details (if completed)
- Scene preservation status
- Investigation officer details
- Visual timeline of notifications
- Compliance status indicators

**Estimated Lines:** ~100 lines of TAL/HTML

#### Phase 3.4: Compliance Dashboard

**New File:** `csc/src/csc/whs/browser/notifiable_dashboard.py`

**Purpose:** Dashboard view for notifiable incidents compliance tracking

**Features:**
1. **Overview Statistics**
   - Total notifiable incidents
   - Pending phone notifications
   - Pending written notifications
   - Overdue notifications (>48 hours)

2. **Active Notifiable Incidents Table**
   - Incident reference
   - Date/time reported
   - Current state
   - Time elapsed since report
   - Notification status
   - Actions required

3. **SLA Tracking**
   - Incidents approaching 48-hour deadline
   - Color-coded urgency indicators
   - Time remaining until deadline

4. **Compliance Summary**
   - Notifications completed on time vs late
   - Average response times
   - Monthly/yearly statistics

**Estimated Lines:** ~200 lines of Python

**New File:** `csc/src/csc/whs/browser/templates/notifiable_dashboard.pt`

**Estimated Lines:** ~250 lines of TAL/HTML

#### Phase 3.5: Compliance Reporting/Export

**File:** `csc/src/csc/whs/browser/notifiable_dashboard.py`

**Add export methods:**

```python
def export_notifiable_incidents_csv(self):
    """Export notifiable incidents with compliance data to CSV."""
    # Include all notification tracking fields
    # Include time-to-notification metrics
    # Include compliance status

def export_compliance_report(self):
    """Generate compliance report for audit purposes."""
    # Summary statistics
    # Individual incident details
    # Timeline of notifications
    # PDF format for official records
```

**Estimated Lines:** ~120 lines of Python

#### Phase 3.6: Automated Deadline Reminders

**New File:** `csc/src/csc/whs/notifications.py` (enhancement)

**Add scheduled task functions:**

```python
def check_notifiable_deadlines():
    """
    Scheduled task to check for approaching/overdue notifiable deadlines.
    Run every hour.
    """
    # Find notifiable incidents without written notification
    # Calculate time since incident
    # Send reminders at:
    #   - 24 hours (warning)
    #   - 40 hours (urgent)
    #   - 48 hours (overdue)
    #   - Daily after 48 hours until resolved

def send_deadline_reminder(incident, urgency_level):
    """Send reminder email about notification deadline."""
    # High priority email
    # Include time remaining
    # Include direct action links
    # Escalate to management if overdue
```

**Estimated Lines:** ~150 lines of Python

**New File:** `csc/src/csc/whs/configure.zcml` (enhancement)

**Add GenericSetup clock server configuration:**
```xml
<!-- Scheduled task for notifiable deadline checking -->
<!-- Run hourly: 0 * * * * -->
```

**Note:** May require additional configuration in zope.ini for clock server

**Estimated Lines:** ~20 lines of XML

#### Phase 3.7: Profile Upgrade Step

**New File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/upgrades/v21.py`

**Purpose:** Add new schema fields

**Tasks:**
1. Update catalog indexes if needed
2. Reindex incidents for new fields
3. Initialize new fields to None/empty for existing incidents

**Estimated Lines:** ~80 lines of Python

**File:** `/home/ceo/Development/WHSPortal/csc/src/csc/whs/profiles/default/metadata.xml`

**Change version to:** `<version>21</version>`

### Files Modified/Created (Priority 3)

**Modified:**
- `csc/src/csc/whs/content/incident.py` (~120 lines added)
- `csc/src/csc/whs/vocabularies.py` (~40 lines added)
- `csc/src/csc/whs/browser/notifiable_workflow.py` (~60 lines modified)
- `csc/src/csc/whs/browser/templates/incident.pt` (~100 lines added)
- `csc/src/csc/whs/notifications.py` (~150 lines added)
- `csc/src/csc/whs/configure.zcml` (~20 lines added)
- `csc/src/csc/whs/profiles/default/metadata.xml` (version bump)
- `csc/src/csc/whs/profiles/default/upgrades.zcml` (new upgrade step)

**Created:**
- `csc/src/csc/whs/browser/notifiable_dashboard.py` (~320 lines)
- `csc/src/csc/whs/browser/templates/notifiable_dashboard.pt` (~250 lines)
- `csc/src/csc/whs/upgrades/v21.py` (~80 lines)

**Total Code Impact:** ~1,140 lines

### Testing Requirements (Priority 3)

1. **Schema Testing**
   - [ ] All new fields save correctly
   - [ ] File upload works for notification documents
   - [ ] Vocabularies display correctly
   - [ ] Fields display in incident view

2. **Dashboard Testing**
   - [ ] Dashboard displays correct statistics
   - [ ] SLA tracking calculations are accurate
   - [ ] Time remaining displays correctly
   - [ ] Color coding works as expected

3. **Export Testing**
   - [ ] CSV export includes all required fields
   - [ ] Compliance report generates correctly
   - [ ] Exported data is accurate
   - [ ] File downloads work correctly

4. **Reminder Testing**
   - [ ] Scheduled task runs correctly
   - [ ] Reminders sent at correct times
   - [ ] Email content is accurate
   - [ ] No duplicate reminders sent

5. **Integration Testing**
   - [ ] Workflow views save notification data correctly
   - [ ] Dashboard updates when data changes
   - [ ] All compliance tracking works end-to-end

### Deployment Strategy (Priority 3)
- **Version:** csc.whs v0.13.0
- **Profile Version:** v21 (requires upgrade step)
- **Deployment Type:** Wheel deployment + profile upgrade
- **Rollback Risk:** Medium (schema changes)
- **Testing Window:** 7-10 days with full compliance tracking test
- **Deployment Steps:**
  1. Deploy wheel to dev server
  2. Run profile upgrade: v20 → v21
  3. Test all new fields and tracking
  4. Test dashboard and exports
  5. Test deadline reminder system
  6. Full end-to-end compliance test
  7. WHS Officer approval
  8. Production deployment

---

## Overall Project Timeline

### Aggressive Schedule (All Priorities)
| Priority | Development | Testing | Deployment | Total |
|----------|-------------|---------|------------|-------|
| Priority 1 | 4-6 hours | 1 day | 1 day | 2-3 days |
| Priority 2 | 12-16 hours | 5-7 days | 1 day | 6-8 days |
| Priority 3 | 8-12 hours | 7-10 days | 1 day | 8-11 days |
| **Total** | **24-34 hours** | | | **16-22 days** |

### Recommended Phased Schedule
- **Phase 1 (v0.11.0):** Week 1-2 (Deploy ASAP for immediate visual improvements)
- **Phase 2 (v0.12.0):** Week 3-4 (Core workflow compliance)
- **Phase 3 (v0.13.0):** Week 5-7 (Full compliance tracking)

### Quick Win Option
Deploy Priority 1 independently within 2-3 days for immediate improvement in notifiable incident visibility while developing Priority 2 & 3.

---

## Success Metrics

### Compliance Metrics
- **Legal Compliance:** 100% of notifiable incidents reported to WorkSafe QLD within legal timeframes
- **Phone Notification:** <1 hour from incident report to WorkSafe phone notification
- **Written Notification:** <24 hours (well under 48-hour legal requirement)
- **Review SLA:** <2 hours from report to WHS Officer review

### Operational Metrics
- **Visibility:** 100% of notifiable incidents immediately identifiable in listing view
- **Tracking:** 100% of notifiable incidents have complete notification records
- **Audit Trail:** Complete workflow history for all notifiable incidents
- **Response Time:** Reduction in time-to-notification through automated workflow

### User Satisfaction Metrics
- WHS Officer feedback on visual improvements
- Ease of workflow transitions
- Usefulness of compliance dashboard
- Audit readiness improvements

---

## Risk Assessment

### Priority 1 Risks: **LOW**
- UI-only changes, no data modifications
- Easy rollback if issues found
- No schema changes
- No workflow changes

**Mitigation:** Thorough visual testing across devices and browsers

### Priority 2 Risks: **MEDIUM**
- Workflow changes affect permissions and state management
- Auto-transition could cause unexpected behavior
- Email notifications could spam if misconfigured

**Mitigation:**
- Extensive testing on dev server
- Gradual rollout with monitoring
- Email notification testing with test recipients
- Rollback plan: can revert to v0.11.0 if needed

### Priority 3 Risks: **MEDIUM**
- Schema changes require profile upgrade
- Scheduled tasks could impact performance
- Additional fields increase complexity

**Mitigation:**
- Thorough upgrade testing
- Performance monitoring after deployment
- Scheduled task monitoring and logging
- Rollback plan: difficult after schema changes, test thoroughly before production

---

## Dependencies and Prerequisites

### Technical Dependencies
- No new Python package dependencies required
- All functionality uses existing Plone 6.1 APIs
- Email server must be configured for notifications
- Cron/clock server for scheduled tasks (Priority 3)

### Knowledge Dependencies
- Understanding of Queensland WHS Act 2011 requirements
- WorkSafe QLD notification procedures
- Cook Shire Council internal compliance processes

### Stakeholder Dependencies
- WHS Officer approval at each priority level
- Testing availability from WHS Officer
- Feedback on workflow suitability

---

## Documentation Requirements

### Technical Documentation
- Update csc/README.md with notifiable incident features
- Document new workflow states and transitions
- Document compliance dashboard usage
- API documentation for new browser views

### User Documentation
- WHS Officer guide for notifiable incident workflow
- Quick reference card for WorkSafe QLD notification requirements
- Compliance tracking user guide
- Dashboard usage instructions

### Compliance Documentation
- Mapping of system features to legal requirements
- Audit trail documentation
- Compliance checklist
- Record-keeping procedures

---

## Recommendations

### Immediate Action (Priority 1)
**Recommended:** Deploy Priority 1 immediately (v0.11.0) for quick wins:
- Immediate improvement in notifiable incident visibility
- Low risk deployment
- Provides immediate value to WHS Officers
- Can be deployed within 2-3 days

### Core Compliance (Priority 2)
**Recommended:** Deploy Priority 2 (v0.12.0) within 3-4 weeks:
- Addresses core legal compliance requirements
- Provides workflow automation
- Reduces risk of missed notifications
- Requires thorough testing due to workflow changes

### Enhanced Tracking (Priority 3)
**Recommended:** Deploy Priority 3 (v0.13.0) within 6-8 weeks:
- Provides comprehensive compliance tracking
- Enables audit-ready reporting
- Requires scheduled task implementation
- Can be delayed if needed without compromising core compliance

### Alternative: Combined Deployment
If preferred, Priority 1 and Priority 2 could be combined into a single v0.11.0 release, though this would extend testing time to 6-8 days and increase deployment risk.

---

## Next Steps

1. **Review this implementation plan** with WHS Officer and stakeholders
2. **Confirm priorities and timeline** - Agree on phased vs. combined approach
3. **Begin Priority 1 development** - Quick visual improvements
4. **Schedule testing windows** - Coordinate with WHS Officer availability
5. **Document WorkSafe QLD procedures** - Ensure workflow matches actual process
6. **Plan communication** - Notify staff of new notifiable incident procedures

---

## Appendix: Queensland WHS Legal Requirements

### Work Health and Safety Act 2011 (Qld)

**Section 38: Notifiable Incidents**
- Person conducting business or undertaking (PCBU) must notify regulator immediately
- Notification required by fastest means available (phone)

**Section 39: Written Notice**
- Written notice required within 48 hours
- Must include prescribed information

### Work Health and Safety Regulation 2011 (Qld)

**Part 3.1: Notifiable Incidents**

**Regulation 34: Definition of Notifiable Incident**
1. Death of a person
2. Serious injury or illness
3. Dangerous incident

**Regulation 35: Serious Injury or Illness**
Includes:
- Requires immediate treatment as in-patient in hospital
- Immediate treatment for:
  - Amputation
  - Serious head injury
  - Serious eye injury
  - Serious burn
  - Spinal injury
  - Loss of bodily function
  - Serious lacerations

**Regulation 36: Dangerous Incident**
Includes:
- Uncontrolled release/escape/spillage of substance
- Uncontrolled implosion/explosion/fire
- Escape of gas/steam/pressurized substance
- Electric shock
- Fall/release of object from height
- Damage to or failure of plant
- Collapse/failure/malfunction of excavation/shaft
- Inrush of water/mud/gas
- Interruption of main system of ventilation

**Regulation 37: Notification Requirements**
- Immediate notification by fastest means (phone: 1300 369 915)
- Must not disturb incident site (except for rescue/safety)
- Written notice within 48 hours
- Must include: date, time, location, description, identity of persons involved

### Penalties for Non-Compliance
- Individual: Up to $100,000
- Body corporate: Up to $500,000
- Failure to preserve incident site: Additional penalties

### WorkSafe Queensland Contact Information
- **Phone (24/7):** 1300 369 915
- **Website:** https://www.worksafe.qld.gov.au/notify
- **Written Notification:** Submit via online form or email

---

**Document End**

*This implementation plan should be reviewed and approved by WHS Officer and relevant stakeholders before proceeding with development.*
