**10** WHS Officer Request 10
**Fix Q13 Title Field - Remove & Update Formula** | **High** | **6-7** | **4h** | **Medium - Question renumbering** |

Request #10: Fix Q13 Title Field - Remove from Form & Update Generation Formula

  Key Changes:
  - Remove Q13 completely from user-facing forms (both authenticated and anonymous)
  - Change title generation formula from: {Incident Type} - {Department} - {Location Town}
  - To new formula: {Injury Type} - {Person Name} - {Town/Locality} - {Date}
  - Implement server-side generation instead of JavaScript
  - Example: "Sprain/Strain - John Smith - Cooktown - 21/10/2025"

  Implementation Details:
  - 6-7 files to modify
  - Estimated effort: 4 hours
  - Priority: High
  - Files affected: report_incident.pt, anonymous_form.pt, utilities.py, intake.py, anonymous.py, incident_form.js, interfaces.py

  Rationale:
  - Cleaner UX (users don't need to see title during entry)
  - Server-side generation more reliable than JavaScript
  - Eliminates label/description mismatch
  - Title visible in views, listings, and search after submission

