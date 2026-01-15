"""
Global variables for CIS Compliance Testing Framework
Environment: Staging
"""
import os
from config.variables.credentials import NEXPOSE_USERNAME, NEXPOSE_PASSWORD, NEXPOSE_PORT, NEXPOSE_SSL_VERIFY

# Environment Configuration
ENVIRONMENT = "staging"
DEBUG_MODE = False
LOG_LEVEL = "INFO"

# Nexpose Host (environment-specific, credentials imported from shared config)
NEXPOSE_HOST = os.getenv("NEXPOSE_HOST", "")

# Default Timeouts (in seconds)
DEFAULT_TIMEOUT = 60
SCAN_TIMEOUT = 7200
NETWORK_TIMEOUT = 120
LOGIN_TIMEOUT = 180

# CIS Benchmark Configuration
CIS_POLICY_DIR = "data/policies"
CIS_TEMPLATE_DIR = "data/templates"
VALIDATION_RULES_DIR = "testdata/validation_rules"

# Test Data Configuration
VM_CONFIG_FILE = "testdata/vm_config.json"
PAYLOADS_DIR = "payloads"

# Results Configuration
RESULTS_DIR = "results/staging"
REPORTS_DIR = "results/staging/reports"
LOGS_DIR = "results/staging/logs"
SCREENSHOTS_DIR = "results/staging/screenshots"

# Default Test Tags
DEFAULT_INCLUDE_TAGS = ["smoke", "regression"]
DEFAULT_EXCLUDE_TAGS = ["manual", "performance"]

# Cleanup Configuration
SKIP_CLEANUP = False
AUTO_DELETE_RESOURCES = True

# Retry Configuration
MAX_RETRIES = 5
RETRY_INTERVAL = 10

# Browser Configuration
BROWSER = "chrome"
HEADLESS = True
BROWSER_TIMEOUT = 60

# Parallel Execution Configuration
PARALLEL_WORKERS = 4
PABOT_OPTIONS = ["--verbose", "--outputdir", "results/staging"]

# Environment Specific Variables
STAGING_SPECIFIC_VAR = "staging_enabled"
MONITORING_ENABLED = True