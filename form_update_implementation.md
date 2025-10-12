# WHS Incident Form Modernization - Implementation Plan

**Project:** Cook Shire Council WHS Portal - Incident Reporting Enhancement
**Version:** 1.0
**Date:** 2025-10-09
**Target Release:** csc.whs v0.7.8

---

## 🎯 Project Overview

### Objective
Modernize the WHS Incident reporting form to align with the approved MS Forms specification while leveraging LDAP/Active Directory integration for intelligent data population and validation.

### Scope
Update `csc.whs` addon with:
- Enhanced incident content type matching MS Forms fields
- LDAP-integrated form with autocomplete user lookup
- Mobile-optimized anonymous reporting interface
- Adaptive single form (authenticated vs anonymous)

### Key Benefits
- **60% reduction** in manual data entry for authenticated users
- **Improved data accuracy** through LDAP integration
- **Better reporting** with organizational structure correlation
- **Consistent with approved forms** matching WHS Officer requirements
- **Mobile-friendly** for field incident reporting

---

## 📐 Architecture Decisions

### Confirmed Decisions
1. **Single Adaptive Form** - One form adapts based on authentication status
2. **LDAP User Lookup** - Autocomplete search for employees
3. **Auto-Population** - Division, relationship, manager from LDAP
4. **Multi-Select Incident Types** - Q7 allows multiple selections
5. **WHS Theme Styling** - Colors: #1e3a5f (dark blue), #5b9bd5 (light blue)
6. **Store LDAP Reference** - Keep username for future queries and reporting

### ✅ Decisions Approved (2025-10-09)

**Decision Point 1: Lock Auto-Populated Fields**
- **APPROVED:** Option A - Lock fields for employees to prevent data inconsistency
- Auto-populated division and relationship fields will be read-only when user selected from LDAP

**Decision Point 2: Anonymous Form Email Requirement**
- **APPROVED:** Option A - Email is required for anonymous reporters
- Enables confirmation emails and follow-up communication

**Decision Point 3: Q6 Location Field Type - GPS INTEGRATION**
- **APPROVED:** GPS Integration with OpenStreetMap/Google Maps
- **Implementation:**
  - Add GPS capture button for mobile devices
  - Capture latitude/longitude coordinates from device geolocation
  - Store coordinates in separate fields for mapping/reporting
  - Reverse geocode to human-readable address
  - Fall back to manual text entry if GPS unavailable or user prefers
  - Since most council phones are Android with Google Maps, integrate with Google Maps API
- **Additional Schema Fields Required:**
  - `location_latitude` (Float)
  - `location_longitude` (Float)
  - `location_accuracy` (Float, in meters)
  - `location_method` (Choice: 'gps', 'manual')
- **Note:** This adds ~5-6 hours to Phase 1 (schema) and Phase 3 (GPS integration UI/JS)

**Decision Point 4: Backward Compatibility**
- **APPROVED:** No backward compatibility needed
- All existing incident records are test data and can be deleted
- This simplifies implementation and removes migration overhead
- We can remove old `category` field entirely

**Decision Point 5: Manager Notification Workflow**
- **APPROVED:** Option B - No automatic manager notification workflow for now
- Manual assignment will be used initially
- Can be added in a future phase if needed

---

## 🗂️ Phase Breakdown

---

## PHASE 1: Schema & Vocabulary Updates

**Duration:** 5.5 hours
**Dependencies:** None
**Priority:** HIGH

### 1.1 Update `interfaces.py` - Incident Schema

**File:** `/csc/src/csc/whs/interfaces.py`

**Task:** Add new fields to IIncident schema

**New Fields:**

```python
class IIncident(model.Schema):
    """WHS Incident schema - Enhanced with MS Forms fields"""

    # ========================================
    # SECTION 1: INCIDENT TYPE AND PERSON(S) INVOLVED
    # ========================================

    # Q1: Date of Incident - EXISTING (keep as is)
    occurred_at = schema.Datetime(...)

    # Q2: Incident time - EXISTING (part of occurred_at)

    # Q3: Person's name who was injured or principally involved
    # NEW: Store both LDAP reference and display name
    injured_person_name = schema.TextLine(
        title=u"Person's name who was injured or principally involved in the incident",
        required=True,
        description=u"Full name of the person involved in the incident",
    )

    injured_person_username = schema.TextLine(
        title=u"Person's username (LDAP)",
        required=False,
        description=u"LDAP username if person is a Cook Shire Council employee",
    )

    # Q4: Person's relationship to Cook Shire Council
    # NEW
    person_relationship = schema.Choice(
        title=u"Person's relationship to Cook Shire Council",
        required=True,
        description=u"This is in reference to the principal person involved in the incident",
        vocabulary="csc.whs.PersonRelationshipVocabulary",
    )

    # Q5: Division of person injured, or principally involved in incident
    # NEW
    division = schema.Choice(
        title=u"Division of person injured, or principally involved in incident",
        required=False,  # Only required if Employee
        description=u"Select the directorate most associated with the incident (e.g. that employed by, who engaged contractor, who manages associated property)",
        vocabulary="csc.whs.DirectorateVocabulary",
    )

    # Q6: The location of incident
    # CHANGED: From Choice to Text for more flexibility
    location = schema.Text(
        title=u"The location of incident",
        required=True,
        description=u"Enter full address, or closest address and detail of location",
    )

    # Q7: What type of incident has occurred?
    # CHANGED: From single Choice to List (multi-select)
    incident_types = schema.List(
        title=u"What type of incident has occurred?",
        required=True,
        description=u"You may not know the extent of injury and if medical treatment or lost time is involved, or if notifiable under legislation; complete to the best of your knowledge. Select all that apply.",
        value_type=schema.Choice(
            vocabulary="csc.whs.IncidentTypeVocabulary"
        ),
        min_length=1,
    )

    # ========================================
    # SECTION 2: REPORTING INFORMATION
    # ========================================

    # Q8: Was supervisor / manager, for the person involved in the incident, notified?
    # NEW
    supervisor_notified = schema.Choice(
        title=u"Was supervisor / manager, for the person involved in the incident, notified?",
        required=True,
        vocabulary="csc.whs.SupervisorNotifiedVocabulary",
    )

    # Q9: Date reported - EXISTING (keep as is)
    reported_at = schema.Datetime(...)

    # Q10: Reported by
    # ENHANCED: Store name (auto-filled for authenticated users)
    reported_by_name = schema.TextLine(
        title=u"Reported by",
        required=True,
        description=u"Name of person reporting this incident",
    )

    # Q11: Witness full name - EXISTING (keep as is)
    # Q12: Witness contact number - EXISTING (keep as is)
    witnesses = schema.Text(
        title=u"Witnesses",
        required=False,
        description=u"If there is more than one witness, or others involved, their names and details can be provided here",
    )

    # ========================================
    # EXISTING FIELDS (keep unchanged for backward compatibility)
    # ========================================
    category = schema.Choice(...)  # Keep for old incidents
    severity = schema.Choice(...)
    immediate_actions = schema.Text(...)
    persons_involved = schema.Text(...)
    injury_type = schema.Choice(...)
    treatment = schema.Text(...)
    body_part = schema.Choice(...)
    equipment_plant = schema.Text(...)
    property_damage = schema.Text(...)
    root_cause = schema.Text(...)
    corrective_actions = schema.Text(...)
    notifiable_to_regulator = schema.Bool(...)
    regulator_reference = schema.TextLine(...)
    photo_1 = NamedBlobFile(...)
    photo_2 = NamedBlobFile(...)
    photo_3 = NamedBlobFile(...)
    confidential = schema.Bool(...)
    reference_code = schema.TextLine(...)
```

**Deliverables:**
- Updated `interfaces.py` with new fields
- Fields properly documented with help text
- Type hints and validation rules

**Testing:**
- Schema loads without errors
- Fields appear in Plone control panel
- Field types validate correctly

**Time Estimate:** 2 hours

---

### 1.2 Create New Vocabularies

**File:** `/csc/src/csc/whs/vocabularies.py` (create new file)

**Task:** Implement all required vocabularies

**Code Structure:**

```python
# -*- coding: utf-8 -*-
from plone import api
from zope.interface import provider
from zope.schema.interfaces import IVocabularyFactory
from zope.schema.vocabulary import SimpleTerm, SimpleVocabulary
import logging

logger = logging.getLogger('csc.whs.vocabularies')


@provider(IVocabularyFactory)
def DirectorateVocabulary(context):
    """Cook Shire Council Directorates/Divisions

    Based on organizational structure as of 2025-09-01
    """
    terms = [
        SimpleTerm(value='office-of-ceo', title=u'Office of the CEO'),
        SimpleTerm(value='growth-and-liveability', title=u'Growth and Liveability'),
        SimpleTerm(value='infrastructure', title=u'Infrastructure'),
        SimpleTerm(value='people-and-performance', title=u'People and Performance'),
    ]
    return SimpleVocabulary(terms)


@provider(IVocabularyFactory)
def IncidentTypeVocabulary(context):
    """Incident type categories as per WHS MS Forms

    Multiple types can be selected for a single incident
    """
    terms = [
        SimpleTerm(value='fai', title=u'First Aid Injury (FAI)'),
        SimpleTerm(value='lti', title=u'Lost Time Injury (LTI)'),
        SimpleTerm(value='mti', title=u'Medical Treatment Injury (MTI)'),
        SimpleTerm(value='near-miss', title=u'Near Miss (NM)'),
        SimpleTerm(value='non-compliance', title=u'Non-compliance (NC)'),
        SimpleTerm(value='notifiable', title=u'Notifiable Incident'),
        SimpleTerm(value='other', title=u'Other incident'),
        SimpleTerm(value='property-damage', title=u'Property Damage (incl. vehicle)'),
    ]
    return SimpleVocabulary(terms)


@provider(IVocabularyFactory)
def PersonRelationshipVocabulary(context):
    """Relationship of injured person to Cook Shire Council"""
    terms = [
        SimpleTerm(value='employee', title=u'Employee'),
        SimpleTerm(value='contractor', title=u'Contractor / Sub-contractor'),
        SimpleTerm(value='visitor', title=u'Visitor to Cook Shire Council premises / member of the public'),
    ]
    return SimpleVocabulary(terms)


@provider(IVocabularyFactory)
def SupervisorNotifiedVocabulary(context):
    """Was the supervisor/manager notified?"""
    terms = [
        SimpleTerm(value='yes', title=u'Yes'),
        SimpleTerm(value='no', title=u'No'),
        SimpleTerm(value='unsure', title=u'Unsure'),
    ]
    return SimpleVocabulary(terms)


@provider(IVocabularyFactory)
def LDAPUserVocabulary(context):
    """Dynamic vocabulary of all active LDAP users

    Provides autocomplete functionality for user selection
    Cached for 5 minutes for performance
    """
    try:
        # Get all users from Plone (which includes LDAP users)
        users = api.user.get_users()

        terms = []
        for user in users:
            username = user.getId()
            fullname = user.getProperty('fullname', username)

            # Create term with username as value, fullname as title
            terms.append(
                SimpleTerm(
                    value=username,
                    token=username,
                    title=fullname
                )
            )

        # Sort by fullname
        terms.sort(key=lambda t: t.title.lower())

        return SimpleVocabulary(terms)

    except Exception as e:
        logger.error(f"Error building LDAP user vocabulary: {e}")
        return SimpleVocabulary([])
```

**Deliverables:**
- All 5 vocabularies implemented
- Proper error handling
- Logging for debugging

**Testing:**
- Each vocabulary returns expected values
- LDAP vocabulary queries successfully
- Terms are properly sorted

**Time Estimate:** 3 hours

---

### 1.3 Register Vocabularies in ZCML

**File:** `/csc/src/csc/whs/configure.zcml`

**Task:** Register vocabulary utilities

**Add to configure.zcml:**

```xml
<!-- Vocabularies -->
<utility
    component=".vocabularies.DirectorateVocabulary"
    name="csc.whs.DirectorateVocabulary"
    />

<utility
    component=".vocabularies.IncidentTypeVocabulary"
    name="csc.whs.IncidentTypeVocabulary"
    />

<utility
    component=".vocabularies.PersonRelationshipVocabulary"
    name="csc.whs.PersonRelationshipVocabulary"
    />

<utility
    component=".vocabularies.SupervisorNotifiedVocabulary"
    name="csc.whs.SupervisorNotifiedVocabulary"
    />

<utility
    component=".vocabularies.LDAPUserVocabulary"
    name="csc.whs.LDAPUserVocabulary"
    />
```

**Deliverables:**
- Vocabularies registered and accessible

**Testing:**
- Plone starts without errors
- Vocabularies accessible via `getUtility`

**Time Estimate:** 30 minutes

---

## PHASE 2: LDAP Integration Layer

**Duration:** 7 hours
**Dependencies:** Phase 1
**Priority:** HIGH

### 2.1 Create LDAP Helper Utilities

**File:** `/csc/src/csc/whs/ldap_utils.py` (NEW)

**Task:** Create reusable LDAP query functions

**Code:**

```python
# -*- coding: utf-8 -*-
"""LDAP utilities for WHS incident reporting

Provides functions to query Active Directory via pas.plugins.ldap
Integrates with existing cook.whs.barceloneta LDAP configuration
"""

from plone import api
from cook.whs.barceloneta.utils import extract_cn_from_dn
import logging

logger = logging.getLogger('csc.whs.ldap_utils')

# Directorate mapping based on department names
DEPARTMENT_TO_DIRECTORATE = {
    # Office of the CEO
    'governance': 'office-of-ceo',
    'records': 'office-of-ceo',
    'grants': 'office-of-ceo',

    # Growth and Liveability
    'regional development': 'growth-and-liveability',
    'community lifestyle': 'growth-and-liveability',
    'planning': 'growth-and-liveability',
    'environment': 'growth-and-liveability',
    'biosecurity': 'growth-and-liveability',
    'local laws': 'growth-and-liveability',
    'buildings': 'growth-and-liveability',
    'facilities': 'growth-and-liveability',
    'communications': 'growth-and-liveability',
    'ict': 'growth-and-liveability',
    'information': 'growth-and-liveability',
    'disaster': 'growth-and-liveability',
    'finance': 'growth-and-liveability',
    'financial': 'growth-and-liveability',

    # Infrastructure
    'water': 'infrastructure',
    'wastewater': 'infrastructure',
    'waste': 'infrastructure',
    'engineering': 'infrastructure',
    'fleet': 'infrastructure',
    'workshop': 'infrastructure',
    'roads': 'infrastructure',
    'civil': 'infrastructure',
    'project': 'infrastructure',
    'parks': 'infrastructure',
    'gardens': 'infrastructure',
    'airports': 'infrastructure',
    'drfa': 'infrastructure',

    # People and Performance
    'hr': 'people-and-performance',
    'human resources': 'people-and-performance',
    'whs': 'people-and-performance',
    'workplace health': 'people-and-performance',
    'safety': 'people-and-performance',
}


def search_ldap_users(query, limit=20):
    """Search for users in LDAP by name or username

    Args:
        query (str): Search query (partial name or username)
        limit (int): Maximum results to return

    Returns:
        list: List of dicts with user info

    Example:
        >>> search_ldap_users('john')
        [
            {
                'username': 'jsmith',
                'fullname': 'John Smith',
                'email': 'john.smith@cook.qld.gov.au',
                'department': 'Water & Wastewater'
            },
            ...
        ]
    """
    try:
        query_lower = query.lower()
        results = []

        # Get all users (LDAP + local)
        users = api.user.get_users()

        for user in users:
            username = user.getId()
            fullname = user.getProperty('fullname', '')
            email = user.getProperty('email', '')

            # Match on username or fullname
            if (query_lower in username.lower() or
                query_lower in fullname.lower()):

                results.append({
                    'username': username,
                    'fullname': fullname,
                    'email': email,
                    'department': user.getProperty('department', ''),
                })

                if len(results) >= limit:
                    break

        logger.info(f"LDAP search for '{query}' returned {len(results)} results")
        return results

    except Exception as e:
        logger.error(f"Error searching LDAP users: {e}", exc_info=True)
        return []


def get_user_details(username):
    """Get full LDAP details for a user

    Args:
        username (str): Username to look up

    Returns:
        dict: Full user details including directorate mapping

    Example:
        >>> get_user_details('jsmith')
        {
            'username': 'jsmith',
            'fullname': 'John Smith',
            'email': 'john.smith@cook.qld.gov.au',
            'phone': '07 4000 1234',
            'mobile': '0400 123 456',
            'department': 'Water & Wastewater',
            'directorate': 'infrastructure',
            'job_title': 'Water Treatment Operator',
            'manager_dn': 'CN=Robyn Maddalena,OU=...',
            'manager_name': 'Robyn Maddalena'
        }
    """
    try:
        user = api.user.get(username=username)
        if not user:
            logger.warning(f"User not found: {username}")
            return None

        # Get basic properties
        fullname = user.getProperty('fullname', '')
        email = user.getProperty('email', '')
        phone = user.getProperty('phone', '')
        mobile = user.getProperty('mobile', '')
        department = user.getProperty('department', '')
        job_title = user.getProperty('job_title', '')
        manager_dn = user.getProperty('manager', '')

        # Extract manager name from DN
        manager_name = extract_cn_from_dn(manager_dn) if manager_dn else ''

        # Map department to directorate
        directorate = get_user_directorate(department)

        return {
            'username': username,
            'fullname': fullname,
            'email': email,
            'phone': phone,
            'mobile': mobile,
            'department': department,
            'directorate': directorate,
            'job_title': job_title,
            'manager_dn': manager_dn,
            'manager_name': manager_name,
        }

    except Exception as e:
        logger.error(f"Error getting user details for {username}: {e}", exc_info=True)
        return None


def get_user_manager_name(username):
    """Extract and return manager's name for a user

    Args:
        username (str): Username to look up

    Returns:
        str: Manager's full name, or empty string if not found
    """
    try:
        user_details = get_user_details(username)
        if user_details:
            return user_details.get('manager_name', '')
        return ''
    except Exception as e:
        logger.error(f"Error getting manager name for {username}: {e}")
        return ''


def get_user_directorate(department):
    """Map a department name to one of the 4 directorates

    Args:
        department (str): Department name from LDAP

    Returns:
        str: Directorate code (office-of-ceo, growth-and-liveability,
             infrastructure, people-and-performance)
             Returns empty string if no match

    Example:
        >>> get_user_directorate('Water & Wastewater')
        'infrastructure'
    """
    if not department:
        return ''

    department_lower = department.lower()

    # Check for keyword matches
    for keyword, directorate in DEPARTMENT_TO_DIRECTORATE.items():
        if keyword in department_lower:
            return directorate

    logger.warning(f"No directorate mapping found for department: {department}")
    return ''


def is_ldap_available():
    """Check if LDAP connection is available

    Returns:
        bool: True if LDAP is accessible, False otherwise
    """
    try:
        # Try to get any user to test connection
        users = api.user.get_users()
        return len(users) > 0
    except Exception as e:
        logger.error(f"LDAP connection check failed: {e}")
        return False
```

**Deliverables:**
- LDAP query functions
- Department to directorate mapping
- Error handling and logging
- Connection check utility

**Testing:**
- User search returns correct results
- User details properly extracted
- Directorate mapping accurate
- Graceful handling of LDAP unavailable

**Time Estimate:** 4 hours

---

### 2.2 Create AJAX API for User Lookup

**File:** `/csc/src/csc/whs/browser/ldap_api.py` (NEW)

**Task:** Create JSON API endpoints for JavaScript to query LDAP

**Code:**

```python
# -*- coding: utf-8 -*-
"""AJAX API endpoints for LDAP user lookup

Provides JSON endpoints for JavaScript autocomplete and user details
"""

from Products.Five.browser import BrowserView
from plone import api
from csc.whs.ldap_utils import search_ldap_users, get_user_details
import json
import logging

logger = logging.getLogger('csc.whs.ldap_api')


class SearchUsersView(BrowserView):
    """Search for users by name or username

    URL: @@search-users?q=john

    Returns JSON:
    {
        "success": true,
        "users": [
            {
                "username": "jsmith",
                "fullname": "John Smith",
                "email": "john.smith@cook.qld.gov.au",
                "department": "Water & Wastewater"
            }
        ]
    }
    """

    def __call__(self):
        # Set JSON content type
        self.request.response.setHeader('Content-Type', 'application/json')

        # Get query parameter
        query = self.request.get('q', '').strip()

        if not query or len(query) < 2:
            return json.dumps({
                'success': False,
                'error': 'Query must be at least 2 characters'
            })

        try:
            # Search LDAP
            users = search_ldap_users(query, limit=20)

            return json.dumps({
                'success': True,
                'users': users,
                'count': len(users)
            })

        except Exception as e:
            logger.error(f"Error in search-users API: {e}", exc_info=True)
            return json.dumps({
                'success': False,
                'error': str(e)
            })


class GetUserInfoView(BrowserView):
    """Get full details for a specific user

    URL: @@get-user-info?username=jsmith

    Returns JSON:
    {
        "success": true,
        "user": {
            "username": "jsmith",
            "fullname": "John Smith",
            "email": "john.smith@cook.qld.gov.au",
            "phone": "07 4000 1234",
            "department": "Water & Wastewater",
            "directorate": "infrastructure",
            "manager_name": "Robyn Maddalena"
        }
    }
    """

    def __call__(self):
        # Set JSON content type
        self.request.response.setHeader('Content-Type', 'application/json')

        # Get username parameter
        username = self.request.get('username', '').strip()

        if not username:
            return json.dumps({
                'success': False,
                'error': 'Username parameter required'
            })

        try:
            # Get user details from LDAP
            user_details = get_user_details(username)

            if not user_details:
                return json.dumps({
                    'success': False,
                    'error': f'User not found: {username}'
                })

            return json.dumps({
                'success': True,
                'user': user_details
            })

        except Exception as e:
            logger.error(f"Error in get-user-info API: {e}", exc_info=True)
            return json.dumps({
                'success': False,
                'error': str(e)
            })
```

**Register in ZCML:**

**File:** `/csc/src/csc/whs/browser/configure.zcml`

```xml
<!-- LDAP API Endpoints -->
<browser:page
    name="search-users"
    for="*"
    class=".ldap_api.SearchUsersView"
    permission="zope2.View"
    />

<browser:page
    name="get-user-info"
    for="*"
    class=".ldap_api.GetUserInfoView"
    permission="zope2.View"
    />
```

**Deliverables:**
- Two JSON API endpoints
- Proper error handling
- CORS headers if needed

**Testing:**
- API returns valid JSON
- Search works with partial names
- User details complete and accurate
- Error responses properly formatted

**Time Estimate:** 3 hours

---

## PHASE 3: Form Template & Widgets

**Duration:** 15 hours
**Dependencies:** Phase 1, 2
**Priority:** HIGH

### 3.1 Create Enhanced Incident Report Form Template

**File:** `/csc/src/csc/whs/browser/templates/report_incident.pt` (NEW)

**Task:** Create mobile-optimized, adaptive form template

**Template Structure:**

```html
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:tal="http://xml.zope.org/namespaces/tal"
      xmlns:metal="http://xml.zope.org/namespaces/metal"
      xmlns:i18n="http://xml.zope.org/namespaces/i18n"
      lang="en"
      metal:use-macro="context/main_template/macros/master"
      i18n:domain="csc.whs">

<head>
    <metal:block fill-slot="style_slot">
        <link rel="stylesheet" type="text/css"
              href="++resource++csc.whs/incident_form.css" />
    </metal:block>
    <metal:block fill-slot="javascript_head_slot">
        <script type="text/javascript"
                src="++resource++csc.whs/incident_form.js"></script>
    </metal:block>
</head>

<body>
<metal:main fill-slot="main">
    <tal:main-macro metal:define-macro="main">

        <div class="whs-incident-form-container">

            <!-- Form Header -->
            <h1 class="whs-form-title">Incident Report</h1>

            <div class="whs-form-intro">
                <p tal:condition="view/is_authenticated">
                    Hi <strong tal:content="view/current_user_fullname">User</strong>.
                    Some fields will be automatically filled from your profile.
                </p>
                <p tal:condition="not:view/is_authenticated">
                    Thank you for reporting this incident. Please complete all required fields marked with
                    <span class="required-indicator">*</span>
                </p>
                <p class="whs-form-note">
                    <strong>Note:</strong> A red asterisk (*) indicates mandatory fields that must be completed.
                </p>
            </div>

            <!-- Form -->
            <form method="post"
                  action="@@report-incident"
                  enctype="multipart/form-data"
                  class="whs-incident-form"
                  id="incident-report-form"
                  data-authenticated="true" tal:attributes="data-authenticated view/is_authenticated">

                <!-- CSRF Token -->
                <input type="hidden"
                       name="_authenticator"
                       tal:attributes="value view/authenticator" />

                <!-- ========================================
                     SECTION 1: INCIDENT TYPE AND PERSON(S) INVOLVED
                     ======================================== -->
                <section class="whs-form-section" id="section-incident-type">
                    <h2 class="whs-section-title">Incident Type and Person(s) Involved</h2>

                    <!-- Q1: Date of Incident -->
                    <div class="whs-form-field whs-field-required">
                        <label for="occurred_date">
                            1. Date of Incident <span class="required">*</span>
                        </label>
                        <p class="field-description">Please input date (dd/MM/yyyy)</p>
                        <input type="date"
                               id="occurred_date"
                               name="occurred_date"
                               required="required"
                               class="whs-input whs-date-input" />
                    </div>

                    <!-- Q2: Incident Time -->
                    <div class="whs-form-field whs-field-required">
                        <label for="occurred_time">
                            2. Incident time <span class="required">*</span>
                        </label>
                        <p class="field-description">If you are unsure, enter an approx. time - 12hr format include am/pm</p>
                        <input type="time"
                               id="occurred_time"
                               name="occurred_time"
                               required="required"
                               class="whs-input whs-time-input" />
                    </div>

                    <!-- Q3: Person's Name -->
                    <div class="whs-form-field whs-field-required">
                        <label for="injured_person_name">
                            3. Person's name who was injured or principally involved in the incident <span class="required">*</span>
                        </label>

                        <!-- For Authenticated Users: LDAP Autocomplete -->
                        <div tal:condition="view/is_authenticated" class="whs-ldap-search-container">
                            <input type="text"
                                   id="person-search-input"
                                   class="whs-input whs-ldap-search"
                                   placeholder="Start typing employee name..."
                                   autocomplete="off" />
                            <div id="person-search-results" class="whs-autocomplete-results"></div>

                            <!-- Hidden fields for selected user -->
                            <input type="hidden" id="injured_person_name" name="injured_person_name" required="required" />
                            <input type="hidden" id="injured_person_username" name="injured_person_username" />

                            <!-- Display selected user -->
                            <div id="selected-user-display" class="whs-selected-user" style="display: none;">
                                <strong>Selected:</strong> <span id="selected-user-name"></span>
                                <button type="button" class="whs-clear-selection">Change</button>
                            </div>

                            <p class="field-description">
                                Search for a Cook Shire Council employee, or
                                <a href="#" id="enter-manual-name">enter name manually</a>
                            </p>
                        </div>

                        <!-- For Anonymous Users: Simple Text Input -->
                        <div tal:condition="not:view/is_authenticated">
                            <input type="text"
                                   id="injured_person_name"
                                   name="injured_person_name"
                                   required="required"
                                   class="whs-input"
                                   placeholder="Full name" />
                        </div>
                    </div>

                    <!-- Q4: Person's Relationship -->
                    <div class="whs-form-field whs-field-required">
                        <label>
                            4. Person's relationship to Cook Shire Council? <span class="required">*</span>
                        </label>
                        <p class="field-description">
                            This is in reference to the principal person. For example, if an employee was involved
                            in a car accident and injured themselves, and a member of the public was also injured
                            in the same incident, the selection would be employee.
                        </p>

                        <div class="whs-radio-group">
                            <label class="whs-radio-label">
                                <input type="radio"
                                       name="person_relationship"
                                       value="employee"
                                       required="required"
                                       id="relationship-employee" />
                                Employee
                            </label>

                            <label class="whs-radio-label">
                                <input type="radio"
                                       name="person_relationship"
                                       value="contractor"
                                       id="relationship-contractor" />
                                Contractor / Sub-contractor
                            </label>

                            <label class="whs-radio-label">
                                <input type="radio"
                                       name="person_relationship"
                                       value="visitor"
                                       id="relationship-visitor" />
                                Visitor to Cook Shire Council premises / member of the public
                            </label>
                        </div>
                    </div>

                    <!-- Q5: Division -->
                    <div class="whs-form-field">
                        <label for="division">
                            5. Division of person injured, or principally involved in incident
                        </label>
                        <p class="field-description">
                            Select the directorate most associated with the incident e.g. that employed by,
                            who engaged contractor, who manages associated property
                        </p>

                        <select id="division"
                                name="division"
                                class="whs-select">
                            <option value="">-- Select Division --</option>
                            <option value="office-of-ceo">Office of the CEO</option>
                            <option value="growth-and-liveability">Growth and Liveability</option>
                            <option value="infrastructure">Infrastructure</option>
                            <option value="people-and-performance">People and Performance</option>
                        </select>
                    </div>

                    <!-- Q6: Location -->
                    <div class="whs-form-field whs-field-required">
                        <label for="location">
                            6. The location of incident <span class="required">*</span>
                        </label>
                        <p class="field-description">Enter full address, or closest address and detail of location</p>

                        <textarea id="location"
                                  name="location"
                                  required="required"
                                  rows="3"
                                  class="whs-textarea"
                                  placeholder="e.g., 123 Main Street, Cooktown QLD 4895"></textarea>
                    </div>

                    <!-- Q7: Incident Types (Multi-select) -->
                    <div class="whs-form-field whs-field-required">
                        <label>
                            7. What type of incident has occurred? <span class="required">*</span>
                        </label>
                        <p class="field-description">
                            You may not know the extent of injury and if medical treatment or lost time is involved,
                            or if notifiable under legislation; complete to the best of your knowledge.
                            <strong>Select all that apply.</strong>
                        </p>

                        <div class="whs-checkbox-group">
                            <label class="whs-checkbox-label">
                                <input type="checkbox" name="incident_types:list" value="fai" />
                                First Aid Injury (FAI)
                            </label>

                            <label class="whs-checkbox-label">
                                <input type="checkbox" name="incident_types:list" value="lti" />
                                Lost Time Injury (LTI)
                            </label>

                            <label class="whs-checkbox-label">
                                <input type="checkbox" name="incident_types:list" value="mti" />
                                Medical Treatment Injury (MTI)
                            </label>

                            <label class="whs-checkbox-label">
                                <input type="checkbox" name="incident_types:list" value="near-miss" />
                                Near Miss (NM)
                            </label>

                            <label class="whs-checkbox-label">
                                <input type="checkbox" name="incident_types:list" value="non-compliance" />
                                Non-compliance (NC)
                            </label>

                            <label class="whs-checkbox-label">
                                <input type="checkbox" name="incident_types:list" value="notifiable" />
                                Notifiable Incident
                            </label>

                            <label class="whs-checkbox-label">
                                <input type="checkbox" name="incident_types:list" value="other" />
                                Other incident
                            </label>

                            <label class="whs-checkbox-label">
                                <input type="checkbox" name="incident_types:list" value="property-damage" />
                                Property Damage (incl. vehicle)
                            </label>
                        </div>
                        <div id="incident-types-error" class="whs-field-error" style="display: none;">
                            Please select at least one incident type
                        </div>
                    </div>

                </section>

                <!-- ========================================
                     SECTION 2: REPORTING INFORMATION
                     ======================================== -->
                <section class="whs-form-section" id="section-reporting">
                    <h2 class="whs-section-title">Reporting Information</h2>

                    <!-- Q8: Supervisor Notified -->
                    <div class="whs-form-field whs-field-required">
                        <label>
                            8. Was supervisor / manager, for the person involved in the incident, notified? <span class="required">*</span>
                        </label>

                        <div class="whs-radio-group">
                            <label class="whs-radio-label">
                                <input type="radio"
                                       name="supervisor_notified"
                                       value="yes"
                                       required="required" />
                                Yes
                            </label>

                            <label class="whs-radio-label">
                                <input type="radio"
                                       name="supervisor_notified"
                                       value="no" />
                                No
                            </label>

                            <label class="whs-radio-label">
                                <input type="radio"
                                       name="supervisor_notified"
                                       value="unsure" />
                                Unsure
                            </label>
                        </div>
                    </div>

                    <!-- Q9: Date Reported (Auto-filled with today) -->
                    <div class="whs-form-field whs-field-required">
                        <label for="reported_date">
                            9. Date reported <span class="required">*</span>
                        </label>
                        <p class="field-description">Please input date (dd/MM/yyyy)</p>
                        <input type="date"
                               id="reported_date"
                               name="reported_date"
                               required="required"
                               class="whs-input whs-date-input"
                               tal:attributes="value view/today_iso" />
                    </div>

                    <!-- Q10: Reported By -->
                    <div class="whs-form-field whs-field-required">
                        <label for="reported_by_name">
                            10. Reported by <span class="required">*</span>
                        </label>

                        <input type="text"
                               id="reported_by_name"
                               name="reported_by_name"
                               required="required"
                               class="whs-input"
                               tal:attributes="value view/current_user_fullname;
                                               readonly view/is_authenticated" />

                        <p class="field-description" tal:condition="view/is_authenticated">
                            This field is automatically filled with your name
                        </p>
                    </div>

                    <!-- Q11: Witness Full Name -->
                    <div class="whs-form-field">
                        <label for="witness_name">
                            11. Witness full name
                        </label>
                        <p class="field-description">
                            If there is more than one witness, or others involved, their names and details
                            can be provided in the next section under Incident Detail
                        </p>

                        <input type="text"
                               id="witness_name"
                               name="witness_name"
                               class="whs-input" />
                    </div>

                    <!-- Q12: Witness Contact Number -->
                    <div class="whs-form-field">
                        <label for="witness_contact">
                            12. Witness contact number
                        </label>

                        <input type="tel"
                               id="witness_contact"
                               name="witness_contact"
                               class="whs-input"
                               placeholder="e.g., 07 4000 1234 or 0400 123 456" />
                    </div>

                </section>

                <!-- ========================================
                     SECTION 3: INCIDENT DETAILS
                     ======================================== -->
                <section class="whs-form-section" id="section-details">
                    <h2 class="whs-section-title">Incident Details</h2>

                    <!-- Description -->
                    <div class="whs-form-field">
                        <label for="description">
                            What happened?
                        </label>
                        <p class="field-description">Provide a detailed description of the incident</p>

                        <textarea id="description"
                                  name="description"
                                  rows="6"
                                  class="whs-textarea"
                                  placeholder="Describe the incident in detail..."></textarea>
                    </div>

                    <!-- Immediate Actions -->
                    <div class="whs-form-field">
                        <label for="immediate_actions">
                            Immediate actions taken
                        </label>
                        <p class="field-description">What actions were taken immediately after the incident?</p>

                        <textarea id="immediate_actions"
                                  name="immediate_actions"
                                  rows="4"
                                  class="whs-textarea"></textarea>
                    </div>

                    <!-- Additional Witnesses/People Involved -->
                    <div class="whs-form-field">
                        <label for="witnesses">
                            Additional witnesses or people involved
                        </label>
                        <p class="field-description">List additional names and contact details (one per line)</p>

                        <textarea id="witnesses"
                                  name="witnesses"
                                  rows="4"
                                  class="whs-textarea"></textarea>
                    </div>

                </section>

                <!-- ========================================
                     SECTION 4: ATTACHMENTS
                     ======================================== -->
                <section class="whs-form-section" id="section-attachments">
                    <h2 class="whs-section-title">Attachments (Optional)</h2>

                    <p class="field-description">
                        You can upload up to 3 photos or documents (max 10MB each).
                        Accepted formats: JPG, PNG, PDF, Word, Excel
                    </p>

                    <div class="whs-form-field">
                        <label for="photo_1">Photo/Document 1</label>
                        <input type="file"
                               id="photo_1"
                               name="photo_1"
                               class="whs-file-input"
                               accept="image/*,.pdf,.doc,.docx,.xls,.xlsx" />
                    </div>

                    <div class="whs-form-field">
                        <label for="photo_2">Photo/Document 2</label>
                        <input type="file"
                               id="photo_2"
                               name="photo_2"
                               class="whs-file-input"
                               accept="image/*,.pdf,.doc,.docx,.xls,.xlsx" />
                    </div>

                    <div class="whs-form-field">
                        <label for="photo_3">Photo/Document 3</label>
                        <input type="file"
                               id="photo_3"
                               name="photo_3"
                               class="whs-file-input"
                               accept="image/*,.pdf,.doc,.docx,.xls,.xlsx" />
                    </div>
                </section>

                <!-- ========================================
                     FORM ACTIONS
                     ======================================== -->
                <div class="whs-form-actions">
                    <button type="submit" class="whs-button whs-button-primary">
                        Submit Incident Report
                    </button>
                    <button type="button" class="whs-button whs-button-secondary" onclick="history.back()">
                        Cancel
                    </button>
                </div>

            </form>

        </div>

    </tal:main-macro>
</metal:main>
</body>
</html>
```

**Deliverables:**
- Complete form template
- Adaptive sections for authenticated/anonymous
- All 12 MS Form questions included
- Proper field validation attributes
- Mobile-responsive structure

**Testing:**
- Form renders correctly
- Fields appear/disappear based on auth status
- Required validation works
- File uploads functional

**Time Estimate:** 6 hours

---

### 3.2 JavaScript for Dynamic Behavior

**File:** `/csc/src/csc/whs/browser/static/incident_form.js` (NEW)

**Task:** Implement client-side interactivity

**Key Features:**
- LDAP user search with autocomplete
- Auto-populate fields when user selected
- Multi-select validation for Q7
- Show/hide fields based on selections
- Client-side validation before submit
- Mobile touch optimization

**Time Estimate:** 5 hours

---

### 3.3 CSS Styling (WHS Theme)

**File:** `/csc/src/csc/whs/browser/static/incident_form.css` (NEW)

**Task:** Style form with WHS theme colors

**Design Tokens:**
```css
:root {
    --whs-primary: #1e3a5f;
    --whs-secondary: #5b9bd5;
    --whs-success: #28a745;
    --whs-warning: #ffc107;
    --whs-error: #dc3545;
    --whs-border: #e0e0e0;
    --whs-radius: 8px;
    --whs-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
```

**Time Estimate:** 4 hours

---

## PHASE 4: Backend Form Processing

**Duration:** 6 hours
**Dependencies:** Phase 1, 2
**Priority:** HIGH

### 4.1 Update `intake.py` Processing Logic

**File:** `/csc/src/csc/whs/browser/intake.py`

**Task:** Extend intake logic for new fields

**Key Changes:**
- Map LDAP-enhanced person fields
- Handle multi-select incident types
- Process supervisor notification field
- Auto-fill reported_by for authenticated users

**Time Estimate:** 4 hours

---

### 4.2 Update Catalog Indexes

**File:** `/csc/src/csc/whs/profiles/default/catalog.xml`

**Task:** Add indexes for new fields

**Time Estimate:** 1 hour

---

### 4.3 Update `incident.py` Content Class

**File:** `/csc/src/csc/whs/content/incident.py`

**Task:** Add catalog indexing methods

**Time Estimate:** 1 hour

---

## PHASE 5: View Template for Viewing Incidents

**Duration:** 3 hours
**Dependencies:** Phase 1, 4
**Priority:** MEDIUM

### 5.1 Update `incident-view` Template

**File:** `/csc/src/csc/whs/browser/templates/incident.pt`

**Task:** Display new fields in view template

**Time Estimate:** 3 hours

---

## PHASE 6: Notifications & Workflow

**Duration:** 2-5 hours
**Dependencies:** Phase 4
**Priority:** MEDIUM

### 6.1 Update Email Notifications

**File:** `/csc/src/csc/whs/notifications.py`

**Task:** Include new fields in notification emails

**Time Estimate:** 2 hours

---

### 6.2 Workflow Integration (Optional)

**Task:** Auto-assign based on division

**Time Estimate:** 3 hours (if needed)

---

## PHASE 7: Upgrade Step & Migration

**Duration:** 2 hours
**Dependencies:** All phases
**Priority:** HIGH

### 7.1 Create Upgrade Step

**File:** `/csc/src/csc/whs/upgrades.py`

**Task:** Migrate existing incidents, add indexes

**Time Estimate:** 2 hours

---

### 7.2 Update Version

**File:** `/csc/src/csc/whs/profiles/default/metadata.xml`

**Task:** Bump to version 0.7.8

**Time Estimate:** Included in 7.1

---

## PHASE 8: Testing & Documentation

**Duration:** 16 hours
**Dependencies:** All phases
**Priority:** HIGH

### 8.1 Unit Tests

**Task:** Create comprehensive test coverage

**Time Estimate:** 6 hours

---

### 8.2 Integration Testing

**Task:** Test all user scenarios end-to-end

**Time Estimate:** 4 hours

---

### 8.3 User Acceptance Testing (UAT)

**Task:** WHS Officers test complete workflow

**Time Estimate:** 2 hours

---

### 8.4 Documentation

**Task:** User guide, admin guide, technical docs

**Time Estimate:** 4 hours

---

## 📊 Summary & Timeline (UPDATED with GPS Integration)

| Phase | Description | Time | Dependencies |
|-------|-------------|------|--------------|
| **1** | Schema & Vocabularies + GPS fields | 11h (+5.5h) | None |
| **2** | LDAP Integration | 7h | Phase 1 |
| **3** | Form Template & UI + GPS integration | 21h (+6h) | Phase 1, 2 |
| **4** | Backend Processing + GPS data | 7h (+1h) | Phase 1, 2 |
| **5** | View Template + GPS display | 4h (+1h) | Phase 1, 4 |
| **6** | Notifications | 2h (no workflow) | Phase 4 |
| **7** | Upgrade Step (no migration needed) | 1h (-1h) | All |
| **8** | Testing & Docs | 16h | All |
| **TOTAL** | | **69h** | |

**Estimated Development Time:** 9 working days
**Recommended Sprint:** 2 weeks

**Changes from Original Plan:**
- +11.5 hours for GPS location integration (schema, UI, JS, backend, view)
- -1 hour for simplified upgrade (no backward compatibility needed)
- -3 hours for no manager notification workflow
- **Net change:** +7.5 hours total

---

## 🎯 Milestones & Deliverables

### Milestone 1: Schema Complete (Day 2)
- ✅ All new fields defined
- ✅ Vocabularies created and registered
- ✅ Can manually add incidents with new fields

### Milestone 2: LDAP Integration Working (Day 4)
- ✅ LDAP user search functional
- ✅ User data auto-population working
- ✅ AJAX API endpoints tested

### Milestone 3: Form UI Complete (Day 7)
- ✅ Adaptive form renders correctly
- ✅ JavaScript enhancements working
- ✅ Mobile-responsive
- ✅ WHS theme applied

### Milestone 4: End-to-End Testing (Day 10)
- ✅ Authenticated incident reporting works
- ✅ Anonymous incident reporting works
- ✅ Email notifications sending
- ✅ Catalog searching working

### Milestone 5: Production Ready (Day 14)
- ✅ All tests passing
- ✅ Documentation complete
- ✅ Upgrade step tested
- ✅ UAT approved by WHS Officers

---

## ⚠️ Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| LDAP connectivity issues | High | Low | Graceful degradation to manual entry |
| User department doesn't map to directorate | Medium | Medium | Allow manual override + mapping table |
| Mobile browser compatibility | Medium | Low | Progressive enhancement, extensive testing |
| Existing incidents need migration | Low | High | Upgrade step handles backward compatibility |
| Performance with many users | Medium | Low | Caching, optimize LDAP queries |

---

## 🔄 Optional Enhancements (Future Phases)

Not included in this plan but could be added later:

1. **Incident Dashboard** - Visual analytics by division/directorate
2. **Manager Notification Workflow** - Auto-notify based on LDAP manager
3. **Contractor Database** - Store contractor companies, auto-complete
4. **Historical Incident Lookup** - "Has this person had previous incidents?"
5. **Mobile App** - Progressive Web App (PWA) for field reporting
6. **Photo Upload Directly from Camera** - Mobile camera integration
7. **Offline Mode** - Save draft offline, submit when connected

---

## 📝 Decisions Required Before Starting

### Decision 1: Lock Auto-Populated Fields
**Question:** Should division and relationship fields be locked (read-only) when auto-populated from LDAP?

- [ ] **Option A:** Lock fields - prevents data inconsistency (RECOMMENDED)
- [ ] **Option B:** Allow override - flexibility for corrections

**Default if not specified:** Lock fields for employees

---

### Decision 2: Anonymous Form Email Requirement
**Question:** Should anonymous reporters be required to provide email?

- [ ] **Option A:** Required - enables confirmation email and follow-up (RECOMMENDED)
- [ ] **Option B:** Optional - truly anonymous reporting

**Default if not specified:** Required

---

### Decision 3: Q6 Location Field Type
**Question:** How should location be captured?

- [ ] **Option A:** Free text field (matches MS Form exactly) (RECOMMENDED)
- [ ] **Option B:** Dropdown with "Other (specify)" option
- [ ] **Option C:** Hybrid - Common locations dropdown + text fallback

**Default if not specified:** Free text

---

### Decision 4: Backward Compatibility
**Question:** How to handle old incident records?

- [ ] **Option A:** Keep old `category` field, map to `incident_types` on view (RECOMMENDED)
- [ ] **Option B:** Run migration to update all old records

**Default if not specified:** Option A (less disruptive)

---

### Decision 5: Manager Notification Workflow
**Question:** Should incidents auto-notify the person's manager if supervisor_notified=No?

- [ ] **Option A:** Yes - implement smart routing (adds ~3 hours)
- [ ] **Option B:** No - manual assignment for now (RECOMMENDED)

**Default if not specified:** Option B

---

## ✅ Approval Checklist

Before proceeding with implementation:

- [ ] All decision points have been reviewed and answered
- [ ] Phase breakdown and timeline are acceptable
- [ ] Resource allocation confirmed
- [ ] WHS Officers available for UAT in Week 2
- [ ] Development server access confirmed
- [ ] Backup/rollback plan understood

---

## 🚀 Next Steps

Once approved:

1. **Create detailed task list** with all subtasks
2. **Begin Phase 1** (Schema & Vocabularies)
3. **Provide daily progress updates** at end of each day
4. **Request review at each milestone**
5. **Schedule UAT session** with WHS Officers for Week 2

---

## 📞 Contact & Questions

For questions about this implementation plan:
- Review this document
- Request clarification on specific phases
- Suggest modifications before work begins

**Prepared by:** Claude Code
**Date Created:** 2025-10-09
**Date Approved:** 2025-10-09
**Document Version:** 1.1 (Updated with approved decisions + GPS integration)
**Status:** ✅ APPROVED - READY TO BEGIN IMPLEMENTATION
