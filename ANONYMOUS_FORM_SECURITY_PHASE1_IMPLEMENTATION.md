# Phase 1 Security Implementation - v0.10.17

**Date:** 2025-10-16
**Version:** 0.10.17
**Status:** Complete

## Overview

This document summarizes the Phase 1 security enhancements implemented for the WHS Portal's anonymous incident and hazard reporting forms.

## Implementation Summary

Phase 1 implements a **zero-friction, multi-layered security approach** for anonymous form submissions:

### 1. Honeypot Fields (Bot Detection)
- **Purpose:** Detect automated bot submissions
- **Method:** Hidden form fields that legitimate users can't see but bots will fill
- **Action:** Silent rejection - bots receive fake success response
- **Fields:** `contact_number`, `website`, `accept_terms`

### 2. IP-Based Rate Limiting
- **Purpose:** Prevent submission spam and abuse
- **Storage:** ZODB persistent annotations (no external database needed)
- **Limits:**
  - **Incidents:** 3/hour, 10/day, 30/month per IP
  - **Hazards:** 5/hour, 15/day, 50/month per IP
- **Action:** User-friendly error page with WHS Office contact info
- **Proxy-aware:** Uses X-Forwarded-For header for nginx reverse proxy

### 3. Duplicate Detection
- **Purpose:** Prevent accidental duplicate submissions
- **Method:** SHA256 content fingerprinting of key form fields
- **Window:** 60 minutes
- **Action:** Friendly message suggesting to wait or contact WHS Office

## Files Modified

### New Files Created
1. **`src/csc/whs/security.py`** (428 lines)
   - `RateLimiter` class - IP-based rate limiting with ZODB persistence
   - `HoneypotValidator` class - Bot detection via hidden fields
   - `DuplicateDetector` class - Content fingerprinting
   - `get_client_ip()` function - Proxy-aware IP extraction

### Modified Files
1. **`src/csc/whs/browser/templates/report_incident.pt`**
   - Added 3 honeypot fields (hidden via CSS)

2. **`src/csc/whs/browser/templates/report_hazard.pt`**
   - Added 3 honeypot fields (hidden via CSS)

3. **`src/csc/whs/browser/intake.py`**
   - Added security imports
   - Integrated 3-tier security checks in `__call__` method
   - Added rate limit recording after successful submission
   - Added 3 helper methods for error responses

4. **`src/csc/whs/browser/hazard_intake.py`**
   - Same changes as intake.py for hazard form

5. **`pyproject.toml`**
   - Version bumped from 0.10.16 to 0.10.17

## Security Design Principles

### 1. **Fail-Open Approach**
- If security checks error, allow submission (safety-critical system)
- Log errors for monitoring but don't block legitimate reports

### 2. **Anonymous-Only Security**
- Authenticated users bypass all security checks
- Trust internal users, focus on external/anonymous threats

### 3. **Silent Bot Detection**
- Don't reveal to bots that they've been detected
- Return realistic-looking fake success response

### 4. **User-Friendly Error Messages**
- Rate limit messages include WHS Office contact information
- Provide clear instructions on what to do next
- Include phone: (07) 4069 5444 and email: whsofficer@cook.qld.gov.au

### 5. **Zero Friction for Legitimate Users**
- No CAPTCHA or additional steps required
- Invisible protection that doesn't impact usability
- Conservative rate limits that won't affect normal usage

## Technical Implementation

### Rate Limit Storage
```python
# Stored in ZODB portal annotations
RATE_LIMITS_KEY = 'csc.whs.rate_limits'

# Data structure:
rate_limits['{ip}:{form_type}'] = {
    'hour': [timestamp1, timestamp2, ...],
    'day': [timestamp1, timestamp2, ...],
    'month': [timestamp1, timestamp2, ...]
}
```

### Security Check Flow
```python
if is_anonymous:
    # 1. Honeypot check
    if not HoneypotValidator.check(data):
        return _build_fake_success_response()

    # 2. Rate limit check
    allowed, message = RateLimiter.check_limit(client_ip, form_type)
    if not allowed:
        return _build_rate_limit_response(message)

    # 3. Duplicate check
    fingerprint = DuplicateDetector.generate_fingerprint(data, form_type)
    is_dup, message = DuplicateDetector.is_duplicate(fingerprint)
    if is_dup:
        return _build_duplicate_response(message)

    # Create incident/hazard...

    # 4. Record submission
    RateLimiter.record_submission(client_ip, form_type)
```

## Testing Recommendations

### Manual Testing
1. **Normal Submission:** Verify legitimate submissions work normally
2. **Honeypot:** Fill hidden fields to test bot detection
3. **Rate Limits:** Submit multiple times to test hourly limit
4. **Duplicates:** Submit identical form twice within 60 minutes
5. **Authenticated:** Verify security checks are bypassed for logged-in users

### Monitoring
- Check logs for honeypot triggers: `grep "Honeypot triggered" instance.log`
- Check rate limit violations: `grep "Rate limit exceeded" instance.log`
- Check duplicate detections: `grep "Duplicate submission detected" instance.log`

## Admin Tools

The RateLimiter class provides admin methods:

```python
# Reset rate limits for a specific IP
RateLimiter.reset_limit('192.168.1.100', 'incident')

# Reset all limits for an IP
RateLimiter.reset_limit('192.168.1.100')

# Check current submission count
count = RateLimiter.get_submission_count('192.168.1.100', 'incident', 'hour')
```

## Known Limitations

1. **Shared IP Addresses:** VPN gateway may cause multiple users to share an IP
   - Mitigation: Conservative limits, admin override capability
   - Future: Consider session-based tracking (Phase 2)

2. **Sophisticated Bots:** Advanced bots may detect and avoid honeypots
   - Mitigation: Multiple honeypot fields with realistic names
   - Future: Consider browser fingerprinting (Phase 3)

3. **ZODB Storage:** Rate limit data not easily accessible for reporting
   - Mitigation: Comprehensive logging for monitoring
   - Future: Admin dashboard (Phase 2)

## Future Enhancements (Phase 2+)

### Phase 2 (If Needed)
- Admin dashboard for monitoring rate limits
- Session-based tracking for shared IPs
- Enhanced duplicate detection with fuzzy matching
- Automated cleanup of old rate limit data

### Phase 3 (If Abuse Continues)
- Optional math CAPTCHA for high-risk scenarios
- Browser fingerprinting for better bot detection
- Time-based submission pattern analysis

## Configuration

All security settings are defined in `src/csc/whs/security.py`:

```python
# Rate limits (per IP address)
RateLimiter.LIMITS = {
    'incident': {'hour': 3, 'day': 10, 'month': 30},
    'hazard': {'hour': 5, 'day': 15, 'month': 50}
}

# Honeypot fields (must match template)
HoneypotValidator.HONEYPOT_FIELDS = [
    'contact_number', 'accept_terms', 'website'
]

# Duplicate detection window (minutes)
DuplicateDetector.is_duplicate(fingerprint, window_minutes=60)
```

To adjust these values, edit the security.py file and redeploy.

## Deployment Notes

1. **No database changes required** - Uses existing ZODB
2. **No configuration changes required** - Works out of the box
3. **Backwards compatible** - Doesn't affect existing functionality
4. **Zero downtime deployment** - Safe to deploy during business hours

## Success Metrics

Monitor these indicators after deployment:

1. **Reduction in spam submissions** (if spam was occurring)
2. **No increase in support requests** from legitimate users
3. **Log entries showing security checks working** (honeypot, rate limits)
4. **No false positives** (legitimate users being blocked)

## Support

If users report issues with form submission:

1. Check logs for their IP address and timestamp
2. Verify if rate limit was triggered
3. Use admin tools to reset rate limit if needed
4. Consider adjusting limits if false positives occur

---

**Implementation completed:** 2025-10-16
**Next review:** Monitor for 2 weeks, assess if Phase 2 needed
