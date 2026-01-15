"""
Global variables for CIS Compliance Testing Framework
Environment: Local Development
"""
import os
from config.variables.credentials import NEXPOSE_USERNAME, NEXPOSE_PASSWORD, NEXPOSE_PORT, NEXPOSE_SSL_VERIFY

# Environment Configuration
ENVIRONMENT = "local"
DEBUG_MODE = True
LOG_LEVEL = "DEBUG"

# Nexpose Host (environment-specific, credentials imported from shared config)
NEXPOSE_HOST = os.getenv("NEXPOSE_HOST", "127.0.0.1")

# Default Timeouts (in seconds)
DEFAULT_TIMEOUT = 30
SCAN_TIMEOUT = 3600
NETWORK_TIMEOUT = 60
LOGIN_TIMEOUT = 120

# CIS Benchmark Configuration
CIS_POLICY_DIR = "data/policies"
CIS_TEMPLATE_DIR = "data/templates"
VALIDATION_RULES_DIR = "testdata/validation_rules"

# Test Data Configuration
VM_CONFIG_FILE = "testdata/vm_config.json"
PAYLOADS_DIR = "payloads"

# Results Configuration
RESULTS_DIR = "results/local"
REPORTS_DIR = "results/local/reports"
LOGS_DIR = "results/local/logs"
SCREENSHOTS_DIR = "results/local/screenshots"

# Default Test Tags
DEFAULT_INCLUDE_TAGS = ["smoke", "regression"]
DEFAULT_EXCLUDE_TAGS = ["manual", "slow"]

# Cleanup Configuration
SKIP_CLEANUP = True
AUTO_DELETE_RESOURCES = False

# Retry Configuration
MAX_RETRIES = 3
RETRY_INTERVAL = 5

# Browser Configuration (for future web testing)
BROWSER = "chrome"
HEADLESS = True
BROWSER_TIMEOUT = 30

# Parallel Execution Configuration
PARALLEL_WORKERS = 2
PABOT_OPTIONS = ["--verbose"]

# Custom Variables for Development
CUSTOM_VAR_1 = "development_value"
CUSTOM_VAR_2 = "debug_enabled"