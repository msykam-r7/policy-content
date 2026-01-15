"""
Global variables for CIS Compliance Testing Framework
Environment: Production US Region
"""
import os
from config.variables.credentials import NEXPOSE_USERNAME, NEXPOSE_PASSWORD, NEXPOSE_PORT, NEXPOSE_SSL_VERIFY

# Environment Configuration
ENVIRONMENT = "production-us"
REGION = "us-east-1"
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
RESULTS_DIR = "results/prod-us"
REPORTS_DIR = "results/prod-us/reports"
LOGS_DIR = "results/prod-us/logs"
SCREENSHOTS_DIR = "results/prod-us/screenshots"

# Default Test Tags
DEFAULT_INCLUDE_TAGS = ["smoke", "critical", "us-region"]
DEFAULT_EXCLUDE_TAGS = ["manual", "debug", "performance", "eu-only"]

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
PABOT_OPTIONS = ["--verbose", "--outputdir", "results/prod-us", "--critical", "critical"]

# Production US Region Specific Variables
PRODUCTION_MONITORING = True
ALERTS_ENABLED = True
HIGH_SECURITY_MODE = True
REGION_SPECIFIC = "us"
