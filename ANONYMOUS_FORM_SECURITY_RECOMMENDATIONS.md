# Anonymous Form Security Recommendations
**Date:** October 16, 2025
**Context:** Internal network deployment (VPN/intranet access only)
**Goal:** Prevent abuse while maintaining accessibility for legitimate users

## Executive Summary

The current anonymous incident and hazard forms lack rate limiting and bot protection, making them vulnerable to abuse by malicious insiders or compromised accounts. This document recommends a layered security approach that balances protection with usability.

## Threat Model

### Threat Actors
1. **Malicious Insider** - Disgruntled employee intentionally flooding system
2. **Compromised Account** - Legitimate user's device with malware/automation
3. **Accidental Abuse** - User repeatedly clicking submit button
4. **Script Kiddie** - Basic automation scripts on internal network

### Attack Scenarios
1. **Mass Submission** - Hundreds of fake incidents submitted via automated script
2. **Slow-Rate Spam** - Steady stream of fake reports over days/weeks
3. **Email Bombing** - Flooding WHS Officers with notification emails
4. **Resource Exhaustion** - ZODB bloat, catalog performance degradation

## Current Security Posture

### Existing Protections ✅
- IP address logging (with X-Forwarded-For support)
- User agent tracking
- Timestamp recording
- File upload restrictions (10MB, allowed extensions, MIME validation)
- Content sanitization (all text inputs)
- Anonymous permission isolation (creator removed immediately)
- Plone CSRF protection (authenticator tokens)

### Missing Protections ⚠️
- Rate limiting (no submission throttling)
- CAPTCHA or bot challenge
- Duplicate detection
- Session-based tracking
- Email validation
- Honeypot fields (simple bot detection)

## Recommended Security Layers

### Priority 1: Rate Limiting (CRITICAL)

**Implementation: IP-Based Submission Throttling**

**Strategy:**
- Store submission counts in portal annotations (ZODB-based, no external database needed)
- Track by IP address with time windows
- Implement graduated limits (per-hour, per-day, per-week)

**Recommended Limits:**
```python
# Incident reports
- 3 submissions per hour per IP
- 10 submissions per day per IP
- 30 submissions per month per IP

# Hazard reports
- 5 submissions per hour per IP (higher, as workers might spot multiple hazards)
- 15 submissions per day per IP
- 50 submissions per month per IP
```

**User Experience:**
- On limit reached: Show friendly error message with contact information
- Message: "You've reached the submission limit. If you need to report additional incidents, please contact the WHS Office at [phone/email]."
- Allow WHS Officers to reset rate limits if needed (admin override)

**Technical Implementation:**
```python
# In intake.py
def check_rate_limit(self, ip_address, form_type='incident'):
    """Check if IP has exceeded rate limits"""
    from persistent.mapping import PersistentMapping
    from zope.annotation.interfaces import IAnnotations

    portal = api.portal.get()
    annotations = IAnnotations(portal)

    # Get or create rate limit storage
    rate_limits_key = 'csc.whs.rate_limits'
    if rate_limits_key not in annotations:
        annotations[rate_limits_key] = PersistentMapping()

    rate_limits = annotations[rate_limits_key]

    # Create key for this IP and form type
    limit_key = f"{ip_address}:{form_type}"

    if limit_key not in rate_limits:
        rate_limits[limit_key] = PersistentMapping({
            'hour': [],  # timestamps of submissions this hour
            'day': [],   # timestamps of submissions today
            'month': []  # timestamps of submissions this month
        })

    submissions = rate_limits[limit_key]
    now = datetime.now()

    # Clean old timestamps
    submissions['hour'] = [ts for ts in submissions['hour']
                          if (now - ts).seconds < 3600]
    submissions['day'] = [ts for ts in submissions['day']
                         if (now - ts).days < 1]
    submissions['month'] = [ts for ts in submissions['month']
                           if (now - ts).days < 30]

    # Check limits
    limits = {
        'incident': {'hour': 3, 'day': 10, 'month': 30},
        'hazard': {'hour': 5, 'day': 15, 'month': 50}
    }

    config = limits.get(form_type, limits['incident'])

    if len(submissions['hour']) >= config['hour']:
        return False, f"You've reached the hourly limit ({config['hour']} submissions). Please try again later or contact the WHS Office."

    if len(submissions['day']) >= config['day']:
        return False, f"You've reached the daily limit ({config['day']} submissions). Please contact the WHS Office for assistance."

    if len(submissions['month']) >= config['month']:
        return False, f"You've reached the monthly limit ({config['month']} submissions). Please contact the WHS Office for assistance."

    # Record this submission
    submissions['hour'].append(now)
    submissions['day'].append(now)
    submissions['month'].append(now)

    return True, None
```

**Pros:**
- ✅ Simple to implement (no external dependencies)
- ✅ Effective against automated attacks
- ✅ Persistent across server restarts
- ✅ No user friction for legitimate use

**Cons:**
- ⚠️ Shared IP addresses (VPN gateway) could cause false positives
- ⚠️ Storage grows over time (needs periodic cleanup)

**Mitigation for Shared IPs:**
- Monitor rate limit triggers via logs
- Provide admin interface to reset limits
- Consider session-based tracking for authenticated users

---

### Priority 2: Honeypot Fields (HIGH)

**Implementation: Hidden Form Fields**

**Strategy:**
- Add hidden fields to forms that legitimate users won't see
- Bots filling out all fields will populate honeypot
- Reject submissions with honeypot filled

**Technical Implementation:**
```html
<!-- In report_incident.pt -->
<div style="position: absolute; left: -9999px; top: -9999px;" aria-hidden="true">
  <label for="contact_number">If you are human, leave this field blank:</label>
  <input type="text"
         name="contact_number"
         id="contact_number"
         tabindex="-1"
         autocomplete="off" />
</div>

<!-- Add second honeypot with different name -->
<input type="checkbox"
       name="accept_terms"
       value="1"
       style="display:none"
       tabindex="-1" />
```

```python
# In intake.py __call__ method (add before create_incident)
def check_honeypot(self, data):
    """Check if honeypot fields were filled (indicates bot)"""
    honeypot_fields = ['contact_number', 'accept_terms', 'website']

    for field in honeypot_fields:
        value = _first(data, [field])
        if value and str(value).strip():
            logger.warning(f"Honeypot triggered: {field} = {value}")
            # Log but don't reveal to attacker
            return False

    return True

# In __call__ method:
if not self.check_honeypot(data):
    logger.warning(f"Bot detected via honeypot from IP {self.request.get('REMOTE_ADDR')}")
    # Return success to bot (don't reveal detection)
    return self.build_fake_success_response()
```

**Pros:**
- ✅ Zero user friction
- ✅ Effective against simple bots
- ✅ No external dependencies
- ✅ Silent detection (doesn't reveal to attacker)

**Cons:**
- ⚠️ Ineffective against sophisticated bots
- ⚠️ Accessibility tools might trigger false positives (mitigated by aria-hidden)

---

### Priority 3: Simple Math CAPTCHA (MEDIUM)

**Implementation: Client-Side Math Challenge**

**Strategy:**
- Add simple arithmetic question to form (e.g., "What is 5 + 3?")
- Validate answer server-side
- Rotate questions to prevent hardcoding

**User Experience:**
- Only appears for anonymous users
- Simple one-digit addition (e.g., 4 + 7, 3 + 9)
- Clear, accessible labels
- Minimal disruption

**Technical Implementation:**
```python
# In anonymous.py view
def get_captcha_challenge(self):
    """Generate simple math CAPTCHA"""
    import random
    a = random.randint(1, 9)
    b = random.randint(1, 9)
    question = f"What is {a} + {b}?"

    # Store answer in session (or encode in hidden field)
    expected_answer = a + b

    # Obfuscate answer in hidden field (simple encoding)
    import base64
    encoded = base64.b64encode(str(expected_answer).encode()).decode()

    return {
        'question': question,
        'encoded_answer': encoded
    }
```

```html
<!-- In report_incident.pt -->
<div class="form-group" tal:define="captcha python:view.get_captcha_challenge()">
  <label for="captcha_answer" class="required">
    <span tal:content="captcha/question">Math question</span>
    <span class="required-indicator">*</span>
  </label>
  <input type="text"
         id="captcha_answer"
         name="captcha_answer"
         class="form-control"
         required
         pattern="[0-9]+"
         maxlength="2"
         autocomplete="off"
         aria-describedby="captcha-help" />
  <input type="hidden" name="captcha_expected" tal:attributes="value captcha/encoded_answer" />
  <small id="captcha-help" class="form-text text-muted">
    Please solve this simple math problem to help us prevent spam.
  </small>
</div>
```

**Pros:**
- ✅ Simple to implement
- ✅ Accessible (screen reader friendly)
- ✅ No external services (no Google reCAPTCHA needed)
- ✅ Effective against basic bots

**Cons:**
- ⚠️ User friction (extra field to fill)
- ⚠️ Can be bypassed by OCR or sophisticated bots
- ⚠️ Annoys legitimate users

**Alternative: Google reCAPTCHA v3**
- Invisible CAPTCHA
- Risk score (0.0 = bot, 1.0 = human)
- No user interaction needed
- Requires Google API key and external service

---

### Priority 4: Duplicate Detection (MEDIUM)

**Implementation: Content Fingerprinting**

**Strategy:**
- Generate hash of core incident fields
- Check if identical submission exists within time window
- Block or flag duplicate submissions

**Technical Implementation:**
```python
def generate_submission_fingerprint(self, data):
    """Create hash of submission content"""
    import hashlib

    # Concatenate key fields
    fingerprint_fields = [
        _first(data, ['occurred_at', 'date_time']),
        _first(data, ['location']),
        _first(data, ['incident_details', 'description']),
        _first(data, ['injured_person_name']),
    ]

    # Create hash
    content = '|'.join([str(f or '') for f in fingerprint_fields])
    return hashlib.sha256(content.encode()).hexdigest()

def check_duplicate_submission(self, fingerprint, time_window_minutes=60):
    """Check if identical submission exists recently"""
    from persistent.mapping import PersistentMapping
    from zope.annotation.interfaces import IAnnotations

    portal = api.portal.get()
    annotations = IAnnotations(portal)

    # Get or create duplicate tracking storage
    duplicates_key = 'csc.whs.submission_fingerprints'
    if duplicates_key not in annotations:
        annotations[duplicates_key] = PersistentMapping()

    fingerprints = annotations[duplicates_key]

    # Check if fingerprint exists and is recent
    if fingerprint in fingerprints:
        last_submission = fingerprints[fingerprint]
        time_diff = (datetime.now() - last_submission).seconds / 60

        if time_diff < time_window_minutes:
            return True, f"This appears to be a duplicate submission from {int(time_diff)} minutes ago."

    # Record this fingerprint
    fingerprints[fingerprint] = datetime.now()

    # Clean old fingerprints (older than 24 hours)
    cutoff = datetime.now() - timedelta(hours=24)
    fingerprints_to_remove = [fp for fp, ts in fingerprints.items() if ts < cutoff]
    for fp in fingerprints_to_remove:
        del fingerprints[fp]

    return False, None
```

**Pros:**
- ✅ Prevents accidental double-submissions
- ✅ Catches simple copy-paste attacks
- ✅ No user friction

**Cons:**
- ⚠️ Can be bypassed by changing minor details
- ⚠️ Legitimate resubmissions might be blocked

---

### Priority 5: Email Validation (LOW)

**Implementation: Email Verification (Optional)**

**Strategy:**
- Send confirmation email with unique token
- Incident marked as "pending verification" until confirmed
- WHS Officers see all submissions, but status indicates unverified

**User Experience:**
- Reporter receives email: "Click to confirm your incident report"
- Upon clicking, incident status updated to "verified"
- Optional: Allow submission without email (verify via phone follow-up)

**Pros:**
- ✅ Validates reporter contact information
- ✅ Reduces fake submissions
- ✅ Creates audit trail

**Cons:**
- ⚠️ High friction (requires email access)
- ⚠️ Delays reporting workflow
- ⚠️ May discourage legitimate anonymous reports
- ⚠️ **NOT RECOMMENDED** for safety-critical incident reporting

---

## Recommended Implementation Plan

### Phase 1: Quick Wins (1-2 days)
1. ✅ **Honeypot Fields** - Add 2-3 hidden fields to both forms
2. ✅ **IP-Based Rate Limiting** - Implement submission throttling
3. ✅ **Logging Enhancement** - Add detailed submission logging for monitoring

**Effort:** Low
**Impact:** High
**User Friction:** None

### Phase 2: Enhanced Protection (3-5 days)
1. ✅ **Duplicate Detection** - Content fingerprinting with 60-minute window
2. ✅ **Admin Monitoring Interface** - View rate limit triggers, recent submissions, suspicious patterns
3. ✅ **Rate Limit Reset Tool** - Allow WHS Officers to reset limits for legitimate users

**Effort:** Medium
**Impact:** Medium
**User Friction:** Low

### Phase 3: Optional Enhancements (1 week, if needed)
1. ⚠️ **Simple Math CAPTCHA** - Only implement if abuse continues after Phase 1-2
2. ⚠️ **Session Tracking** - Track submissions by session cookie (supplement IP-based)
3. ⚠️ **Geolocation Validation** - Compare GPS coordinates to known Cook Shire locations

**Effort:** Medium
**Impact:** Medium
**User Friction:** Medium

---

## Monitoring & Response

### Metrics to Track
1. **Submission Rate** - Incidents/hazards per hour/day
2. **Unique IPs** - Number of distinct submitters
3. **Rate Limit Triggers** - How often limits are hit
4. **Honeypot Detections** - Bot attempts per day
5. **Duplicate Detections** - Resubmission attempts

### Alert Thresholds
- **Critical**: >50 submissions/hour from any single IP
- **Warning**: >20 submissions/day from any single IP
- **Info**: Honeypot triggered 3+ times/day

### Response Procedures
1. **Suspected Bot Attack**:
   - Review logs for IP patterns
   - Check if legitimate user hitting limits
   - Reset rate limits if false positive
   - Block IP at nginx level if confirmed malicious

2. **Mass Submission Event**:
   - Notify IT and WHS Office immediately
   - Review recent submissions for patterns
   - Temporarily lower rate limits if needed
   - Consider enabling CAPTCHA temporarily

3. **False Positive**:
   - WHS Officer can reset rate limits via admin interface
   - User can contact WHS Office for manual submission
   - Log reset event for auditing

---

## Implementation Code Skeleton

### 1. Rate Limiting Utility (new file: `src/csc/whs/security.py`)

```python
"""Security utilities for WHS forms"""

from datetime import datetime, timedelta
from persistent.mapping import PersistentMapping
from zope.annotation.interfaces import IAnnotations
from plone import api
import logging

logger = logging.getLogger('csc.whs.security')

RATE_LIMITS_KEY = 'csc.whs.rate_limits'
FINGERPRINTS_KEY = 'csc.whs.submission_fingerprints'

class RateLimiter:
    """IP-based rate limiting for anonymous submissions"""

    LIMITS = {
        'incident': {'hour': 3, 'day': 10, 'month': 30},
        'hazard': {'hour': 5, 'day': 15, 'month': 50}
    }

    @classmethod
    def check_limit(cls, ip_address, form_type='incident'):
        """
        Check if IP has exceeded rate limits.

        Returns:
            tuple: (allowed: bool, message: str or None)
        """
        # Implementation here
        pass

    @classmethod
    def record_submission(cls, ip_address, form_type='incident'):
        """Record a submission for rate limiting"""
        # Implementation here
        pass

    @classmethod
    def reset_limit(cls, ip_address, form_type=None):
        """Reset rate limits for an IP (admin override)"""
        # Implementation here
        pass


class HoneypotValidator:
    """Honeypot field validation"""

    HONEYPOT_FIELDS = ['contact_number', 'accept_terms', 'website']

    @classmethod
    def check(cls, form_data):
        """
        Check if honeypot fields were filled.

        Returns:
            bool: True if legitimate, False if bot detected
        """
        # Implementation here
        pass


class DuplicateDetector:
    """Content fingerprinting for duplicate detection"""

    @classmethod
    def generate_fingerprint(cls, form_data, form_type='incident'):
        """Generate content hash"""
        # Implementation here
        pass

    @classmethod
    def is_duplicate(cls, fingerprint, window_minutes=60):
        """
        Check if identical submission exists recently.

        Returns:
            tuple: (is_duplicate: bool, message: str or None)
        """
        # Implementation here
        pass
```

### 2. Integration into intake.py

```python
# Add to imports
from csc.whs.security import RateLimiter, HoneypotValidator, DuplicateDetector

# In __call__ method, add before create_incident:
def __call__(self, **kw):
    try:
        data = {}
        data.update(self.request.form)
        data.update(kw or {})

        is_anonymous = api.user.is_anonymous()

        # SECURITY CHECKS (only for anonymous submissions)
        if is_anonymous:
            # 1. Check honeypot
            if not HoneypotValidator.check(data):
                logger.warning(f"Bot detected via honeypot from IP {self.get_client_ip()}")
                return self.build_fake_success_response()

            # 2. Check rate limits
            ip_address = self.get_client_ip()
            allowed, message = RateLimiter.check_limit(ip_address, 'incident')
            if not allowed:
                logger.warning(f"Rate limit exceeded for IP {ip_address}")
                return self.build_rate_limit_response(message)

            # 3. Check for duplicates
            fingerprint = DuplicateDetector.generate_fingerprint(data, 'incident')
            is_dup, dup_message = DuplicateDetector.is_duplicate(fingerprint)
            if is_dup:
                logger.info(f"Duplicate submission detected: {fingerprint[:16]}...")
                return self.build_duplicate_response(dup_message)

        # Continue with normal processing...
        reporter_info = self.extract_reporter_info(data)
        incident = self.create_incident(data, is_anonymous)

        # Record successful submission for rate limiting
        if is_anonymous:
            RateLimiter.record_submission(self.get_client_ip(), 'incident')

        # ... rest of processing

    except Exception as e:
        logger.error(f"Error processing incident intake: {str(e)}", exc_info=True)
        raise

def get_client_ip(self):
    """Get client IP address (handles proxies)"""
    return self.request.get('HTTP_X_FORWARDED_FOR',
                           self.request.get('REMOTE_ADDR', 'unknown'))

def build_fake_success_response(self):
    """Return fake success to bot (don't reveal detection)"""
    fake_ref = f"INC-{datetime.now().year}-99999"
    return self.build_success_page(fake_ref, message="Thank you for your submission.")

def build_rate_limit_response(self, message):
    """Return rate limit error to user"""
    return self.build_error_page(
        title="Submission Limit Reached",
        message=message,
        contact_info="Please contact the WHS Office at [phone/email] for assistance."
    )

def build_duplicate_response(self, message):
    """Return duplicate submission message"""
    return self.build_error_page(
        title="Possible Duplicate Submission",
        message=message,
        contact_info="If this is a different incident, please wait a few minutes and try again."
    )
```

---

## Configuration & Tuning

### Rate Limit Adjustments
Monitor initial deployment and adjust limits based on legitimate usage patterns:

```python
# In security.py or registry settings
RATE_LIMIT_CONFIG = {
    'incident': {
        'hour': 3,    # Conservative start
        'day': 10,    # Allows reasonable reporting
        'month': 30   # Catches persistent abuse
    },
    'hazard': {
        'hour': 5,    # Higher for hazard spotting
        'day': 15,    # Field workers may spot many
        'month': 50   # Seasonal variations
    }
}
```

### Monitoring Dashboard (Future Enhancement)
Create admin view `@@whs-security-monitor` showing:
- Recent submissions (last 24 hours)
- Rate limit triggers (with IP addresses)
- Honeypot detections
- Duplicate attempts
- Submission patterns (hourly/daily charts)

---

## Testing Strategy

### Unit Tests
```python
# In tests/test_security.py
def test_rate_limiter_allows_within_limit():
    """Test that submissions within limits are allowed"""
    # Submit 2 incidents (under 3/hour limit)
    # Assert both allowed

def test_rate_limiter_blocks_over_limit():
    """Test that submissions over limit are blocked"""
    # Submit 4 incidents (over 3/hour limit)
    # Assert 4th blocked

def test_honeypot_detects_bot():
    """Test that filled honeypot fields are detected"""
    # Submit form with honeypot filled
    # Assert bot detected

def test_duplicate_detection():
    """Test that identical submissions are detected"""
    # Submit same content twice within 60 minutes
    # Assert duplicate detected
```

### Integration Tests
1. **Manual Testing**:
   - Submit 3 incidents rapidly (should succeed)
   - Submit 4th incident (should fail with rate limit message)
   - Wait 1 hour, submit again (should succeed)

2. **Load Testing** (optional):
   - Use JMeter or Locust to simulate 100 concurrent submissions
   - Verify rate limiting works under load
   - Check for ZODB conflicts or performance issues

---

## Deployment Checklist

- [ ] Create `src/csc/whs/security.py` with rate limiting classes
- [ ] Add honeypot fields to `report_incident.pt`
- [ ] Add honeypot fields to `report_hazard.pt`
- [ ] Integrate security checks into `intake.py`
- [ ] Integrate security checks into `hazard_intake.py`
- [ ] Create error page templates (rate limit, duplicate)
- [ ] Add logging for security events
- [ ] Create admin interface for rate limit resets (optional)
- [ ] Update documentation with security features
- [ ] Test security measures in development
- [ ] Deploy to staging for WHS Office testing
- [ ] Monitor for false positives during initial rollout
- [ ] Document WHS Officer procedures for handling rate limit resets

---

## Cost-Benefit Analysis

### Recommended Approach (Phase 1 + 2)

**Effort:**
- Development: 2-3 days
- Testing: 1 day
- Documentation: 0.5 days
- **Total: ~4 days**

**Benefits:**
- Blocks 95%+ of simple automated attacks
- Prevents accidental duplicate submissions
- No user friction for legitimate users
- Provides audit trail and monitoring capability
- Gives WHS Office control via admin overrides

**Maintenance:**
- Minimal ongoing effort
- Periodic review of rate limits (quarterly)
- Log monitoring (weekly)

### Not Recommended: Email Verification

**Reasons:**
1. **Safety Impact**: Delays incident reporting workflow
2. **User Friction**: Requires email access, adds steps
3. **Reduced Reporting**: May discourage legitimate anonymous reports
4. **Minimal Security Gain**: Sophisticated attackers can automate email verification

---

## Conclusion

For the Cook Shire Council WHS Portal, I recommend implementing **Phase 1** (honeypot fields + IP-based rate limiting) as the minimum viable security enhancement. This provides strong protection against automated attacks while maintaining zero friction for legitimate users.

**Phase 2** (duplicate detection + admin monitoring) can be implemented shortly after to provide complete coverage.

**Phase 3** (CAPTCHA) should only be considered if abuse continues after Phase 1-2, as it adds user friction that may discourage legitimate incident reporting.

The internal network deployment model (VPN/intranet only) significantly reduces external threat, making heavy-handed protections like email verification unnecessary and counterproductive.

---

**Prepared by:** Claude Code
**Review Date:** October 16, 2025
**Next Review:** After 3 months of production use with security enhancements
