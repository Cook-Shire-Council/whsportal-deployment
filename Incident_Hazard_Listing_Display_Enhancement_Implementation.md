# Incident & Hazard Listing Display Enhancement - Implementation Plan

**Document Version:** 1.1
**Date:** 20 October 2025
**Status:** Phase 1 Complete ✅
**Related To:** WHS Portal v0.10.19 (Phase B Complete)

## Overview

This document outlines the implementation plan for enhancing the incident and hazard listing views with improved sorting, filtering, and data export capabilities. These enhancements will provide WHS Officers with powerful tools for data analysis, reporting, and compliance documentation.

## Business Justification

### Current Limitations
1. **Fixed Sorting**: Incidents/hazards display in chronological order only (most recent first)
2. **No Filtering**: Cannot filter by type, department, severity, or workflow state
3. **No Export**: Cannot extract data for Excel analysis or third-party reporting
4. **Limited Analysis**: WHS Officers cannot easily identify trends or patterns

### Business Value
1. **Regulatory Compliance**: Easy extraction of incident data for WorkSafe Queensland reporting
2. **Data Analysis**: WHS Officers can analyze trends, patterns, and risk indicators in Excel
3. **Third-Party Integration**: CSV export enables connectivity to insurance systems, safety management platforms
4. **Improved Efficiency**: Quick filtering and sorting reduces time spent searching for specific incidents
5. **Better Decision Making**: Enhanced visibility into incident patterns supports proactive safety improvements

## Implementation Phases

### Phase 1: CSV Export Functionality ⭐ Priority
**Effort:** 30-60 minutes
**Value:** High - Immediate data analysis capability

#### Features
- **Export Button**: Prominent "Export to CSV" button at top of listing
- **All Fields**: Export all incident/hazard fields with descriptive headers
- **Australian Format**: Date format DD/MM/YYYY, proper timezone handling
- **Filename Convention**: `incidents_export_YYYYMMDD_HHMMSS.csv` / `hazards_export_YYYYMMDD_HHMMSS.csv`
- **UTF-8 Encoding**: Proper handling of special characters
- **Excel Optimization**: BOM marker for Excel compatibility

#### Exported Fields (Incidents)
```
Reference Code
Title
Incident Type(s)
Date Occurred
Date Reported
Person Injured/Involved
Person Username
Relationship to Council
Department
Location Town
Location Address
GPS Latitude
GPS Longitude
Incident Details
Circumstances
Immediate Actions
Emergency Services Called
Emergency Services Types
Supervisor Notified
Severity
Workflow State
Injury Body Areas
Injury Classifications
First Aid Given
Medical Treatment Sought
Property Damage Types
Plant Number
Contributing Factors
Preventative Actions
Reported By
Reporter Email
Last Modified
```

#### Exported Fields (Hazards)
```
Reference Code
Title
Hazard Category/Categories
Date Identified
Date Reported
Location Town
Location Address
GPS Latitude
GPS Longitude
Hazard Description
Risk Likelihood
Risk Consequence
Risk Rating
Immediate Actions Taken
Control Measures Recommended
Reported By
Reporter Email
Department
Workflow State
Last Modified
```

#### Technical Implementation
**Files to Modify:**
- `/csc/src/csc/whs/browser/incident_listing.py` - Add `export_csv()` method
- `/csc/src/csc/whs/browser/hazard_listing.py` - Add `export_csv()` method
- `/csc/src/csc/whs/browser/templates/incident_listing.pt` - Add export button
- `/csc/src/csc/whs/browser/templates/hazard_listing.pt` - Add export button
- `/csc/src/csc/whs/browser/configure.zcml` - Register CSV export views (if needed)

**Python Approach:**
```python
def export_csv(self):
    """Export incidents/hazards to CSV format"""
    import csv
    from io import StringIO

    # Get all incidents/hazards
    items = self.get_incidents()  # or get_hazards()

    # Create CSV in memory
    output = StringIO()
    writer = csv.DictWriter(output, fieldnames=[...])
    writer.writeheader()

    for brain in items:
        obj = brain.getObject()
        writer.writerow({
            'reference_code': getattr(obj, 'reference_code', ''),
            'occurred_at': format_date_au(obj.occurred_at),
            # ... all fields
        })

    # Return as downloadable file
    response = self.request.response
    response.setHeader('Content-Type', 'text/csv; charset=utf-8')
    response.setHeader('Content-Disposition',
                      f'attachment; filename="incidents_export_{timestamp}.csv"')
    return '\ufeff' + output.getvalue()  # BOM for Excel
```

---

### Phase 2: Interactive Sorting & Filtering
**Effort:** 2-3 hours
**Value:** Medium - Improved day-to-day usability

#### Features

##### 2.1 Sortable Column Headers
- **Click-to-Sort**: Click any column header to sort by that field
- **Visual Indicator**: Arrow icons showing current sort direction (▲▼)
- **Toggle**: Click again to reverse sort order
- **Default**: Date Occurred (most recent first)
- **Sortable Columns**: Reference, Type, Date Occurred, Person/Department, Severity, State

##### 2.2 Quick Filters
**Filter Panel** at top of listing with dropdowns:

**Incident Filters:**
- **Incident Type**: Multi-select dropdown (FAI, LTI, MTI, Near Miss, etc.)
- **Department**: Dropdown (all 26 departments)
- **Severity**: Dropdown (Critical, Major, Moderate, Minor, Insignificant)
- **Workflow State**: Dropdown (Reported, Investigating, Resolved, Closed)
- **Date Range**: From/To date pickers (occurred_at)
- **Search**: Text search for Reference Code, Person Name, Location

**Hazard Filters:**
- **Hazard Category**: Multi-select dropdown (14 categories)
- **Risk Rating**: Dropdown (Extreme, High, Medium, Low)
- **Department**: Dropdown (all 26 departments)
- **Workflow State**: Dropdown (Identified, Assessed, Controlled, Closed)
- **Date Range**: From/To date pickers (identified_at)
- **Search**: Text search for Reference Code, Location

##### 2.3 Filter Behavior
- **Real-time**: Filters apply as user makes selections (JavaScript)
- **Cumulative**: Multiple filters combine (AND logic)
- **Clear All**: Button to reset all filters
- **Count Display**: "Showing X of Y incidents" with active filters highlighted
- **URL Parameters**: Filter state saved in URL for bookmarking/sharing

#### Technical Implementation

**Approach: Client-Side JavaScript**
- Use existing table markup
- Add JavaScript library for sorting/filtering (lightweight, no jQuery dependency)
- Filter/sort operates on rendered table rows (fast, no server round-trips)
- Store filter state in localStorage for persistence across sessions

**Files to Modify:**
- Create `/csc/src/csc/whs/browser/static/listing_enhancements.js`
- Create `/csc/src/csc/whs/browser/static/listing_enhancements.css`
- Update `/csc/src/csc/whs/browser/templates/incident_listing.pt`
- Update `/csc/src/csc/whs/browser/templates/hazard_listing.pt`

**JavaScript Approach:**
```javascript
class ListingEnhancer {
    constructor(tableId, filterFormId) {
        this.table = document.getElementById(tableId);
        this.filterForm = document.getElementById(filterFormId);
        this.initSorting();
        this.initFiltering();
    }

    initSorting() {
        // Add click handlers to <th> elements
        // Toggle sort order on click
        // Update visual indicators
    }

    initFiltering() {
        // Listen to filter form changes
        // Apply filters to table rows
        // Update count display
    }

    applyFilters() {
        let visibleCount = 0;
        this.table.querySelectorAll('tbody tr').forEach(row => {
            if (this.matchesFilters(row)) {
                row.style.display = '';
                visibleCount++;
            } else {
                row.style.display = 'none';
            }
        });
        this.updateCount(visibleCount);
    }
}
```

**Template Changes:**
```html
<!-- Filter Panel -->
<div class="listing-filters" style="margin-bottom: 20px; padding: 15px; background: #f8f9fa; border-radius: 5px;">
    <h3 style="margin-top: 0;">Filters</h3>
    <form id="incident-filters" class="filter-form">
        <div class="filter-row">
            <div class="filter-field">
                <label>Incident Type</label>
                <select name="incident_type" multiple>
                    <option value="fai">First Aid Injury (FAI)</option>
                    <option value="lti">Lost Time Injury (LTI)</option>
                    <!-- ... -->
                </select>
            </div>
            <!-- More filter fields -->
        </div>
        <div class="filter-actions">
            <button type="button" id="apply-filters">Apply Filters</button>
            <button type="button" id="clear-filters">Clear All</button>
        </div>
    </form>
    <div class="filter-results">
        Showing <strong id="visible-count">0</strong> of <strong id="total-count">0</strong> incidents
    </div>
</div>

<!-- Make headers sortable -->
<th class="sortable" data-sort="reference">
    Reference <span class="sort-indicator"></span>
</th>
```

---

### Phase 3: Dashboard & Analytics (Future Enhancement)
**Effort:** 4-6 hours
**Value:** High - Strategic insights and trend analysis

#### Features

##### 3.1 Summary Statistics Dashboard
**New view: `@@incidents-dashboard` / `@@hazards-dashboard`**

Display at top of listing or separate dashboard page:

**Incident Dashboard Widgets:**
```
┌─────────────────────────────────────────────────────────────┐
│  Incident Overview - Last 12 Months                         │
├─────────────────────────────────────────────────────────────┤
│  Total Incidents: 142          Open: 23         Closed: 119 │
│  First Aid: 67    LTI: 8       MTI: 15         Near Miss: 32│
│  Critical: 2      Major: 12    Moderate: 45    Minor: 83    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Incidents by Department (Top 5)                            │
├─────────────────────────────────────────────────────────────┤
│  Parks & Gardens          ████████████████ 28               │
│  Roads & Civil Works      ████████████ 22                   │
│  Water & Wastewater       ██████████ 18                     │
│  Fleet & Workshop         ████████ 15                       │
│  Waste Management         ██████ 12                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Monthly Trend (Last 12 Months)                             │
├─────────────────────────────────────────────────────────────┤
│  [Line chart showing incident count by month]               │
└─────────────────────────────────────────────────────────────┘
```

**Hazard Dashboard Widgets:**
- Total hazards identified
- Breakdown by risk rating (Extreme, High, Medium, Low)
- Hazards by category
- Open vs. controlled hazards
- Monthly identification trend

##### 3.2 Chart Visualizations
**Technology Options:**
- **Chart.js** - Lightweight, open-source, excellent for line/bar/pie charts
- **Plotly.js** - More advanced, interactive charts
- **D3.js** - Maximum flexibility, steeper learning curve

**Chart Types:**
1. **Monthly Trend Line Chart**: Incident/hazard count over time
2. **Type Breakdown Pie Chart**: Distribution by incident type
3. **Department Bar Chart**: Top departments by incident count
4. **Severity Stacked Bar**: Monthly incidents stacked by severity

##### 3.3 Advanced Filtering
- **Date Range Presets**: "Last 7 days", "Last month", "Last quarter", "Last year", "Custom"
- **Multi-Department Filter**: Select multiple departments at once
- **Risk Level Filter** (Hazards): Based on likelihood × consequence matrix
- **Workflow State Filter**: "Currently open", "Recently closed", etc.

#### Technical Implementation

**Files to Create:**
- `/csc/src/csc/whs/browser/incident_dashboard.py`
- `/csc/src/csc/whs/browser/hazard_dashboard.py`
- `/csc/src/csc/whs/browser/templates/incident_dashboard.pt`
- `/csc/src/csc/whs/browser/templates/hazard_dashboard.pt`
- `/csc/src/csc/whs/browser/static/dashboard.js`
- `/csc/src/csc/whs/browser/static/dashboard.css`

**Python Analytics Methods:**
```python
class IncidentDashboardView(BrowserView):
    """Dashboard with incident analytics and charts"""

    def get_summary_stats(self):
        """Return summary statistics for dashboard widgets"""
        return {
            'total': self.get_total_count(),
            'by_type': self.get_count_by_type(),
            'by_severity': self.get_count_by_severity(),
            'by_department': self.get_count_by_department(),
            'by_state': self.get_count_by_state(),
            'monthly_trend': self.get_monthly_trend(months=12),
        }

    def get_monthly_trend(self, months=12):
        """Get incident count by month for trend chart"""
        # Query catalog with date range
        # Group by month
        # Return [{month: 'Oct 2025', count: 23}, ...]

    def get_count_by_department(self):
        """Get incident count grouped by department"""
        # Use catalog aggregation or iterate and count
        # Return {dept_token: count, ...}
```

**Chart Integration:**
```javascript
// Load Chart.js from CDN or local
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>

// Generate monthly trend chart
const ctx = document.getElementById('monthlyTrendChart');
new Chart(ctx, {
    type: 'line',
    data: {
        labels: monthlyData.labels,
        datasets: [{
            label: 'Incidents',
            data: monthlyData.counts,
            borderColor: '#007bff',
            tension: 0.1
        }]
    }
});
```

---

## Implementation Schedule

### Recommended Order
1. **Phase 1** - CSV Export (Quick win, high value)
2. **Phase 2a** - Sortable columns (Easy, improves UX)
3. **Phase 2b** - Basic filters (Type, Department, State)
4. **Phase 2c** - Date range & search filters
5. **Phase 3** - Dashboard & Analytics (Future enhancement)

### Effort Estimates
| Phase | Feature | Effort | Priority |
|-------|---------|--------|----------|
| 1 | CSV Export - Incidents | 30 min | ⭐⭐⭐ High |
| 1 | CSV Export - Hazards | 30 min | ⭐⭐⭐ High |
| 2a | Sortable Columns - Both | 1 hour | ⭐⭐ Medium |
| 2b | Filter Panel - Both | 2 hours | ⭐⭐ Medium |
| 2c | Date Range & Search | 1 hour | ⭐ Low |
| 3 | Dashboard & Charts | 6 hours | Future |
| **Total** | **Phases 1-2** | **5 hours** | |

---

## User Stories

### Phase 1: CSV Export

**Story 1:** As a WHS Officer, I want to export all incidents to CSV so that I can analyze trends in Excel using pivot tables and charts.

**Story 2:** As a WHS Manager, I want to extract incident data for quarterly WorkSafe Queensland compliance reporting.

**Story 3:** As a Council Manager, I want to share incident data with our insurance provider without giving them direct system access.

### Phase 2: Sorting & Filtering

**Story 4:** As a WHS Officer, I want to sort incidents by severity so that I can prioritize which incidents to review first.

**Story 5:** As a Department Manager, I want to filter incidents by my department so that I can see only incidents relevant to my team.

**Story 6:** As a WHS Officer, I want to filter incidents by type (LTI, MTI, FAI) so that I can focus on injury patterns.

**Story 7:** As a WHS Manager, I want to find all open incidents from the last 30 days so that I can ensure timely resolution.

### Phase 3: Dashboard

**Story 8:** As a WHS Manager, I want to see a visual dashboard showing incident trends so that I can identify emerging safety issues.

**Story 9:** As the CEO, I want to see a high-level summary of safety performance so that I can report to the Board.

**Story 10:** As a WHS Officer, I want to see which departments have the most incidents so that I can target safety interventions.

---

## Technical Considerations

### CSV Export
- **Performance**: For large datasets (1000+ incidents), consider pagination or background task
- **Memory**: Use streaming approach for very large exports
- **Encoding**: UTF-8 with BOM for Excel compatibility
- **Security**: Respect Plone permissions - only export items user can view
- **Timestamps**: Use Australian timezone (AEST/AEDT)

### Sorting & Filtering
- **Approach**: Client-side JavaScript for <500 items, server-side for larger datasets
- **Current Dataset**: ~30-50 incidents expected in first year, client-side is appropriate
- **Scalability**: Monitor performance, migrate to server-side if needed
- **Browser Compatibility**: Test on Chrome, Firefox, Edge, Safari
- **Mobile**: Ensure filters work on tablets (WHS Officers use iPads in field)

### Dashboard & Charts
- **Chart Library**: Recommend Chart.js (25KB, no dependencies, excellent docs)
- **Caching**: Cache dashboard statistics (15-minute expiry)
- **Real-time**: Dashboard refreshes on page load, not real-time updates
- **Permissions**: Ensure WHS Officers can view aggregate data but not confidential incidents

---

## Security & Permissions

### Existing Permissions (Leverage these)
- **View Incidents**: WHS Officers, Managers, CEO
- **Export CSV**: Same as View permission (if you can see it, you can export it)
- **Confidential Incidents**: Respect existing confidential flag, exclude from exports

### New Permissions (Not needed)
- Reuse existing Plone view permissions
- No new permission types required

---

## Testing Plan

### Phase 1: CSV Export
- **Test 1**: Export empty list (no incidents)
- **Test 2**: Export single incident with all fields populated
- **Test 3**: Export 50+ incidents, verify Excel can open file
- **Test 4**: Verify date format is DD/MM/YYYY
- **Test 5**: Verify special characters (unicode, commas, quotes) are handled correctly
- **Test 6**: Verify confidential incidents are excluded (if implemented)
- **Test 7**: Test with non-admin user (WHS Officer permission)

### Phase 2: Sorting & Filtering
- **Test 8**: Click each column header, verify sort works correctly
- **Test 9**: Apply single filter (Type = FAI), verify correct incidents shown
- **Test 10**: Apply multiple filters, verify AND logic works
- **Test 11**: Clear filters, verify all incidents return
- **Test 12**: Test date range filter with various ranges
- **Test 13**: Test search box with partial matches
- **Test 14**: Test on tablet (iPad) - ensure filters are usable
- **Test 15**: Verify filter state persists on page refresh (localStorage)

### Phase 3: Dashboard
- **Test 16**: Verify summary statistics are accurate
- **Test 17**: Verify charts render correctly
- **Test 18**: Test dashboard with zero incidents
- **Test 19**: Verify department breakdown matches actual incidents
- **Test 20**: Test dashboard performance with 500+ incidents

---

## Deployment Strategy

### Phase 1 Deployment
1. Build and deploy csc.whs package with CSV export
2. No profile upgrade needed (new method only)
3. Test CSV export on development server
4. Deploy to production
5. Notify WHS Officers of new export feature

### Phase 2 Deployment
1. Deploy new JavaScript/CSS files
2. Update templates with filter panel
3. No profile upgrade needed
4. Test sorting and filtering on development
5. Deploy to production
6. Provide brief training to WHS Officers (5-minute demo)

### Phase 3 Deployment
1. Create new dashboard views
2. Register views in configure.zcml
3. Add dashboard links to listing views
4. Test charts and statistics
5. Deploy to production
6. Gather feedback from WHS Officers

---

## Success Metrics

### Phase 1
- **Usage**: WHS Officer uses CSV export at least monthly
- **Feedback**: WHS Officer confirms export meets reporting needs
- **Compliance**: Quarterly compliance reports can be generated from exports

### Phase 2
- **Efficiency**: Time to find specific incident reduced by 50%
- **Usage**: Filters used on >50% of listing page views
- **Satisfaction**: WHS Officer reports improved usability

### Phase 3
- **Visibility**: Dashboard accessed weekly by WHS Manager
- **Insights**: Dashboard insights lead to targeted safety interventions
- **Reporting**: Management uses dashboard for Board reporting

---

## Future Enhancements (Beyond Scope)

### Potential Future Features
1. **Scheduled Reports**: Email CSV export weekly/monthly
2. **Custom Report Builder**: Let users select which fields to export
3. **PDF Report Generation**: Generate formatted PDF incident reports
4. **API Integration**: REST API for third-party system integration
5. **Power BI Connector**: Direct integration with Microsoft Power BI
6. **Predictive Analytics**: ML model to predict high-risk periods
7. **Mobile App**: Native iOS/Android app for field incident reporting

---

## Appendix A: Similar Plone Implementations

### Reference Implementations
1. **collective.easyform** - CSV export from form submissions
2. **Products.DataGridField** - Sortable table columns
3. **collective.portlet.collage** - Dashboard-style layouts
4. **plone.restapi** - Reference for CSV export patterns

### Code Patterns to Reuse
- CSV generation with proper encoding
- Client-side table sorting with vanilla JavaScript
- Permission-aware catalog queries
- Date formatting utilities

---

## Appendix B: Field Mapping Reference

### Incident Object → CSV Column Mapping
```python
INCIDENT_CSV_MAPPING = {
    'reference_code': 'Reference Code',
    'title': 'Title',
    'incident_types': 'Incident Type(s)',  # Join with "/"
    'occurred_at': 'Date Occurred',  # Format: DD/MM/YYYY HH:MM
    'reported_at': 'Date Reported',
    'injured_person_name': 'Person Injured/Involved',
    'injured_person_username': 'Person Username',
    'person_relationship': 'Relationship to Council',
    'department': 'Department',  # Resolve to display name
    'location_town': 'Location Town',
    'location': 'Location Address',
    'location_latitude': 'GPS Latitude',
    'location_longitude': 'GPS Longitude',
    'incident_details': 'Incident Details',
    'circumstances': 'Circumstances',
    'immediate_actions': 'Immediate Actions',
    'emergency_services_called': 'Emergency Services Called',
    'emergency_services_types': 'Emergency Services Types',  # Join with "/"
    'supervisor_notified': 'Supervisor Notified',
    'severity': 'Severity',
    'review_state': 'Workflow State',
    'injury_body_areas': 'Injury Body Areas',  # Join with ", "
    'injury_classifications': 'Injury Classifications',  # Join with ", "
    'first_aid_given': 'First Aid Given',
    'medical_treatment_sought': 'Medical Treatment Sought',
    'property_damage_types': 'Property Damage Types',  # Join with ", "
    'plant_number': 'Plant Number',
    'contributing_factors_identified': 'Contributing Factors',
    'preventative_actions_suggested': 'Preventative Actions',
    'reported_by_name': 'Reported By',
    'reported_by_email': 'Reporter Email',
    'modified': 'Last Modified',  # Format: DD/MM/YYYY HH:MM
}
```

### Hazard Object → CSV Column Mapping
```python
HAZARD_CSV_MAPPING = {
    'reference_code': 'Reference Code',
    'title': 'Title',
    'hazard_categories': 'Hazard Categories',  # Join with "/"
    'identified_at': 'Date Identified',
    'reported_at': 'Date Reported',
    'location_town': 'Location Town',
    'location': 'Location Address',
    'location_latitude': 'GPS Latitude',
    'location_longitude': 'GPS Longitude',
    'hazard_description': 'Hazard Description',
    'risk_likelihood': 'Risk Likelihood',
    'risk_consequence': 'Risk Consequence',
    'risk_rating': 'Risk Rating',  # Calculated
    'immediate_actions': 'Immediate Actions Taken',
    'control_measures': 'Control Measures Recommended',
    'reported_by_name': 'Reported By',
    'reported_by_email': 'Reporter Email',
    'department': 'Department',
    'review_state': 'Workflow State',
    'modified': 'Last Modified',
}
```

---

## Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-20 | Claude Code | Initial implementation plan created |

---

## Approval & Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| WHS Officer | | | |
| WHS Manager | | | |
| IT Manager | | | |
| CEO | | | |

---

**END OF IMPLEMENTATION PLAN**
