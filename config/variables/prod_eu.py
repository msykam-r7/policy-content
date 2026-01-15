"""
Global variables for CIS Compliance Testing Framework
Environment: Production EU Region
"""
import os
from config.variables.credentials import NEXPOSE_USERNAME, NEXPOSE_PASSWORD, NEXPOSE_PORT, NEXPOSE_SSL_VERIFY

# Environment Configuration
ENVIRONMENT = "production-eu"
REGION = "eu-west-1"
DEBUG_MODE = False
LOG_LEVEL = "INFO"

# Nexpose Host (environment-specific, credentials imported from shared config)
NEXPOSE_HOST = os.getenv("NEXPOSE_HOST", "")

# Default Timeouts (in seconds)
DEFAULT_TIMEOUT = 120
SCAN_TIMEOUT = 10800
NETWORK_TIMEOUT = 180
LOGIN_TIMEOUT = 300

# CIS Benchmark Configuration
CIS_POLICY_DIR = "data/policies"
CIS_TEMPLATE_DIR = "data/templates"
VALIDATION_RULES_DIR = "testdata/validation_rules"

# Test Data Configuration
VM_CONFIG_FILE = "testdata/vm_config.json"
PAYLOADS_DIR = "payloads"

# Results Configuration
RESULTS_DIR = "results/prod-eu"
REPORTS_DIR = "results/prod-eu/reports"
LOGS_DIR = "results/prod-eu/logs"
SCREENSHOTS_DIR = "results/prod-eu/screenshots"

# Default Test Tags
DEFAULT_INCLUDE_TAGS = ["smoke", "critical", "eu-region"]
DEFAULT_EXCLUDE_TAGS = ["manual", "debug", "performance", "us-only"]

# Cleanup Configuration
SKIP_CLEANUP = False
AUTO_DELETE_RESOURCES = True

# Retry Configuration
MAX_RETRIES = 3
RETRY_INTERVAL = 15

# Browser Configuration
BROWSER = "chrome"
HEADLESS = True
BROWSER_TIMEOUT = 120

# Parallel Execution Configuration
PARALLEL_WORKERS = 8
PABOT_OPTIONS = ["--verbose", "--outputdir", "results/prod-eu", "--critical", "critical"]

# Production EU Region Specific Variables
PRODUCTION_MONITORING = True
ALERTS_ENABLED = True
HIGH_SECURITY_MODE = True
REGION_SPECIFIC = "eu"
GDPR_COMPLIANCE = True
