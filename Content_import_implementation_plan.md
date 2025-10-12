# WHS Portal Content Import Implementation Plan

## Project Overview

**Objective:** Automate the import of WHS documentation from filesystem (`/home/ceo/HDRIVE/WHS/0.1_WHSMS_Portal_Approved`) into the Plone 6.1 WHS Portal using `collective.exportimport` with AI-enhanced metadata extraction.

**Approach:** Hybrid Python script that generates JSON files compatible with `collective.exportimport`, utilizing AI to extract rich metadata from documents (including document authors/approvers matched against Active Directory users), with caching to optimize re-runs and batching by parent folder to handle large imports.

**Recent Infrastructure Updates:**
- **Active Directory Integration:** WHS Portal integrated with AD domain controller via `pas.plugins.ldap` addon. All organizational users and groups accessible in Plone for workflow and content attribution.
- **LDAP Attribute Mapping:** Extended user attributes include phone, mobile, department, job_title, and manager (DN format).
- **Custom LDAP Utilities:** Both `cook.whs.barceloneta` and `csc.teams` addons provide `extract_cn_from_dn()` and `get_user_manager_name()` utilities for working with LDAP Distinguished Names.
- **HTTPS Frontend:** Production site accessible via nginx reverse proxy at `https://whsportal.cook.qld.gov.au` (secured with SSL/TLS).
- **User Consistency:** AI can extract document author/approver information and map to actual AD users in Plone for accurate content attribution.
- **VM Snapshots:** Rollback strategy based on VM snapshots of whsportaldev taken before each import attempt.
- **Import Tracking:** Comprehensive tracking system that monitors imported files without modifying H: drive, supporting incremental imports and change detection.

---

## Phase 0: Pre-Implementation Validation & Filesystem Audit

**Purpose:** Ensure accurate mapping, identify issues, and create comprehensive reports for manual review.

### 0.1 Filesystem Audit Script (`audit_filesystem.py`)

**Purpose:** Scan actual filesystem and generate accurate reports

**Functions:**
```python
def scan_filesystem(base_path: str) -> dict:
    """
    Recursively scan filesystem and categorize all files

    Returns: {
        'importable': [...],      # Files ready to import
        'legacy_formats': [...],  # .doc, .xls (old Office)
        'images': [...],          # .png, .jpg, .jpeg
        'excluded': [...],        # Thumbs.db, .DS_Store
        'duplicates': {},         # filename: [path1, path2, ...]
        'special_chars': [...],   # Files needing character fixes
        'total_size_bytes': int,
        'directory_tree': {}
    }
    """

def generate_path_mapping_from_scan(scan_results: dict, plone_export: dict) -> dict:
    """
    Generate filesystem → Plone path mappings by analyzing:
    - Filesystem directory structure
    - Existing Plone folder structure from export JSON
    - Match naming patterns between filesystem and Plone paths

    Returns: {
        'filesystem/path/': {
            'plone_path': 'whs-policies/all-staff-whs-procedures',
            'parent_uid': 'abc123...',
            'exists_in_plone': True/False
        }
    }
    """

def identify_duplicates(files: list) -> dict:
    """Find files with same name in different locations"""

def identify_special_characters(files: list) -> list:
    """Find files with problematic characters in names"""

def generate_audit_report(scan_results: dict, path_mappings: dict) -> str:
    """
    Generate comprehensive audit report for manual review

    Report sections:
    1. Import Summary Statistics
    2. Files Ready for Import (by folder)
    3. Missing Plone Folders (require manual creation)
    4. Duplicate Filenames (require manual review)
    5. Legacy Office Formats (skipped, manual handling required)
    6. Image Files (skipped, manual handling required)
    7. Files with Special Characters (require renaming)
    8. Estimated JSON Size per Batch
    """
```

**Execution:**
```bash
python audit_filesystem.py --base-path /home/ceo/HDRIVE/WHS/0.1_WHSMS_Portal_Approved \
                           --export-json /home/ceo/Development/WHSPortal/Content/whsportal.json \
                           --output import_data/filesystem_audit_report.json
```

**Output Files:**
- `import_data/filesystem_audit_report.json` - Machine-readable audit data
- `import_data/filesystem_audit_report.md` - Human-readable markdown report
- `import_data/path_mappings.json` - Generated path mappings for review

**Test Cases:**
- [ ] Detect all 3 Thumbs.db files for exclusion
- [ ] Identify duplicate filenames (e.g., WHSProcedure-EmergencyResponse-LVRescue.pdf × 2)
- [ ] Flag legacy Office formats (.doc, .xls)
- [ ] Identify image files (Safety Alert #0001.png)
- [ ] Detect special characters (#, spaces, etc.)
- [ ] Calculate accurate file counts and sizes
- [ ] Match filesystem directories to Plone folders

---

### 0.2 Filename Sanitization Script (`sanitize_filenames.py`)

**Purpose:** Fix problematic characters in filenames before import processing

**Strategy:**
- Replace spaces with underscores
- Remove hash symbols (#)
- Remove or replace other problematic characters: `, ?, *, <, >, |, :, ", \`
- Preserve file extensions
- Create backup mapping of original → sanitized names
- **Important:** Only rename files in a temporary working directory, not the original H: drive

**Functions:**
```python
def sanitize_filename(filename: str) -> str:
    """
    Clean filename of problematic characters

    Rules:
    - Spaces → underscores
    - # → removed
    - Special chars → removed or replaced
    - Multiple underscores → single underscore
    - Leading/trailing underscores → removed
    - Preserve extension

    Examples:
    'Safety Alert #0001.png' → 'Safety_Alert_0001.png'
    'WHSTemplate _Letter_of_Authority_Return-to-Work_Coordination.dotx'
      → 'WHSTemplate_Letter_of_Authority_Return-to-Work_Coordination.dotx'
    """

def create_working_copy(source_dir: str, dest_dir: str, file_list: list) -> dict:
    """
    Copy files to working directory with sanitized names
    Preserves directory structure

    Returns: {
        'original_path': 'sanitized_path',
        ...
    }
    """

def generate_rename_report(mappings: dict) -> str:
    """Report of original → sanitized filename mappings"""
```

**Execution:**
```bash
# Create sanitized working copy
python sanitize_filenames.py --source /home/ceo/HDRIVE/WHS/0.1_WHSMS_Portal_Approved \
                              --dest /home/ceo/Development/WHSPortal/import_working_copy \
                              --report import_data/filename_sanitization_report.json
```

**Test Cases:**
- [ ] Handle 'Safety Alert #0001.png' correctly
- [ ] Fix 'WHSTemplate _Letter_of_Authority...' (leading space after underscore)
- [ ] Handle multiple consecutive spaces
- [ ] Preserve file extensions exactly
- [ ] Detect naming collisions after sanitization

---

### 0.3 Plone Structure Validator (`validate_plone_structure.py`)

**Purpose:** Verify all required parent folders exist in Plone

**Functions:**
```python
def load_plone_export(export_path: str) -> dict:
    """Parse whsportal.json and extract folder structure"""

def get_all_folders_with_uids(plone_data: dict) -> dict:
    """
    Extract all folders from export

    Returns: {
        'emergency-management/emergency-procedures': {
            'uid': '40d53ce4979347bbaf53540f4a573ba2',
            'title': 'Emergency Procedures',
            'full_path': 'whsportal/emergency-management/emergency-procedures'
        },
        ...
    }
    """

def validate_path_mappings(path_mappings: dict, plone_folders: dict) -> dict:
    """
    Check if all mapped parent folders exist

    Returns: {
        'valid': [{filesystem_path, plone_path, uid}, ...],
        'missing': [{filesystem_path, expected_plone_path}, ...],
        'no_mapping': [filesystem_path, ...]
    }
    """

def generate_validation_report(validation_results: dict) -> str:
    """Report showing which folders exist, which are missing"""
```

**Test Cases:**
- [ ] Verify all UIDs in path mapping exist in Plone export
- [ ] Identify unmapped filesystem directories
- [ ] Flag filesystem folders with no corresponding Plone location

---

### 0.4 AI Extraction Testing (`test_ai_extraction.py`)

**Purpose:** Test AI metadata extraction on sample files before full run

**Test Files:**
1. 1 PDF: `WHS_Procedure_Incident_and_Hazard_Reporting.pdf`
2. 1 DOCX: `WHSTemplate_Toolbox_Agenda_Notes_Attendees.dotx`
3. 1 Legacy DOC: (any .doc file found)
4. 1 Image: `Safety Alert #0001.png` (even though skipped, test extraction)

**Validation:**
- [ ] Verify summary extraction quality
- [ ] Check author/approver name extraction
- [ ] Test document date extraction
- [ ] Validate key topics extraction
- [ ] Estimate API costs per document
- [ ] Check extraction time per document

---

## Phase 1: Environment Setup & Validation

### 1.1 Verify collective.exportimport Installation
- [ ] Confirm `collective.exportimport` is installed in Plone virtual environment
- [ ] Verify add-on is activated in WHS Portal site
- [ ] Test export/import functionality via Plone UI (`@@export_content`, `@@import_content`)

### 1.2 Analyze Exported Content Structure
- [ ] Review existing export file: `/home/ceo/Development/WHSPortal/Content/whsportal.json`
- [ ] Document JSON structure for File content types
- [ ] Extract all parent folder UIDs and paths
- [ ] Identify required vs optional fields
- [ ] Note: Base URL format is `http://whsportaldev.cook.local:8080/whsportal/`

### 1.3 Verify Active Directory Integration
- [ ] Confirm `pas.plugins.ldap` is installed and configured
- [ ] Test Plone API user enumeration: `acl_users.searchUsers()`
- [ ] Verify AD users are accessible in Plone
- [ ] Document user object structure (id, fullname, email, phone, mobile, department, job_title, manager)
- [ ] Review LDAP attribute mappings in `cook.whs.barceloneta/profiles/default/ldapsettings.xml`
- [ ] Test existing LDAP utilities: `extract_cn_from_dn()`, `get_user_manager_name()`
- [ ] Understand how `csc.teams` vocabularies retrieve user lists

### 1.4 VM Snapshot Strategy
- [ ] Document VM snapshot procedure for whsportaldev
- [ ] Establish snapshot naming convention (e.g., `whsportaldev_pre_import_YYYY-MM-DD`)
- [ ] Test snapshot creation and restoration process
- [ ] Create initial snapshot before any import testing

### 1.5 Create Project Directory Structure
```
/home/ceo/Development/WHSPortal/
├── Content/                          # Existing export
│   └── whsportal.json
├── import_working_copy/              # NEW: Sanitized filesystem copy
│   └── [mirrors HDRIVE structure]
├── import_scripts/                   # NEW: Python scripts
│   ├── config.py                     # Configuration
│   ├── audit_filesystem.py           # Phase 0.1: Filesystem audit
│   ├── sanitize_filenames.py         # Phase 0.2: Filename cleaning
│   ├── validate_plone_structure.py   # Phase 0.3: Plone validation
│   ├── test_ai_extraction.py         # Phase 0.4: AI testing
│   ├── path_mapper.py                # Filesystem → Plone path mapping
│   ├── ai_extractor.py               # AI metadata extraction
│   ├── ad_user_mapper.py             # AD user ID mapping
│   ├── json_generator.py             # JSON generation for import
│   ├── import_tracker.py             # Import tracking and status management
│   ├── check_import_status.py        # CLI tool to check import status
│   └── main.py                       # Orchestration script
├── import_data/                      # NEW: Generated import files & reports
│   ├── filesystem_audit_report.json  # Phase 0 audit data
│   ├── filesystem_audit_report.md    # Phase 0 human-readable report
│   ├── filename_sanitization_report.json
│   ├── path_mappings.json            # Generated filesystem → Plone mappings
│   ├── plone_validation_report.json
│   ├── summaries_cache.json          # AI-extracted summaries
│   ├── ad_users_cache.json           # AD user lookup cache
│   ├── imported_files_tracker.json   # Import tracking database (H: drive unchanged)
│   ├── imported_files_report.html    # Visual import status report for WHS Officer
│   ├── imported_files_report.csv     # Excel-compatible import status export
│   ├── import_batches/               # Batched JSON files by folder
│   │   ├── batch_001_emergency_procedures.json
│   │   ├── batch_002_whs_forms.json
│   │   └── ...
│   ├── import_log.json               # Processing log
│   └── manual_review_report.md       # Items requiring manual review
└── Content_import_implementation_plan.md  # This document
```

---

## Phase 2: Path Mapping & Configuration

### 2.1 Generate Filesystem → Plone Path Mapping

**Approach:** Use Phase 0 audit script to generate mappings, then manually review and adjust.

**Expected Filesystem Structure** (from actual scan):
```
/home/ceo/HDRIVE/WHS/0.1_WHSMS_Portal_Approved/
├── Portal_Display/
├── WHS_Community/
├── WHS_Emergency Management/          # Note: space in name!
│   ├── Emergency_Management_Templates_Forms/
│   ├── Emergency_Procedures/
│   ├── Empergency_Plan/               # Note: typo "Empergency"
│   └── Evacuation_Diagrams/
├── WHS_Forms_Templates/
│   ├── All-staff_WHS_Forms_Templates/
│   └── Divisional_Specific_WHS_Forms_Templates/
├── WHS_Inductions/
│   ├── Contractor_Safety_Induction/
│   ├── General_WHS_Induction/
│   └── Outdoor_Worker_Induction/
└── WHS_Plans_Policy_Procedures/
    ├── All-staff_WHS_Procedures/
    ├── Divisional_Specific_WHS_Procedures/
    ├── Plans/
    └── WHS_Policy/
```

**Mapping Strategy:**
1. Auto-generate initial mappings by:
   - Analyzing Plone export for folder structure and UIDs
   - Matching filesystem directory names to Plone paths (fuzzy matching on normalized names)
2. Generate `path_mappings.json` for manual review
3. WHS Officer reviews and confirms mappings
4. Flag unmapped directories in manual review report

**Manual Review Items:**
- Directories on filesystem with no Plone equivalent → Flag, don't import
- Directories in Plone with no filesystem content → Ignore
- Ambiguous mappings → Manual decision required

### 2.2 File Type Handling Rules

| File Type | Action | Notes |
|-----------|--------|-------|
| PDF (`.pdf`) | **Import** | Use File content type |
| Word (`.docx`, `.dotx`) | **Import** | Use File content type |
| Excel (`.xlsx`, `.xltm`) | **Import** | Use File content type |
| PowerPoint (`.potx`, `.pptx`) | **Import** | Use File content type |
| Legacy Office (`.doc`, `.xls`, `.ppt`) | **Skip** | Flag in report for manual handling |
| Images (`.png`, `.jpg`, `.jpeg`) | **Skip** | Flag in report for manual handling |
| System Files (`Thumbs.db`, `.DS_Store`) | **Exclude** | Silent exclusion |
| Duplicate Filenames | **Import + Link** | Import to primary location, create links in other locations |

### 2.2.1 Duplicate Filename Handling Strategy

**Approach:** Import once to primary location, create Plone Link content type in other locations

**Process:**
1. **Identify duplicates** (same filename, different paths) during Phase 0.1 audit
2. **Determine primary location** (manual decision by WHS Officer based on context)
3. **Import file** to primary location as normal File content type
4. **Create Link content** in secondary locations pointing to primary file
5. **Link metadata:**
   - Title: Same as original file
   - Description: "This document is available at [primary location]. Click to view."
   - Remote URL: Full Plone URL to primary file (e.g., `http://whsportaldev.cook.local:8080/whsportal/whs-policies/all-staff-whs-procedures/whsprocedure-emergencyresponse-lvrescue-pdf`)
   - Link content type allows users to click and be redirected to actual file

**Example:**
```
Duplicate: WHSProcedure-EmergencyResponse-LVRescue.pdf
- Primary: WHS_Emergency Management/Emergency_Procedures/ → Import as File
- Secondary: WHS_Plans_Policy_Procedures/Divisional_Specific_WHS_Procedures/ → Create Link

Link JSON structure:
{
  "@type": "Link",
  "id": "whsprocedure-emergencyresponse-lvrescue-pdf",
  "title": "WHSProcedure-EmergencyResponse-LVRescue.pdf",
  "description": "This procedure is available in Emergency Procedures. Click to view.",
  "remoteUrl": "http://whsportaldev.cook.local:8080/whsportal/emergency-management/emergency-procedures/whsprocedure-emergencyresponse-lvrescue-pdf",
  "parent": {...}
}
```

**Benefits:**
- ✅ Single source of truth - no duplicate content
- ✅ File appears in multiple locations (via links)
- ✅ Updates only needed in one place
- ✅ Clear navigation for users
- ✅ Maintains folder structure expectations

**Implementation:**
- Duplicate tracking added to `audit_filesystem.py` ✓
- Primary location decision made during Phase 0 manual review ✓
- Link generation added to `json_generator.py` (Phase 3)
- Import tracker records both File and Link creations

### 2.3 Configuration File (`config.py`)

```python
"""Configuration for WHS Portal content import."""

import os

# ============================================================================
# SOURCE PATHS
# ============================================================================

# Original filesystem location (read-only reference)
FILESYSTEM_BASE_ORIGINAL = "/home/ceo/HDRIVE/WHS/0.1_WHSMS_Portal_Approved"

# Working copy with sanitized filenames (actual import source)
FILESYSTEM_BASE_WORKING = "/home/ceo/Development/WHSPortal/import_working_copy"

# Use working copy for processing
FILESYSTEM_BASE = FILESYSTEM_BASE_WORKING

# ============================================================================
# PLONE CONFIGURATION
# ============================================================================

# Plone URLs
PLONE_INTERNAL_URL = "http://whsportaldev.cook.local:8080/whsportal"
PLONE_EXTERNAL_URL = "https://whsportal.cook.qld.gov.au"
PLONE_BASE_URL = PLONE_INTERNAL_URL  # Use for JSON generation

# Plone authentication (if needed for API calls)
PLONE_USERNAME = os.environ.get('PLONE_USERNAME', 'admin')
PLONE_PASSWORD = os.environ.get('PLONE_PASSWORD', '')

# ============================================================================
# WORKING DIRECTORIES
# ============================================================================

BASE_DIR = "/home/ceo/Development/WHSPortal"
IMPORT_DATA_DIR = os.path.join(BASE_DIR, "import_data")
IMPORT_BATCHES_DIR = os.path.join(IMPORT_DATA_DIR, "import_batches")

# Input files
PLONE_EXPORT_JSON = os.path.join(BASE_DIR, "Content/whsportal.json")
PATH_MAPPINGS_FILE = os.path.join(IMPORT_DATA_DIR, "path_mappings.json")

# Cache files
CACHE_FILE = os.path.join(IMPORT_DATA_DIR, "summaries_cache.json")
AD_USERS_CACHE = os.path.join(IMPORT_DATA_DIR, "ad_users_cache.json")

# Output files
LOG_FILE = os.path.join(IMPORT_DATA_DIR, "import_log.json")
MANUAL_REVIEW_REPORT = os.path.join(IMPORT_DATA_DIR, "manual_review_report.md")

# Import tracking files
IMPORT_TRACKER_FILE = os.path.join(IMPORT_DATA_DIR, "imported_files_tracker.json")
IMPORT_STATUS_HTML = os.path.join(IMPORT_DATA_DIR, "imported_files_report.html")
IMPORT_STATUS_CSV = os.path.join(IMPORT_DATA_DIR, "imported_files_report.csv")

# ============================================================================
# BATCHING CONFIGURATION
# ============================================================================

# Create separate JSON file for each parent folder
BATCH_BY_FOLDER = True

# Alternative: Batch by size/count (if not batching by folder)
MAX_JSON_SIZE_MB = 50
MAX_FILES_PER_BATCH = 10

# ============================================================================
# DEFAULT METADATA
# ============================================================================

# Fallback user if author not found or mapping fails
DEFAULT_CREATORS = ["admin"]  # Changed from "whsofficer" to "admin" as safe fallback
DEFAULT_REVIEW_STATE = "published"
DEFAULT_EFFECTIVE_DATE = "2025-10-01T00:00:00+00:00"

# Language
DEFAULT_LANGUAGE = {
    "title": "English (United Kingdom)",
    "token": "en-gb"
}

# ============================================================================
# FILE HANDLING
# ============================================================================

# System files to always exclude (silent)
EXCLUDED_FILES = ["Thumbs.db", ".DS_Store", "desktop.ini"]

# Allowed file extensions for import
ALLOWED_EXTENSIONS = [
    ".pdf",
    ".docx", ".dotx",
    ".xlsx", ".xltm",
    ".potx", ".pptx"
]

# Legacy formats to skip with report entry
LEGACY_EXTENSIONS = [".doc", ".xls", ".ppt"]

# Image formats to skip with report entry
IMAGE_EXTENSIONS = [".png", ".jpg", ".jpeg", ".gif", ".bmp"]

# ============================================================================
# AI EXTRACTION CONFIGURATION
# ============================================================================

# AI extraction settings
AI_MODEL = "claude-sonnet-4"  # If using Anthropic API
EXTRACTION_ENABLED = True
EXTRACT_AUTHORS = True  # Enable author/approver extraction from documents

# Extraction prompt template
AI_EXTRACTION_PROMPT = """Analyze this WHS document and extract metadata.

Document: {filename}

Extract the following information:

1. **Summary**: Write a 2-3 sentence overview suitable for a description field in a content management system.

2. **Key Topics**: Identify 3-5 keywords or tags that categorize this document (e.g., "incident reporting", "safety", "compliance").

3. **Document Type**: Classify as one of: procedure, template, form, guide, plan, policy, alert, training, or other.

4. **Target Audience**: Identify the intended audience: all-staff, contractors, managers, specific-division, or other.

5. **Authors**: Look for author names in:
   - Document properties/metadata
   - "Prepared by" sections
   - Headers or footers
   - If multiple authors, list all
   - Extract full names (e.g., "Natalie Henderson", "John Smith")

6. **Approvers**: Look for approver/reviewer names in:
   - "Approved by" or "Reviewed by" sections
   - Signature blocks
   - Document control sections
   - Extract full names

7. **Document Date**: Extract the most relevant date:
   - Effective date
   - Approval date
   - Last modified/revision date
   - Format as YYYY-MM-DD or null if not found

Respond in JSON format only:
{{
  "summary": "...",
  "key_topics": ["...", "..."],
  "document_type": "...",
  "target_audience": "...",
  "authors": ["Full Name", "..."],
  "approvers": ["Full Name", "..."],
  "document_date": "YYYY-MM-DD or null"
}}
"""

# ============================================================================
# ACTIVE DIRECTORY USER MAPPING
# ============================================================================

# Enable AD user mapping for creators/contributors
AD_USER_MAPPING_ENABLED = True

# Fallback user if AD lookup fails (should exist in Plone)
AD_USER_FALLBACK = "admin"

# Cache refresh interval (hours)
AD_CACHE_REFRESH_HOURS = 24

# Manual user name overrides (for known ambiguous cases)
MANUAL_USER_MAPPINGS = {
    "N. Henderson": "natalieh",
    "WHS Manager": "whsofficer",
    "WHS Officer": "whsofficer",
    # Add more as needed during testing
}

# Use existing LDAP utilities from addons
USE_LDAP_UTILS = True  # Import from cook.whs.barceloneta.utils

# ============================================================================
# DUPLICATE FILE HANDLING
# ============================================================================

# Duplicate filename handling: import to primary location, create links in others
DUPLICATE_HANDLING_STRATEGY = "import_and_link"  # or "skip_all" to flag only

# Primary locations for known duplicates (determined during Phase 0 manual review)
DUPLICATE_PRIMARY_LOCATIONS = {
    "WHSProcedure-EmergencyResponse-LVRescue.pdf": "WHS_Emergency Management/Emergency_Procedures",
    "WHSProcedure-TrenchCollapseRescueResponse.pdf": "WHS_Emergency Management/Emergency_Procedures",
    # Add more as identified during Phase 0 review
}

# Link description template for secondary locations
DUPLICATE_LINK_DESCRIPTION = "This document is available in {primary_folder}. Click to view."

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Continue processing other files if one fails
CONTINUE_ON_ERROR = True

# Log level
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR

# ============================================================================
# MANUAL REVIEW TRIGGERS
# ============================================================================

# Automatically flag for manual review:
FLAG_UNMAPPED_DIRECTORIES = True
FLAG_DUPLICATE_FILENAMES = True  # Still flag for visibility, but will auto-handle if strategy set
FLAG_LEGACY_FORMATS = True
FLAG_IMAGE_FILES = True
FLAG_MISSING_PLONE_FOLDERS = True
FLAG_AMBIGUOUS_USER_MAPPINGS = True  # Multiple possible AD user matches
FLAG_UNKNOWN_USERS = True  # Extracted name not found in AD
```

---

## Phase 3: Core Script Development

### 3.1 Path Mapper Module (`path_mapper.py`)

**Purpose:** Map filesystem paths to Plone parent UIDs and generate content IDs

**Functions:**
```python
def load_path_mappings(mappings_file: str) -> dict:
    """Load filesystem → Plone path mappings from JSON file"""

def get_parent_info(filesystem_path: str, mappings: dict) -> dict:
    """
    Return: {
        'parent_uid': 'abc123...',
        'parent_path': 'whs-policies/all-staff-whs-procedures',
        'parent_url': 'http://whsportaldev.cook.local:8080/whsportal/whs-policies/...',
        'exists_in_plone': True,
        'batch_name': 'all_staff_whs_procedures'  # For batching
    }
    Or None if no mapping found
    """

def generate_plone_id(filename: str, parent_path: str = '') -> str:
    """
    Convert sanitized filename to Plone-friendly ID

    NOTE: Filenames already sanitized by Phase 0.2 script

    Rules:
    - Lowercase
    - Replace remaining underscores with hyphens
    - Include file extension in ID (for uniqueness)
    - Ensure uniqueness within parent folder

    Examples:
    'Safety_Alert_0001.png' → 'safety-alert-0001-png'
    'WHS_Procedure_Incident_and_Hazard_Reporting.pdf'
      → 'whs-procedure-incident-and-hazard-reporting-pdf'
    """

def should_process_file(filepath: str, filename: str) -> tuple[bool, str]:
    """
    Check if file should be included

    Returns: (should_process: bool, reason: str)

    Reasons:
    - 'import': File should be imported
    - 'excluded': System file (Thumbs.db)
    - 'legacy': Legacy Office format
    - 'image': Image file
    - 'duplicate': Duplicate filename
    """

def group_files_by_parent(files: list, mappings: dict) -> dict:
    """
    Group files by parent folder for batching

    Returns: {
        'batch_name_1': {
            'parent_uid': '...',
            'parent_path': '...',
            'files': [...]
        },
        ...
    }
    """
```

**Test Cases:**
- [ ] Load path mappings from JSON
- [ ] Map sanitized filenames to parent UIDs
- [ ] Generate unique Plone IDs
- [ ] Handle files with no mapping (return None)
- [ ] Group files correctly by parent folder

---

### 3.2 AI Extractor Module (`ai_extractor.py`)

**Purpose:** Extract metadata from documents using AI, with caching

**Functions:**
```python
def load_cache(cache_file: str) -> dict:
    """Load existing summaries from cache file"""

def save_cache(cache: dict, cache_file: str):
    """Save summaries to cache file"""

def get_file_hash(filepath: str) -> str:
    """Calculate SHA256 hash of file for change detection"""

def extract_metadata_from_document(filepath: str, filename: str) -> dict:
    """
    Use AI (Claude via Read tool) to extract metadata

    Process:
    1. Read document content (PDF, Word)
    2. Format extraction prompt
    3. Send to Claude
    4. Parse JSON response
    5. Validate required fields

    Return: {
        'summary': '...',
        'key_topics': ['incident reporting', 'safety'],
        'document_type': 'procedure',
        'target_audience': 'all-staff',
        'authors': ['Natalie Henderson', 'John Smith'],
        'approvers': ['Jane Doe'],
        'document_date': '2024-09-15',
        'extracted_date': '2025-10-06',
        'file_hash': 'abc123...',
        'extraction_success': True
    }

    On failure: Returns dict with extraction_success=False
    """

def get_or_extract_metadata(filepath: str, filename: str, cache: dict, force_refresh: bool = False) -> dict:
    """
    Check cache first, extract if:
    - Not in cache
    - File hash changed
    - Cache entry missing required fields
    - force_refresh=True

    Cache key: filename (sanitized)
    """

def validate_extraction(metadata: dict) -> bool:
    """Check that required fields are present and valid"""
```

**Extraction Strategy:**
1. Use Claude Code's Read tool to read document
2. Format extraction prompt with document content
3. Request structured JSON response
4. Parse and validate
5. Cache result keyed by sanitized filename + hash

**Test Cases:**
- [ ] Extract from sample PDF
- [ ] Extract from sample DOCX
- [ ] Verify cache creation and reuse
- [ ] Test cache invalidation on file change
- [ ] Handle extraction errors gracefully
- [ ] Validate author name extraction
- [ ] Validate document date extraction

---

### 3.3 AD User Mapper Module (`ad_user_mapper.py`)

**Purpose:** Map extracted author/approver names to Active Directory user IDs in Plone

**Leverages:** Existing LDAP integration and utilities from `cook.whs.barceloneta` and `csc.teams` addons.

**Functions:**
```python
def load_ad_users_cache(cache_file: str) -> dict:
    """Load cached AD user mapping from file"""

def save_ad_users_cache(cache: dict, cache_file: str):
    """Save AD user mapping to cache file"""

def fetch_plone_users_via_api() -> list:
    """
    Query Plone to get all users from AD

    Two approaches:
    1. REST API: GET http://whsportaldev.cook.local:8080/whsportal/@users
    2. Python script approach: Use acl_users.searchUsers() like csc.teams vocabulary

    Returns list of user objects with:
    - id (username)
    - fullname (CN from LDAP)
    - email
    - Additional LDAP properties: phone, mobile, department, job_title, manager
    """

def extract_cn_from_dn(dn: str) -> str:
    """
    Import from cook.whs.barceloneta.utils
    Extract Common Name from LDAP Distinguished Name

    Example: 'CN=Scott Johnson,OU=Workshop,...' → 'Scott Johnson'
    """

def build_user_lookup_dict(users: list) -> dict:
    """
    Create lookup dictionary for fuzzy matching

    Multiple keys per user for flexibility:
    - Full name (normalized)
    - Last name only
    - First name + last name
    - Username

    Example:
    {
        'natalie henderson': 'natalieh',
        'henderson': 'natalieh',
        'natalieh': 'natalieh',
        'n henderson': 'natalieh',
        'john smith': 'jsmith',
        'smith': 'jsmith',  # AMBIGUOUS - flag if multiple Smiths
        ...
    }

    For ambiguous keys (multiple users with same last name):
    Store as list: 'smith': ['jsmith', 'msmith', 'asmith']
    """

def normalize_name(name: str) -> str:
    """
    Normalize name for matching

    Rules:
    - Lowercase
    - Strip whitespace
    - Remove punctuation (periods, commas)
    - Remove titles (Mr., Ms., Dr.)
    """

def find_user_id(name: str, user_lookup: dict, manual_overrides: dict, fallback: str = 'admin') -> tuple:
    """
    Map extracted name to Plone user ID using fuzzy matching

    Strategies (in order):
    1. Check manual overrides first
    2. Exact match on normalized full name
    3. Match on last name only (if unambiguous)
    4. Match on first initial + last name
    5. Return fallback if no match

    Returns: (user_id: str, confidence: str, ambiguous: bool)

    Confidence levels:
    - 'manual': From manual override
    - 'exact': Exact full name match
    - 'high': Last name match (unambiguous)
    - 'medium': First initial + last name match
    - 'low': Ambiguous match (multiple possibilities)
    - 'fallback': No match found

    If ambiguous=True, log for manual review
    """

def map_authors_to_user_ids(authors: list, user_lookup: dict, manual_overrides: dict) -> dict:
    """
    Convert list of author names to list of Plone user IDs

    Returns: {
        'user_ids': ['natalieh', 'jsmith'],
        'mappings': [
            {'name': 'Natalie Henderson', 'user_id': 'natalieh', 'confidence': 'exact'},
            {'name': 'John Smith', 'user_id': 'jsmith', 'confidence': 'high'}
        ],
        'unmapped': [],  # Names that couldn't be mapped
        'ambiguous': []  # Names with multiple possible matches
    }
    """

def refresh_ad_users_cache(force: bool = False) -> dict:
    """
    Fetch fresh user list from Plone and update cache
    Only refresh if cache is older than AD_CACHE_REFRESH_HOURS or force=True

    Returns: Updated user lookup dictionary
    """

def generate_user_mapping_report(mapping_results: list) -> str:
    """Generate report of all author/approver mappings for review"""
```

**User Mapping Strategy:**
1. On first run, fetch all users from Plone (like `csc.teams.vocabularies.users_vocabulary`)
2. Build normalized lookup dictionary with multiple keys per user
3. Cache for 24 hours to avoid repeated queries
4. For each extracted name:
   - Check manual overrides first
   - Try exact full name match
   - Try last name match (if unambiguous)
   - Try first initial + last name
   - Log ambiguous matches
   - Fall back to default user if no match
5. Generate mapping report with confidence levels

**LDAP Integration Notes:**
- User fullname comes from `cn` attribute (Common Name)
- Manager field is LDAP DN format (e.g., `CN=Scott Johnson,OU=...`)
- Use `extract_cn_from_dn()` utility if manager info needed
- Additional attributes available: phone, mobile, department, job_title
- Reference `csc.teams/src/csc/teams/vocabularies.py` for user enumeration approach

**Test Cases:**
- [ ] Fetch users from Plone (test both API and acl_users.searchUsers approaches)
- [ ] Test name normalization
- [ ] Test exact full name matching
- [ ] Test last name matching (unambiguous)
- [ ] Test last name matching (ambiguous - multiple Smiths)
- [ ] Test first initial + last name matching
- [ ] Test manual overrides
- [ ] Test fallback for unknown names
- [ ] Verify cache persistence and refresh logic
- [ ] Generate user mapping report

---

### 3.4 Import Tracker Module (`import_tracker.py`)

**Purpose:** Track imported files without modifying H: drive, support incremental imports and status checking

**Strategy:** Maintain JSON database of all imported files with metadata, generate multiple report formats for different audiences.

**Functions:**
```python
def load_import_tracker(tracker_file: str) -> dict:
    """
    Load import tracking database

    Returns: {
        'last_updated': '2025-10-06T15:30:00',
        'total_imported': 20,
        'files': {
            'filename': {
                'filesystem_path': '...',
                'imported_date': '...',
                'import_batch': '...',
                'plone_url': '...',
                'plone_id': '...',
                'file_hash': '...',
                'status': 'imported' | 'failed' | 'pending',
                'creators': [...],
                'imported_by': '...',
                'last_checked': '...'
            }
        }
    }
    """

def save_import_tracker(tracker: dict, tracker_file: str):
    """Save import tracking database to JSON file"""

def add_imported_file(tracker: dict, file_info: dict) -> dict:
    """
    Add successfully imported file to tracker

    file_info: {
        'filename': '...',
        'filesystem_path': '...',
        'import_batch': '...',
        'plone_url': '...',
        'plone_id': '...',
        'file_hash': '...',
        'creators': [...],
        'imported_by': '...'
    }
    """

def mark_file_failed(tracker: dict, filename: str, error: str) -> dict:
    """Mark file as failed with error message"""

def is_file_imported(tracker: dict, filename: str, file_hash: str = None) -> tuple:
    """
    Check if file has been imported

    Returns: (imported: bool, status: str, info: dict)

    If file_hash provided, also checks if file has changed since import
    """

def get_files_needing_import(filesystem_base: str, tracker: dict, path_mappings: dict) -> list:
    """
    Scan filesystem and return files that need import:
    1. New files (not in tracker)
    2. Modified files (hash changed since import)
    3. Previously failed imports (status='failed')

    Returns list of file paths with reasons
    """

def generate_html_report(tracker: dict, output_file: str):
    """
    Generate HTML report for WHS Officer viewing in browser

    Features:
    - Searchable/filterable table (JavaScript)
    - Color-coded status (green=imported, red=failed, yellow=pending)
    - Clickable Plone URLs
    - Sort by filename, date, status
    - Summary statistics at top
    """

def generate_csv_report(tracker: dict, output_file: str):
    """
    Generate CSV for Excel viewing/manipulation

    Columns:
    - Filename
    - Location (filesystem path)
    - Status
    - Import Date
    - Plone URL
    - Creators
    - Batch
    """

def get_import_statistics(tracker: dict) -> dict:
    """
    Calculate statistics for reporting

    Returns: {
        'total_files': int,
        'imported': int,
        'failed': int,
        'pending': int,
        'last_import_date': str,
        'files_by_batch': {...}
    }
    """

def check_plone_content_exists(plone_url: str, plone_id: str) -> bool:
    """
    Optional: Verify imported content still exists in Plone via REST API
    Useful for validating tracker accuracy
    """
```

**Tracker JSON Structure** (`imported_files_tracker.json`):
```json
{
  "last_updated": "2025-10-06T15:30:00",
  "total_imported": 20,
  "files": {
    "WHS_Procedure_Incident_and_Hazard_Reporting.pdf": {
      "filename": "WHS_Procedure_Incident_and_Hazard_Reporting.pdf",
      "filesystem_path": "/home/ceo/HDRIVE/WHS/0.1_WHSMS_Portal_Approved/WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/WHS_Procedure_Incident_and_Hazard_Reporting.pdf",
      "imported_date": "2025-10-06T14:30:00",
      "import_batch": "batch_003_all_staff_procedures.json",
      "plone_url": "http://whsportaldev.cook.local:8080/whsportal/whs-policies/all-staff-whs-procedures/whs-procedure-incident-and-hazard-reporting-pdf",
      "plone_id": "whs-procedure-incident-and-hazard-reporting-pdf",
      "parent_uid": "1ad8f065ce7e45cbbd240b573f992573",
      "file_hash": "abc123def456...",
      "file_size_bytes": 363725,
      "status": "imported",
      "creators": ["natalieh"],
      "imported_by": "admin",
      "last_checked": "2025-10-06T14:30:00"
    },
    "WHSTemplate_Toolbox_Agenda_Notes_Attendees.dotx": {
      "filename": "WHSTemplate_Toolbox_Agenda_Notes_Attendees.dotx",
      "filesystem_path": "/home/ceo/HDRIVE/WHS/.../WHSTemplate_Toolbox_Agenda_Notes_Attendees.dotx",
      "imported_date": "2025-10-06T14:35:00",
      "import_batch": "batch_002_whs_forms.json",
      "plone_url": "http://whsportaldev.cook.local:8080/whsportal/whs-forms/all-staff-whs-forms-templates/whstemplate-toolbox-agenda-notes-attendees-dotx",
      "plone_id": "whstemplate-toolbox-agenda-notes-attendees-dotx",
      "parent_uid": "ca51c0d418bb4e82845339179357883b",
      "file_hash": "def789ghi012...",
      "file_size_bytes": 125600,
      "status": "imported",
      "creators": ["natalieh"],
      "imported_by": "admin",
      "last_checked": "2025-10-06T14:35:00"
    },
    "Old_WHS_Procedure.doc": {
      "filename": "Old_WHS_Procedure.doc",
      "filesystem_path": "/home/ceo/HDRIVE/WHS/.../Old_WHS_Procedure.doc",
      "attempted_date": "2025-10-06T14:40:00",
      "status": "failed",
      "error": "Legacy Office format - skipped for manual handling",
      "file_hash": "xyz789abc123...",
      "last_checked": "2025-10-06T14:40:00"
    }
  }
}
```

**HTML Report Features:**
- Bootstrap-based responsive design
- DataTables.js for sorting/filtering/search
- Summary cards at top (Total, Imported, Failed, Pending)
- Status badges with colors
- Clickable Plone links
- Last updated timestamp
- Export to Excel button (from HTML)

**Test Cases:**
- [ ] Add file to tracker after successful import
- [ ] Mark file as failed with error
- [ ] Check if file is imported (by name and hash)
- [ ] Detect new files needing import
- [ ] Detect modified files (hash changed)
- [ ] Generate HTML report with correct formatting
- [ ] Generate CSV report compatible with Excel
- [ ] Calculate accurate statistics

---

### 3.5 Check Import Status Tool (`check_import_status.py`)

**Purpose:** Command-line tool for checking import status of files

**Usage:**
```bash
# Check specific file
python check_import_status.py "WHS_Procedure_Incident_and_Hazard_Reporting.pdf"

# Check all pending files
python check_import_status.py --pending

# Check all failed files
python check_import_status.py --failed

# Check files modified since date
python check_import_status.py --modified-since 2025-10-01

# Generate status report
python check_import_status.py --report

# Check if file has changed on filesystem vs. imported version
python check_import_status.py "WHS_Procedure.pdf" --check-modified
```

**Output Examples:**
```
$ python check_import_status.py "WHS_Procedure_Incident_and_Hazard_Reporting.pdf"

✓ IMPORTED
  Date: 2025-10-06 14:30:00
  Batch: batch_003_all_staff_procedures.json
  Plone: http://whsportaldev.cook.local:8080/whsportal/whs-policies/all-staff-whs-procedures/whs-procedure-incident-and-hazard-reporting-pdf
  Creators: natalieh
  File Hash: abc123def456...
  Status: Up to date (no changes detected)

$ python check_import_status.py --pending

PENDING IMPORT (3 files):
  1. WHS_New_Procedure.pdf
     Location: WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/
     Reason: New file (not in tracker)

  2. Safety_Form_Update.docx
     Location: WHS_Forms_Templates/All-staff_WHS_Forms_Templates/
     Reason: Modified since import (2025-10-05)

  3. Emergency_Plan_Revised.pdf
     Location: WHS_Emergency Management/Empergency_Plan/
     Reason: New file (not in tracker)

To import these files, run:
  python main.py --mode incremental

$ python check_import_status.py --report

========================================
WHS Portal Import Status Report
========================================
Generated: 2025-10-06 15:45:00

Summary:
  Total files tracked: 23
  Successfully imported: 20
  Failed imports: 2
  Pending import: 3

Last import: 2025-10-06 14:40:00

Recent imports (last 5):
  1. WHSTemplate_Toolbox_Agenda_Notes_Attendees.dotx (2025-10-06 14:35:00)
  2. WHS_Procedure_Injury_Management.pdf (2025-10-06 14:33:00)
  3. WHS_Procedure_Incident_and_Hazard_Reporting.pdf (2025-10-06 14:30:00)
  4. Emergency_Procedure_LV_Rescue.pdf (2025-10-06 14:28:00)
  5. Safety_Alert_0001.png (2025-10-06 14:25:00) [FAILED - image format]

Failed imports requiring attention:
  1. Old_WHS_Procedure.doc
     Error: Legacy Office format - skipped for manual handling
  2. Safety_Alert_0001.png
     Error: Image format - skipped for manual handling

Detailed reports available:
  HTML: import_data/imported_files_report.html
  CSV: import_data/imported_files_report.csv
========================================
```

**Test Cases:**
- [ ] Check status of imported file
- [ ] Check status of pending file
- [ ] List all pending files
- [ ] List all failed files
- [ ] Detect file modifications since import
- [ ] Generate summary report

---

### 3.6 JSON Generator Module (`json_generator.py`)

**Purpose:** Create collective.exportimport-compatible JSON, batched by parent folder

**Functions:**
```python
def read_file_to_base64(filepath: str) -> str:
    """Read file and encode as base64"""

def get_file_mimetype(filepath: str) -> str:
    """Detect MIME type from file extension"""

def calculate_json_size_estimate(file_list: list) -> int:
    """Estimate JSON size for a batch (base64 is ~133% of original)"""

def generate_file_item(filepath: str, filename: str, parent_info: dict, metadata: dict,
                       user_mappings: dict, plone_base_url: str) -> dict:
    """
    Generate complete JSON structure for a File content item

    Required fields:
    - @type: "File"
    - id: plone-friendly-id (from sanitized filename)
    - title: human-readable title (from metadata or filename)
    - file: {content-type, data (base64), encoding, filename}
    - parent: {@id, UID}

    Enhanced fields (from AI extraction and AD mapping):
    - description: metadata['summary']
    - subjects: metadata['key_topics']
    - creators: user_mappings['user_ids'] (from authors)
    - contributors: user_mappings['approver_ids'] (from approvers)
    - review_state: 'published'
    - effective: metadata['document_date'] or default date
    - language: {'title': 'English (United Kingdom)', 'token': 'en-gb'}

    Return: Complete JSON dict for one file
    """

def generate_link_item(filename: str, parent_info: dict, target_file_url: str,
                      primary_location: str, plone_base_url: str) -> dict:
    """
    Generate complete JSON structure for a Link content item (for duplicates)

    Used when same file needs to appear in multiple locations.
    Link points to primary file location.

    Required fields:
    - @type: "Link"
    - id: plone-friendly-id (from sanitized filename)
    - title: same as original file title
    - description: informative text about link target
    - remoteUrl: full URL to primary file in Plone
    - parent: {@id, UID}

    Example:
    {
      "@type": "Link",
      "id": "whsprocedure-emergencyresponse-lvrescue-pdf",
      "title": "WHSProcedure-EmergencyResponse-LVRescue.pdf",
      "description": "This procedure is available in Emergency Procedures. Click to view.",
      "remoteUrl": "http://whsportaldev.cook.local:8080/whsportal/emergency-management/emergency-procedures/whsprocedure-emergencyresponse-lvrescue-pdf",
      "parent": {...},
      "review_state": "published"
    }

    Return: Complete JSON dict for one link
    """

def is_duplicate_file(filename: str, duplicate_config: dict) -> tuple:
    """
    Check if file is a known duplicate and return primary location

    Returns: (is_duplicate: bool, primary_location: str, is_primary: bool)
    """

def generate_batch_json(file_items: list, batch_name: str) -> str:
    """
    Wrap file items in array structure expected by collective.exportimport

    Returns: JSON string (formatted, indented)
    """

def write_batch_file(batch_json: str, batch_name: str, output_dir: str) -> str:
    """
    Write batch JSON to file

    Filename format: batch_NNN_<batch_name>.json
    Returns: Full path to written file
    """

def estimate_and_warn_size(batch: dict) -> bool:
    """
    Check if batch size exceeds reasonable limits
    Return True if size OK, False if too large
    """
```

**JSON Structure Template:**
```json
[{
  "@type": "File",
  "id": "whs-procedure-incident-and-hazard-reporting-pdf",
  "title": "WHS Procedure - Incident & Hazard Reporting",
  "description": "[AI-extracted summary: 2-3 sentences about the procedure]",
  "file": {
    "content-type": "application/pdf",
    "data": "[BASE64_ENCODED_CONTENT]",
    "encoding": "base64",
    "filename": "WHS_Procedure_Incident_and_Hazard_Reporting.pdf"
  },
  "parent": {
    "@id": "http://whsportaldev.cook.local:8080/whsportal/whs-policies/all-staff-whs-procedures",
    "UID": "1ad8f065ce7e45cbbd240b573f992573"
  },
  "subjects": ["incident reporting", "hazard reporting", "safety", "compliance"],
  "creators": ["natalieh"],
  "contributors": ["jsmith"],
  "review_state": "published",
  "effective": "2024-09-15T00:00:00+00:00",
  "language": {
    "title": "English (United Kingdom)",
    "token": "en-gb"
  },
  "allow_discussion": false,
  "exclude_from_nav": false
}]
```

**Batching Strategy:**
- One JSON file per parent folder
- Batch naming: `batch_001_emergency_procedures.json`, `batch_002_whs_forms.json`, etc.
- Each batch is independently importable
- Estimate size before writing, warn if >50MB

**Test Cases:**
- [ ] Generate JSON for 1 test file
- [ ] Validate against existing export structure
- [ ] Verify base64 encoding/decoding
- [ ] Test batch file writing
- [ ] Verify JSON is valid and parseable
- [ ] Check parent @id uses correct URL format

---

### 3.7 Main Orchestration Script (`main.py`)

**Purpose:** Coordinate the entire import process

**Workflow:**
```python
def scan_working_directory(base_path: str) -> list:
    """Recursively find all files to process (from sanitized working copy)"""

def load_all_config():
    """Load configuration, path mappings, caches"""

def process_file(filepath: str, filename: str, mappings: dict, ad_lookup: dict,
                 metadata_cache: dict, manual_overrides: dict) -> dict:
    """
    Process single file through full pipeline

    Returns: {
        'file_path': '...',
        'filename': '...',
        'action': 'import' | 'skip' | 'error',
        'reason': '...',
        'plone_id': '...',
        'parent_path': '...',
        'metadata': {...},
        'user_mappings': {...},
        'batch_name': '...',
        'json_item': {...} | None,
        'errors': [...]
    }
    """

def main(mode: str = 'full', **kwargs):
    """
    Main execution flow:

    1. Load configuration
    2. Create output directories
    3. Load AI metadata cache
    4. Load/refresh AD users cache
    5. Build AD user lookup dictionary
    6. Load path mappings
    7. Load import tracker
    8. Scan working directory for files
    9. Initialize manual review report

    10. For each file:
        a. Check if already imported (from tracker)
           - If mode='full': Process all files
           - If mode='incremental': Skip already imported files (unless hash changed)
        b. Check if should process (exclusions, legacy, images)
        c. If skip: Add to manual review report, mark as failed in tracker, continue
        d. Map to parent folder
        e. If no mapping or missing parent: Add to manual review, mark as failed, continue
        f. Get or extract metadata (AI + cache)
        g. Map authors/approvers to AD user IDs
        h. Flag ambiguous or unknown user mappings for manual review
        i. Generate JSON item
        j. Add to appropriate batch (by parent folder)
        k. Log progress

    11. For each batch:
        a. Generate batch JSON file
        b. Estimate size, warn if large
        c. Write to import_batches/ directory

    12. Save updated metadata cache
    13. Save updated AD users cache
    14. Save updated import tracker (mark files as pending import)
    15. Generate HTML and CSV import status reports
    16. Generate summary report
    17. Generate manual review report (consolidated)
    18. Display next steps

    Note: After actual Plone import (Phase 5), run update tracker to mark as imported:
      python main.py --update-tracker --batch batch_001_emergency_procedures.json --status imported
    """
```

**Execution Modes:**
```bash
# Full run with AI extraction (process all files)
python main.py --mode full

# Incremental import (only new/modified files)
python main.py --mode incremental

# Dry run (no file writing, show what would happen)
python main.py --mode dry-run

# Re-extract AI metadata (ignore cache)
python main.py --mode refresh-metadata

# Process single folder for testing
python main.py --mode test --folder "WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures"

# Skip AI extraction (use cached only or skip metadata)
python main.py --mode skip-ai

# Refresh AD users cache from Plone
python main.py --refresh-ad-users

# Generate reports only (no processing)
python main.py --mode report-only

# Update tracker after successful Plone import
python main.py --update-tracker --batch batch_001_emergency_procedures.json --status imported

# Mark all files in batch as imported (after Plone import)
python main.py --mark-batch-imported batch_001_emergency_procedures.json
```

**Logging & Progress:**
- Console output with progress bar (using `tqdm` library)
- Detailed log file with timestamps (`import_log.json`)
- Summary report at end
- Manual review report for flagged items

**Summary Report Template:**
```
========================================
Import JSON Generation Complete
========================================
Total files scanned: 29
Files processed for import: 20
Files skipped:
  - System files excluded: 3 (Thumbs.db)
  - Legacy Office formats: 3
  - Image files: 1
  - Duplicate filenames: 2
  - Missing Plone parent: 0
  - No filesystem mapping: 0

AI Extraction:
  - Documents extracted: 18
  - From cache: 12
  - New extractions: 6
  - Extraction failures: 2

User Mapping Statistics:
  - Authors extracted: 18 names
  - Authors mapped to AD: 15
  - Authors using fallback: 3
  - Approvers extracted: 12 names
  - Approvers mapped to AD: 11
  - Approvers using fallback: 1
  - Ambiguous mappings flagged: 2

Batches Generated: 8
  - batch_001_emergency_procedures.json (3 files, ~2.1 MB)
  - batch_002_whs_forms.json (5 files, ~3.8 MB)
  - batch_003_all_staff_procedures.json (7 files, ~4.5 MB)
  - ... (5 more)

Errors: 2
  - WHS_Legacy_Doc.doc: AI extraction failed (legacy format)
  - Another_File.pdf: Could not read file

Output Files:
  - Batch JSONs: /home/ceo/Development/WHSPortal/import_data/import_batches/
  - Cache: /home/ceo/Development/WHSPortal/import_data/summaries_cache.json
  - AD Cache: /home/ceo/Development/WHSPortal/import_data/ad_users_cache.json
  - Log: /home/ceo/Development/WHSPortal/import_data/import_log.json
  - Manual Review: /home/ceo/Development/WHSPortal/import_data/manual_review_report.md

MANUAL REVIEW REQUIRED:
  Please review: import_data/manual_review_report.md
  Items flagged: 9
    - 2 duplicate filenames
    - 3 legacy Office files
    - 1 image file
    - 2 ambiguous user mappings
    - 1 unknown user name

Next steps:
  1. Review manual_review_report.md with WHS Officer
  2. Resolve flagged items
  3. Take VM snapshot of whsportaldev
  4. Import batches via Plone: http://whsportaldev.cook.local:8080/whsportal/@@import_content
  5. Import batches in order:
     - batch_001_emergency_procedures.json
     - batch_002_whs_forms.json
     - ... (continue with remaining batches)
  6. Verify imported content in Plone UI
========================================
```

**Manual Review Report Template** (`manual_review_report.md`):
```markdown
# WHS Portal Content Import - Manual Review Required

**Generated:** 2025-10-06 14:30:00
**Import Run:** Full import from HDRIVE

---

## Summary

The following items require manual review before or after import:

- **Duplicate Filenames:** 2 files
- **Legacy Office Formats:** 3 files (skipped)
- **Image Files:** 1 file (skipped)
- **Missing Plone Folders:** 0 folders
- **Unmapped Directories:** 0 directories
- **Ambiguous User Mappings:** 2 mappings
- **Unknown Users:** 1 name

---

## 1. Duplicate Filenames

Files with the same name found in multiple locations. Manual review required to determine if these are truly duplicates or different versions.

| Filename | Locations | Recommendation |
|----------|-----------|----------------|
| WHSProcedure-EmergencyResponse-LVRescue.pdf | WHS_Emergency Management/Emergency_Procedures/<br>WHS_Emergency Management/Empergency_Plan/ | Review content, import one or rename |
| WHSProcedure-TrenchCollapseRescueResponse.pdf | WHS_Emergency Management/Emergency_Procedures/<br>WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/ | Review content, import one or rename |

---

## 2. Legacy Office Formats (Skipped from Import)

These files are in legacy Office formats (.doc, .xls) and were not imported. AI extraction may not work on these formats.

| Filename | Location | Action Required |
|----------|----------|-----------------|
| Old_WHS_Procedure.doc | WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/ | Convert to .docx or upload manually |
| Legacy_Form.xls | WHS_Forms_Templates/All-staff_WHS_Forms_Templates/ | Convert to .xlsx or upload manually |
| Old_Template.doc | WHS_Forms_Templates/Divisional_Specific_WHS_Forms_Templates/ | Convert to .docx or upload manually |

---

## 3. Image Files (Skipped from Import)

Image files were not imported automatically. Manual review required to determine appropriate handling.

| Filename | Location | Action Required |
|----------|----------|-----------------|
| Safety Alert #0001.png | Portal_Display/ | Upload manually to appropriate location<br>Consider creating News Item or Alert with embedded image |

---

## 4. Ambiguous User Mappings

Author or approver names that matched multiple AD users. Manual review required to select correct user.

| Extracted Name | File | Possible Matches | Fallback Used |
|----------------|------|------------------|---------------|
| J. Smith | WHS_Procedure_XYZ.pdf | jsmith, johnsmith2, janesmith | admin |
| Johnson | WHSTemplate_ABC.dotx | mjohnson, sjohnson, ajohnson | admin |

**Action Required:** Review documents, determine correct author, update manually in Plone after import or add to MANUAL_USER_MAPPINGS in config.py for re-run.

---

## 5. Unknown Users

Author or approver names that could not be matched to any AD user.

| Extracted Name | File | Action Required |
|----------------|------|-----------------|
| Dr. Sarah Williams | WHS_Plan_Health.pdf | Check if user exists in AD<br>If not, use generic user or leave as-is |

**Action Required:** Verify if these users exist in AD under different names. Add to MANUAL_USER_MAPPINGS if known mapping exists.

---

## 6. Files Processed Successfully

**20 files** were processed and included in import batches. See import_log.json for full details.

---

## Next Steps

1. **Review this report** with WHS Officer
2. **Resolve duplicate files:**
   - Compare content
   - Decide which to import or rename
   - Re-run import for those files if needed
3. **Handle legacy formats:**
   - Convert to modern formats (.docx, .xlsx)
   - Upload manually or re-run import
4. **Handle image files:**
   - Upload manually to Portal_Display or appropriate location
5. **Resolve ambiguous user mappings:**
   - Add to MANUAL_USER_MAPPINGS in config.py
   - Or update creators/contributors in Plone after import
6. **Verify unknown users:**
   - Check AD for correct usernames
   - Add to MANUAL_USER_MAPPINGS
7. **Proceed with import** of generated batch files

---

**Report saved:** /home/ceo/Development/WHSPortal/import_data/manual_review_report.md
**Log file:** /home/ceo/Development/WHSPortal/import_data/import_log.json
```

---

## Phase 4: Testing & Validation

### 4.1 Phase 0 Validation Testing
- [ ] Run `audit_filesystem.py` and review output
- [ ] Verify file counts and categorization
- [ ] Review generated path mappings for accuracy
- [ ] Run `sanitize_filenames.py` and verify filename corrections
- [ ] Run `validate_plone_structure.py` and verify all parent folders exist
- [ ] Run `test_ai_extraction.py` on sample files and review quality

### 4.2 Unit Testing
- [ ] Test path mapping for actual 27 files
- [ ] Test ID generation with sanitized filenames
- [ ] Test base64 encoding/decoding
- [ ] Test AI extraction with 2-3 sample documents
- [ ] Test cache load/save operations
- [ ] Test file categorization logic
- [ ] Test AD user lookup and fuzzy matching
- [ ] Test ambiguous name detection

### 4.3 Integration Testing
- [ ] Process single test folder (e.g., `WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/`)
- [ ] Validate generated batch JSON structure
- [ ] Verify JSON matches collective.exportimport format
- [ ] Take VM snapshot
- [ ] Import test batch via Plone UI (`@@import_content`)
- [ ] Verify imported content in Plone:
  - Correct folder location
  - Metadata populated (description, subjects, creators)
  - File downloadable
  - Proper workflow state (published)
  - Creators/contributors correctly set
- [ ] Restore VM snapshot for next test

### 4.4 Dry Run Testing
- [ ] Run `main.py --mode dry-run` on full working directory
- [ ] Review console output for errors
- [ ] Check path mappings are correct
- [ ] Review manual_review_report.md
- [ ] Verify batch file estimates
- [ ] Check user mappings in log

---

## Phase 5: Full Import Execution

### 5.1 Pre-Import Checklist
- [ ] **VM Snapshot:** Take snapshot of whsportaldev VM
- [ ] **Document snapshot name** for rollback reference
- [ ] Confirm collective.exportimport is installed and working
- [ ] Review and approve path mappings
- [ ] Review manual_review_report.md with WHS Officer
- [ ] Ensure all parent folders exist in Plone (from Phase 0.3 validation)
- [ ] Verify working copy with sanitized filenames exists
- [ ] Test import with 1 batch first (smallest batch)

### 5.2 Execute Full Import

**Step 1: Generate Import JSONs**
```bash
cd /home/ceo/Development/WHSPortal/import_scripts

# Full run with AI extraction
python main.py --mode full

# Review output
cat ../import_data/manual_review_report.md
```

**Step 2: Review Generated Files**
```bash
# List generated batches
ls -lh ../import_data/import_batches/

# Check JSON validity
python -m json.tool ../import_data/import_batches/batch_001_emergency_procedures.json > /dev/null && echo "Valid JSON"
```

**Step 3: Take Pre-Import VM Snapshot**
```bash
# Document this snapshot name for rollback
echo "Snapshot: whsportaldev_pre_import_$(date +%Y%m%d_%H%M%S)"
# [Perform VM snapshot in hypervisor]
```

**Step 4: Import via Plone UI**

For each batch file (in order):

1. Navigate to: `http://whsportaldev.cook.local:8080/whsportal/@@import_content`
2. Select "Upload file from client"
3. Choose batch JSON file (e.g., `batch_001_emergency_procedures.json`)
4. Review preview if available
5. Click "Import"
6. Wait for completion message
7. Check for any error messages
8. Verify files appear in target folder

**Import Order:**
```
batch_001_emergency_procedures.json
batch_002_whs_forms.json
batch_003_all_staff_procedures.json
... (continue with remaining batches)
```

**Step 5: Monitor Import**
- Watch Plone console output for errors
- Check Plone log: `/opt/plone/instance/var/log/instance.log`
- If import fails: Review error, restore VM snapshot, fix issue, retry

**Step 6: Update Import Tracker**

After each successful batch import, update the tracker:
```bash
cd /home/ceo/Development/WHSPortal/import_scripts

# Mark all files in batch as successfully imported
python main.py --mark-batch-imported batch_001_emergency_procedures.json

# This updates imported_files_tracker.json with:
# - status: 'imported'
# - imported_date: current timestamp
# - Plone URLs for each file

# Regenerate status reports
python check_import_status.py --report
```

This ensures:
- Import tracker reflects actual Plone state
- HTML/CSV reports show current status
- Incremental imports will skip these files
- WHS Officer can see what's been imported

### 5.3 Post-Import Verification

**Automated Checks:**
```bash
# TODO: Create verification script
python verify_import.py --batches import_data/import_batches/ --plone-url http://whsportaldev.cook.local:8080/whsportal
```

**Manual Verification Checklist:**
- [ ] Check Plone UI for imported files in each target folder
- [ ] Verify file count matches expected count from batch
- [ ] Spot-check 10-15 files:
  - [ ] File in correct folder location
  - [ ] Title is readable (not just filename)
  - [ ] Description populated (AI-extracted summary)
  - [ ] Subjects/tags present
  - [ ] Creators field shows mapped user (not fallback unless expected)
  - [ ] Contributors field shows approvers (if extracted)
  - [ ] File opens/downloads correctly
  - [ ] Workflow state is "published"
  - [ ] Effective date is set
- [ ] Check for any import errors in Plone error log
- [ ] Verify no duplicate content created (check by ID)
- [ ] Test search functionality - do imported files appear?
- [ ] Test file download from public URL (`https://whsportal.cook.qld.gov.au`)

**If Issues Found:**
1. Document issue in detail
2. Restore VM snapshot
3. Fix issue in import scripts or configuration
4. Re-run import generation
5. Retry import

**If Successful:**
- [ ] Update import tracker for all successfully imported batches
- [ ] Generate HTML/CSV status reports for WHS Officer review
- [ ] Verify import tracker accuracy (spot-check 5-10 files)
- [ ] Share HTML report with WHS Officer
- [ ] Keep VM snapshot for 7 days (safety backup)

---

## Phase 6: Manual Review Items & Cleanup

### 6.1 Resolve Flagged Items

Work through `manual_review_report.md` with WHS Officer:

**Duplicate Filenames:**
1. Review each duplicate (identified in Phase 0.1 audit)
2. Verify files are identical (compare MD5 hashes)
3. **Decision: Import to primary location + create links in secondary locations**
4. Determine primary location based on:
   - Most logical/intuitive location for users
   - Where users would expect to find the document
   - Folder context and purpose
5. Document primary location decision in configuration
6. Import script will:
   - Import File content type to primary location
   - Generate Link content type for each secondary location
   - Link points to primary file's Plone URL

**Legacy Office Formats:**
1. Identify critical vs. optional documents
2. Convert critical documents to modern formats (`.docx`, `.xlsx`)
3. Add to working copy
4. Re-run import for converted files
5. Or: Upload manually via Plone UI

**Image Files:**
1. Review purpose of each image
2. Create appropriate content (News Item, Page, or Alert)
3. Upload image manually and embed
4. Or: Add image to existing content

**Ambiguous User Mappings:**
1. For each ambiguous mapping, determine correct user
2. Update `MANUAL_USER_MAPPINGS` in `config.py`
3. Re-run import for affected files with `--mode refresh-users`
4. Or: Update creators/contributors directly in Plone UI

**Unknown Users:**
1. Check if user exists in AD under different name
2. If found: Add to `MANUAL_USER_MAPPINGS`
3. If not found: Use fallback or create placeholder user
4. Update affected content in Plone

### 6.2 Cleanup Tasks
- [ ] Remove working copy directory (or archive)
- [ ] Archive import logs and reports
- [ ] Document final file count and import statistics
- [ ] Update path mappings if changes were made
- [ ] Document any manual user mappings added for future imports

---

## Phase 7: Ongoing Maintenance & Automation (Future)

### 7.1 Incremental Update Strategy

For future imports when new files are added to H: drive:

**Incremental Import Workflow:**

1. **Check Import Status**
```bash
# Check what files are pending import
cd /home/ceo/Development/WHSPortal/import_scripts
python check_import_status.py --pending

# Output shows:
# - New files (not in tracker)
# - Modified files (hash changed since import)
# - Previously failed imports
```

2. **Run Incremental Import**
```bash
# Process only new/modified files
python main.py --mode incremental

# This will:
# - Load import tracker
# - Scan H: drive
# - Compare with tracker using file hashes
# - Generate batches for only new/changed files
# - Skip files already imported (unless hash changed)
```

3. **Import New Batches to Plone**
```bash
# Follow same import process as Phase 5.2
# Navigate to: http://whsportaldev.cook.local:8080/whsportal/@@import_content
# Upload incremental batch files
```

4. **Update Tracker**
```bash
# After successful Plone import
python main.py --mark-batch-imported batch_incremental_001.json

# Generate updated reports
python check_import_status.py --report
```

**Option A: Manual Trigger (Recommended)**
```bash
# When WHS Officer notifies of new files:
cd /home/ceo/Development/WHSPortal/import_scripts
python check_import_status.py --pending  # Review what's new
python main.py --mode incremental        # Generate import batches
# ... then import via Plone UI
```

**Option B: Scheduled Automation (Future)**
```bash
# Cron job (weekly on Sundays at 2 AM)
0 2 * * 0 cd /home/ceo/Development/WHSPortal/import_scripts && \
  python main.py --mode incremental --auto && \
  python check_import_status.py --report --email whsofficer@cook.qld.gov.au
```

**Incremental Logic (Already Implemented in import_tracker.py):**
```python
def get_files_needing_import(filesystem_base: str, tracker: dict, path_mappings: dict) -> list:
    """
    Scan filesystem and return files that need import:

    1. New files (not in tracker)
       - Filename doesn't exist in tracker

    2. Modified files (hash changed since import)
       - Filename in tracker but file_hash different
       - Indicates file was updated on H: drive

    3. Previously failed imports (status='failed')
       - Files that failed on previous run
       - Allows retry after fixing issues

    Returns: List of (filepath, reason) tuples
    """
```

**Benefits of Import Tracker for Incremental Updates:**
- ✅ No need to modify H: drive files
- ✅ Automatic detection of new files
- ✅ Automatic detection of file changes (via hash comparison)
- ✅ Retry failed imports easily
- ✅ Clear visibility of what's pending
- ✅ Supports manual and automated workflows

### 7.2 Monitoring & Alerts
- [ ] Email notifications on errors
- [ ] Log rotation for import logs
- [ ] Dashboard for import statistics (optional)
- [ ] Automated backup before scheduled imports

### 7.3 Viewing Import Status Reports

**For WHS Officer (Non-Technical):**

1. **HTML Report (Recommended)**
```bash
# Open in browser
firefox /home/ceo/Development/WHSPortal/import_data/imported_files_report.html

# Or on Windows, share via network:
\\server\share\WHSPortal\import_data\imported_files_report.html
```

Features:
- Search bar (find any file instantly)
- Sort by any column (filename, date, status)
- Filter by status (Imported, Failed, Pending)
- Clickable Plone links
- Color-coded status badges
- Summary statistics at top

2. **CSV Report (Excel)**
```bash
# Open in Excel
libreoffice /home/ceo/Development/WHSPortal/import_data/imported_files_report.csv

# Or on Windows:
\\server\share\WHSPortal\import_data\imported_files_report.csv
```

Can be used for:
- Custom filtering/sorting in Excel
- Pivot tables for analysis
- Sharing with management

3. **Command-Line (For Admins)**
```bash
# Quick status check
python check_import_status.py --report

# Check specific file
python check_import_status.py "WHS_Procedure_Incident_and_Hazard_Reporting.pdf"

# List pending files
python check_import_status.py --pending
```

### 7.4 Maintenance Documentation
- [ ] Document how to add new files to H: drive structure
- [ ] Document how to manually trigger import
- [ ] Document how to view import status reports (HTML/CSV)
- [ ] Document how to check individual file status
- [ ] Document troubleshooting common issues
- [ ] Document how to update path mappings
- [ ] Document how to add manual user mappings

---

## Phase 8: Documentation & Handover

### 8.1 User Documentation (for WHS Officer)
Create guide covering:
- How to add new files to H: drive folders
- Naming conventions for files
- What happens when files are added (if automated)
- How to manually trigger import (if manual)
- How to verify imported content in Plone
- Troubleshooting common issues
- Who to contact for technical issues

### 8.2 Technical Documentation
- Script architecture diagram
- Configuration options reference
- How to extend AI extraction prompts
- How to update path mappings
- How to add manual user overrides
- collective.exportimport notes and limitations
- LDAP/AD integration details
- Batch import process

### 8.3 Training Session
- Demonstrate the workflow end-to-end
- Show how to review imported content
- Explain AI-extracted metadata
- Show how to handle manual review items
- Explain VM snapshot rollback process
- Q&A session

---

## Risk Management

### Potential Issues & Mitigations

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| Parent folder doesn't exist in Plone | Import fails | **Phase 0.3 validation, flag in report, don't import** | ✓ Addressed |
| File already exists in Plone | Duplicate content | Check before import, or configure collective.exportimport to skip/update | Testing needed |
| AI extraction fails | Missing metadata | Graceful fallback to filename-based metadata, log error | ✓ Addressed |
| Base64 encoding creates huge JSON | Memory issues | **Batch by parent folder (implemented)** | ✓ Addressed |
| Plone import timeout | Partial import | **Smaller batches, monitor size** | ✓ Addressed |
| File permissions on filesystem | Cannot read files | Run script as appropriate user, check permissions | Testing needed |
| Cache corruption | Re-extract all metadata | Validate cache on load, backup cache regularly | Implemented |
| Path mapping incorrect | Wrong folder location | **Phase 0 validation, thorough testing** | ✓ Addressed |
| Duplicate filenames | Collision errors | **Import to primary + Link in secondary locations** | ✓ Addressed |
| Legacy Office format | AI extraction fails | **Skip and flag in report** | ✓ Addressed |
| Ambiguous user names | Wrong creator attribution | **Confidence scoring, flag for manual review** | ✓ Addressed |
| AD user not found | Fallback to admin | **Log all mappings, manual review report** | ✓ Addressed |
| Special characters in filenames | Import errors | **Phase 0.2 filename sanitization** | ✓ Addressed |
| Import causes Plone corruption | Data loss | **VM snapshots before import, test restore** | ✓ Addressed |

---

## Dependencies

### Python Libraries Required

```bash
# Core dependencies (may already be available via Plone environment)
pip install anthropic                # If using Anthropic API directly
pip install requests                 # For Plone REST API calls
pip install python-magic             # MIME type detection (or use built-in mimetypes)
pip install tqdm                     # Progress bars

# Optional dependencies
pip install python-Levenshtein       # For advanced fuzzy name matching
pip install watchdog                 # For future file system watching automation
```

### Plone Add-ons (Already Installed)
```
collective.exportimport     # Content export/import
pas.plugins.ldap            # Active Directory integration
cook.whs.barceloneta        # Custom WHS theme with LDAP utilities
csc.teams                   # Teams management with AD integration
```

### System Requirements
- Python 3.12+ (Plone 6.1 requirement)
- Access to Plone instance: `http://whsportaldev.cook.local:8080/whsportal`
- Read access to: `/home/ceo/HDRIVE/WHS/0.1_WHSMS_Portal_Approved`
- Write access to: `/home/ceo/Development/WHSPortal/import_data/`
- Disk space: ~500MB for working copy + JSON + cache files
- VM hypervisor access for snapshot creation/restoration

---

## Success Criteria

### Phase Completion Metrics
- [ ] All ~20 importable files successfully imported (excluding duplicates, legacy, images)
- [ ] All files in correct Plone folders (verified)
- [ ] AI-extracted descriptions present on 85%+ of files
- [ ] No duplicate content created
- [ ] All files downloadable and viewable
- [ ] Creators/contributors correctly mapped for 80%+ of files
- [ ] Manual review report generated with all flagged items
- [ ] Import process documented
- [ ] WHS Officer trained on process

### Long-term Success
- [ ] Incremental import process established (manual or automated)
- [ ] WHS Officer can add new files to H: drive and trigger import
- [ ] Metadata quality meets WHS Officer requirements
- [ ] System maintainable by other developers
- [ ] VM snapshot rollback tested and documented

---

## Timeline Estimate

| Phase | Estimated Time | Dependencies |
|-------|----------------|--------------|
| Phase 0: Pre-Implementation Validation | 4-6 hours | Python dev, filesystem access |
| Phase 1: Setup & Validation | 2-3 hours | Plone export, AD access |
| Phase 2: Path Mapping & Config | 2-3 hours | Phase 0 complete, WHS Officer review |
| Phase 3: Core Development | 8-10 hours | Python skills, API knowledge |
| Phase 4: Testing | 4-5 hours | Test environment, VM snapshots |
| Phase 5: Full Import | 2-3 hours | Plone backup, testing complete |
| Phase 6: Manual Review & Cleanup | 2-4 hours | WHS Officer availability |
| Phase 7: Automation (Optional) | 3-4 hours | Can defer to future |
| Phase 8: Documentation | 2-3 hours | Import successful |
| **Total** | **29-41 hours** | Over 5-7 days |

**Note:** Timeline increased from original 17-25 hours to account for:
- Phase 0 validation and audit scripts
- Filename sanitization
- Enhanced user mapping with confidence scoring
- Batching by parent folder
- Manual review report generation
- More thorough testing with VM snapshots

---

## Next Steps

1. **Review this updated plan** with stakeholders
2. **Begin Phase 0:** Run audit scripts and generate reports
3. **Review Phase 0 outputs** with WHS Officer:
   - Path mappings accuracy
   - Duplicate file decisions
   - Legacy format handling approach
4. **Approve** to proceed with Phase 1-3 development
5. **Schedule** testing window with Plone instance and VM access
6. **Begin development** starting with Phase 0 scripts

---

## Questions to Resolve Before Starting

1. ✅ **Exact Plone URL:** Confirmed as `http://whsportaldev.cook.local:8080/whsportal/`
2. ✅ **Folder creation:** Don't attempt programmatic creation - flag in report for manual creation
3. ✅ **Duplicate handling:** Import to primary location + create Link content in secondary locations (Emergency Procedures as primary)
4. ✅ **Legacy formats:** Skip and flag in report - no AI extraction attempt
5. ✅ **Image import:** Skip and flag in report for manual handling
6. ✅ **Filename special characters:** Sanitize in Phase 0.2 before processing
7. ✅ **Batching:** Batch by parent folder (one JSON per folder)
8. ✅ **Rollback strategy:** VM snapshots before each import attempt
9. ✅ **Naming collision:** Resolved - conflicting file removed from H: drive
10. ✅ **WHS_Community directory:** Excluded - handled by csc.teams addon for contacts
11. [ ] **Plone authentication:** Credentials for REST API calls (if needed)
12. [ ] **Testing window:** When can we safely test imports on whsportaldev?
13. [ ] **Backup responsibility:** Confirm who performs VM snapshots
14. [ ] **AD user query method:** REST API or Python script approach?
15. [ ] **User mapping fallback:** Use "admin" or "whsofficer" as default creator?
16. [ ] **Effective date:** Use extracted document date or uniform default?
17. [ ] **File updates:** If file changes on filesystem in future, update Plone version?

---

## Appendix A: Example Cache File Structure

### AI Metadata Cache (summaries_cache.json)
```json
{
  "WHS_Procedure_Incident_and_Hazard_Reporting.pdf": {
    "summary": "This procedure details the responsibilities and process for incident and hazard reporting at Cook Shire Council...",
    "key_topics": ["incident reporting", "hazard reporting", "WHS compliance", "investigation procedures"],
    "document_type": "procedure",
    "target_audience": "all-staff",
    "authors": ["Natalie Henderson", "Sarah Johnson"],
    "approvers": ["John Smith"],
    "document_date": "2024-09-15",
    "extracted_date": "2025-10-06",
    "file_hash": "abc123def456...",
    "extraction_success": true
  },
  "WHSTemplate_Toolbox_Agenda_Notes_Attendees.dotx": {
    "summary": "Template for recording toolbox meeting agendas, notes, and attendee lists...",
    "key_topics": ["toolbox talks", "meeting template", "attendance tracking"],
    "document_type": "template",
    "target_audience": "managers",
    "authors": ["Natalie Henderson"],
    "approvers": [],
    "document_date": null,
    "extracted_date": "2025-10-06",
    "file_hash": "def789ghi012...",
    "extraction_success": true
  }
}
```

### AD Users Cache (ad_users_cache.json)
```json
{
  "cache_date": "2025-10-06T14:30:00",
  "cache_expires": "2025-10-07T14:30:00",
  "user_count": 127,
  "lookup": {
    "natalie henderson": "natalieh",
    "henderson": "natalieh",
    "natalieh": "natalieh",
    "n henderson": "natalieh",
    "john smith": ["jsmith", "johnsmith2"],
    "smith": ["jsmith", "johnsmith2", "asmith"],
    "jsmith": "jsmith",
    "sarah johnson": "sjohnson",
    "johnson": ["sjohnson", "mjohnson"],
    "sjohnson": "sjohnson"
  },
  "users": [
    {
      "id": "natalieh",
      "fullname": "Natalie Henderson",
      "email": "natalie.henderson@cook.qld.gov.au",
      "department": "People and Performance",
      "job_title": "WHS Officer"
    },
    {
      "id": "jsmith",
      "fullname": "John Smith",
      "email": "john.smith@cook.qld.gov.au",
      "department": "Operations",
      "job_title": "Manager"
    },
    {
      "id": "sjohnson",
      "fullname": "Sarah Johnson",
      "email": "sarah.johnson@cook.qld.gov.au",
      "department": "People and Performance",
      "job_title": "HR Coordinator"
    }
  ]
}
```

---

## Appendix B: Example Import Log Entry

```json
{
  "timestamp": "2025-10-06T18:30:15",
  "file": "/home/ceo/Development/WHSPortal/import_working_copy/WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/WHS_Procedure_Incident_and_Hazard_Reporting.pdf",
  "filename": "WHS_Procedure_Incident_and_Hazard_Reporting.pdf",
  "action": "processed",
  "plone_id": "whs-procedure-incident-and-hazard-reporting-pdf",
  "plone_parent": "whs-policies/all-staff-whs-procedures",
  "parent_uid": "1ad8f065ce7e45cbbd240b573f992573",
  "batch_name": "all_staff_whs_procedures",
  "metadata_source": "ai_extracted",
  "extraction_success": true,
  "extracted_authors": ["Natalie Henderson", "Sarah Johnson"],
  "mapped_creators": [
    {"name": "Natalie Henderson", "user_id": "natalieh", "confidence": "exact"},
    {"name": "Sarah Johnson", "user_id": "sjohnson", "confidence": "high"}
  ],
  "extracted_approvers": ["John Smith"],
  "mapped_contributors": [
    {"name": "John Smith", "user_id": "jsmith", "confidence": "exact"}
  ],
  "unmapped_names": [],
  "ambiguous_mappings": [],
  "file_size_bytes": 363725,
  "json_size_estimate_bytes": 485000,
  "status": "success"
}
```

---

## Appendix C: Filesystem Audit Report Example

```markdown
# WHS Portal Filesystem Audit Report

**Generated:** 2025-10-06 14:00:00
**Base Path:** /home/ceo/HDRIVE/WHS/0.1_WHSMS_Portal_Approved
**Export Reference:** /home/ceo/Development/WHSPortal/Content/whsportal.json

---

## Summary

| Category | Count | Total Size |
|----------|-------|------------|
| **Total Files** | 27 | 8.0 MB |
| Importable Files | 20 | 7.2 MB |
| Legacy Office Formats | 3 | 450 KB |
| Image Files | 1 | 180 KB |
| System Files (Excluded) | 3 | 12 KB |
| Duplicate Filenames | 2 files, 4 instances | 620 KB |

---

## File Type Breakdown

| Extension | Count | Total Size |
|-----------|-------|------------|
| .docx/.dotx | 14 | 3.8 MB |
| .pdf | 7 | 3.2 MB |
| .doc (legacy) | 3 | 450 KB |
| .xlsx/.xltm | 1 | 280 KB |
| .potx | 1 | 210 KB |
| .png | 1 | 180 KB |

---

## Importable Files by Target Folder

### Emergency Procedures (3 files, 1.2 MB)
- WHSProcedure-EmergencyResponse-LVRescue.pdf
- WHSProcedure-TrenchCollapseRescueResponse.pdf
- WHS_Procedure_Incident_and_Hazard_Reporting.pdf

**Plone Parent:** emergency-management/emergency-procedures (UID: 40d53ce4979347bbaf53540f4a573ba2)
**Status:** ✓ Folder exists in Plone

### All-Staff WHS Forms (5 files, 2.1 MB)
- WHSTemplate_Toolbox_Agenda_Notes_Attendees.dotx
- WHS_Template_Toolbox_Training_Presentation_Quiz.dotx
- ... (3 more)

**Plone Parent:** whs-forms/all-staff-whs-forms-templates (UID: ca51c0d418bb4e82845339179357883b)
**Status:** ✓ Folder exists in Plone

... (more folders)

---

## Duplicate Filenames

### WHSProcedure-EmergencyResponse-LVRescue.pdf
- **Location 1:** WHS_Emergency Management/Emergency_Procedures/
- **Location 2:** WHS_Emergency Management/Empergency_Plan/
- **Action Required:** Manual review to determine if same file or different versions

### WHSProcedure-TrenchCollapseRescueResponse.pdf
- **Location 1:** WHS_Emergency Management/Emergency_Procedures/
- **Location 2:** WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/
- **Action Required:** Manual review to determine if same file or different versions

---

## Legacy Office Formats (Skipped)

| File | Location | Size |
|------|----------|------|
| Old_WHS_Procedure.doc | WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/ | 180 KB |
| Legacy_Form.xls | WHS_Forms_Templates/All-staff_WHS_Forms_Templates/ | 150 KB |
| Old_Template.doc | WHS_Forms_Templates/Divisional_Specific_WHS_Forms_Templates/ | 120 KB |

**Recommendation:** Convert to modern formats (.docx, .xlsx) for AI extraction and import.

---

## Image Files (Skipped)

| File | Location | Size |
|------|----------|------|
| Safety Alert #0001.png | Portal_Display/ | 180 KB |

**Recommendation:** Upload manually to appropriate location in Plone. Consider creating News Item or Alert content with embedded image.

---

## Files with Special Characters

| Original Filename | Issue | Sanitized Filename |
|-------------------|-------|-------------------|
| Safety Alert #0001.png | Hash symbol | Safety_Alert_0001.png |
| WHSTemplate _Letter_of_Authority_Return-to-Work_Coordination.dotx | Leading space after underscore | WHSTemplate_Letter_of_Authority_Return-to-Work_Coordination.dotx |

**Action:** Run sanitize_filenames.py to create working copy with fixed names.

---

## Path Mappings Generated

Total mappings: 8 folders

| Filesystem Directory | Plone Path | UID | Status |
|---------------------|------------|-----|--------|
| WHS_Emergency Management/Emergency_Procedures/ | emergency-management/emergency-procedures | 40d53ce49793... | ✓ Exists |
| WHS_Forms_Templates/All-staff_WHS_Forms_Templates/ | whs-forms/all-staff-whs-forms-templates | ca51c0d418bb... | ✓ Exists |
| WHS_Plans_Policy_Procedures/All-staff_WHS_Procedures/ | whs-policies/all-staff-whs-procedures | 1ad8f065ce7e... | ✓ Exists |
| ... | ... | ... | ... |

**Status:** All mapped folders exist in Plone ✓

---

## Estimated Batch Sizes

| Batch | Files | Original Size | Estimated JSON Size |
|-------|-------|---------------|---------------------|
| batch_001_emergency_procedures.json | 3 | 1.2 MB | ~1.6 MB |
| batch_002_whs_forms.json | 5 | 2.1 MB | ~2.8 MB |
| batch_003_all_staff_procedures.json | 7 | 3.5 MB | ~4.7 MB |
| ... | ... | ... | ... |

**All batches within size limits** (<50MB) ✓

---

## Next Steps

1. ✓ Review this audit report
2. Run `sanitize_filenames.py` to create working copy
3. Resolve duplicate filename issues
4. Convert legacy Office formats (optional)
5. Proceed to Phase 3: Core script development

---

**Generated by:** audit_filesystem.py
**Output files:**
- JSON data: import_data/filesystem_audit_report.json
- Path mappings: import_data/path_mappings.json
```

---

**Document Version:** 3.2
**Created:** 2025-10-01
**Last Updated:** 2025-10-06
**Author:** Claude (AI Assistant)
**Review Status:** Updated with duplicate file handling strategy - Phase 0 complete

**Changelog:**
- **v3.2 (2025-10-06 - Post Phase 0 Manual Review):**
  - **Added duplicate filename handling strategy: Import + Link**
  - Added Section 2.2.1: Duplicate Filename Handling Strategy
  - Import file to primary location, create Link content in secondary locations
  - Added DUPLICATE_PRIMARY_LOCATIONS configuration mapping
  - Added generate_link_item() function to json_generator.py
  - Updated manual review workflow for duplicates
  - Phase 0 manual review completed:
    - ✅ Naming collision resolved (file removed from H: drive)
    - ✅ WHS_Community directory excluded (handled by csc.teams addon)
    - ✅ Duplicate file strategy defined (Emergency Procedures as primary)
  - Ready to proceed with Phase 1

- **v3.1 (2025-10-06):**
  - **Added comprehensive import tracking system (H: drive unchanged)**
  - Added import_tracker.py module for tracking imported files
  - Added check_import_status.py CLI tool for status checking
  - Added HTML and CSV report generation for WHS Officer
  - Integrated import tracking into main.py workflow
  - Added support for incremental imports (detects new/modified files via hash comparison)
  - Added tracker update commands for post-import workflow
  - Added Section 7.3: Viewing Import Status Reports
  - Updated Phase 5.2 to include tracker update steps
  - Enhanced Phase 7.1 with detailed incremental import workflow
  - Added imported_files_tracker.json to directory structure
  - Added import status report files (HTML/CSV) to directory structure
  - Updated configuration with import tracker file paths

- **v3.0 (2025-10-06):**
  - Added Phase 0: Pre-Implementation Validation (filesystem audit, filename sanitization, Plone structure validation, AI extraction testing)
  - Changed approach: Flag issues in reports instead of auto-creating folders or attempting problematic imports
  - Implemented batching by parent folder (one JSON per folder)
  - Added filename sanitization script and working copy approach
  - Enhanced user mapping with confidence scoring and ambiguous match detection
  - Added comprehensive manual review report generation
  - Updated configuration with batching settings
  - Added VM snapshot rollback strategy
  - Enhanced risk management with addressed items
  - Expanded timeline to 29-41 hours (more realistic)
  - Added Appendix C: Filesystem Audit Report Example
  - Confirmed correct Plone URL format
  - Added detailed manual review report template
  - Improved error handling and reporting throughout

- **v2.0 (2025-10-03):**
  - Added Active Directory integration via pas.plugins.ldap
  - Added ad_user_mapper.py module for mapping authors/approvers to AD user IDs
  - Updated configuration for nginx HTTPS frontend
  - Enhanced AI extraction to include authors, approvers, and document dates
  - Added AD users cache for efficient user lookups
  - Updated JSON structure to use mapped user IDs for creators/contributors

- **v1.0 (2025-10-01):**
  - Initial implementation plan
  - Basic AI metadata extraction
  - collective.exportimport approach
  - Path mapping and file processing
