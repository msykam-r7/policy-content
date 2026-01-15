"""
Global variables for CIS Compliance Testing Framework
Environment: Performance Testing
"""

# Environment Configuration
ENVIRONMENT = "performance"
DEBUG_MODE = False
LOG_LEVEL = "WARN"

# Nexpose/Rapid7 Configuration
NEXPOSE_HOST = "perf-nexpose.rapid7.local"
NEXPOSE_PORT = "3780"
NEXPOSE_USERNAME = "perf_admin"
NEXPOSE_PASSWORD = "perf_password"
NEXPOSE_SSL_VERIFY = True

# Default Timeouts (in seconds) - Extended for performance testing
DEFAULT_TIMEOUT = 300
SCAN_TIMEOUT = 21600  # 6 hours
NETWORK_TIMEOUT = 300
LOGIN_TIMEOUT = 600

# CIS Benchmark Configuration
CIS_POLICY_DIR = "data/policies"
CIS_TEMPLATE_DIR = "data/templates"
VALIDATION_RULES_DIR = "testdata/validation_rules"

# Test Data Configuration
VM_CONFIG_FILE = "testdata/vm_config.json"
PAYLOADS_DIR = "payloads"

# Results Configuration
RESULTS_DIR = "results/performance"
REPORTS_DIR = "results/performance/reports"
LOGS_DIR = "results/performance/logs"
SCREENSHOTS_DIR = "results/performance/screenshots"
METRICS_DIR = "results/performance/metrics"

# Default Test Tags
DEFAULT_INCLUDE_TAGS = ["performance", "load", "stress"]
DEFAULT_EXCLUDE_TAGS = ["manual", "smoke", "regression"]

# Cleanup Configuration
SKIP_CLEANUP = True
AUTO_DELETE_RESOURCES = False

# Retry Configuration
MAX_RETRIES = 1
RETRY_INTERVAL = 30

# Browser Configuration
BROWSER = "chrome"
HEADLESS = True
BROWSER_TIMEOUT = 300

# Parallel Execution Configuration
PARALLEL_WORKERS = 16
PABOT_OPTIONS = ["--verbose", "--outputdir", "results/performance"]

# Performance Testing Specific Variables
PERFORMANCE_MONITORING = True
COLLECT_METRICS = True
BASELINE_COMPARISON = True
METRIC_COLLECTION_INTERVAL = 5  # seconds
MAX_LOAD_USERS = 100
RAMP_UP_TIME = 60  # seconds
