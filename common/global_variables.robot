*** Settings ***
Documentation     Global Variables for CIS Compliance Testing Framework
...               This file contains all global variables that are shared across test suites.
...               Environment-specific variables are loaded from config/variables/<env>.py

*** Variables ***
# ============================================================================
# FRAMEWORK METADATA
# ============================================================================
${FRAMEWORK_NAME}               CIS Compliance Testing Framework
${FRAMEWORK_VERSION}            2.0.0
${FRAMEWORK_AUTHOR}             Rapid7 Quality Engineering Team
${FRAMEWORK_DESCRIPTION}        Automated CIS and DISA benchmark compliance testing framework

# ============================================================================
# GLOBAL TEST CONFIGURATION
# ============================================================================
# Timeouts (can be overridden by environment variables)
${GLOBAL_TIMEOUT}               ${DEFAULT_TIMEOUT}
${GLOBAL_RETRY_COUNT}           ${MAX_RETRIES}
${GLOBAL_RETRY_INTERVAL}        ${RETRY_INTERVAL}
${API_TIMEOUT}                  60
${SCAN_WAIT_TIMEOUT}            7200
${REPORT_WAIT_TIMEOUT}          600

# ============================================================================
# TEST EXECUTION CONTEXT
# ============================================================================
${TEST_ENVIRONMENT}             ${ENVIRONMENT}
${TEST_START_TIME}              ${EMPTY}
${TEST_END_TIME}                ${EMPTY}
${SUITE_START_TIME}             ${EMPTY}
${SUITE_END_TIME}               ${EMPTY}
${SUITE_EXECUTION_ID}           ${EMPTY}
${TEST_EXECUTION_ID}            ${EMPTY}

# ============================================================================
# API CONFIGURATION
# ============================================================================
${API_VERSION}                  3
${API_BASE_PATH}                /api/${API_VERSION}
${API_V1_XML}                   /api/1.1/xml
${API_CONTENT_TYPE_JSON}        application/json
${API_CONTENT_TYPE_XML}         application/xml

# ============================================================================
# BENCHMARK TYPES
# ============================================================================
${BENCHMARK_TYPE_CIS}           CIS
${BENCHMARK_TYPE_DISA}          DISA
${BENCHMARK_TYPE_STIG}          STIG

# ============================================================================
# COMPLIANCE LEVELS
# ============================================================================
${COMPLIANCE_LEVEL_1}           level1
${COMPLIANCE_LEVEL_2}           level2
${COMPLIANCE_CRITICAL}          critical
${COMPLIANCE_HIGH}              high
${COMPLIANCE_MEDIUM}            medium
${COMPLIANCE_LOW}               low

# ============================================================================
# SCAN CONFIGURATION
# ============================================================================
${DEFAULT_SCAN_TEMPLATE}        cis
${SCAN_STATUS_RUNNING}          running
${SCAN_STATUS_COMPLETED}        finished
${SCAN_STATUS_STOPPED}          stopped
${SCAN_STATUS_PAUSED}           paused
${SCAN_STATUS_ERROR}            error

# ============================================================================
# REPORT CONFIGURATION
# ============================================================================
${REPORT_FORMAT_PDF}            pdf
${REPORT_FORMAT_HTML}           html
${REPORT_FORMAT_XML}            xml
${REPORT_FORMAT_CSV}            csv
${REPORT_FORMAT_XCCDF}          xccdf

# ============================================================================
# FILE PATHS (Relative to project root)
# ============================================================================
${POLICIES_DIR}                 data/policies
${TEMPLATES_DIR}                data/templates
${PAYLOADS_DIR}                 payloads
${TEST_DATA_DIR}                testdata
${VALIDATION_RULES_DIR}         testdata/validation_rules

# ============================================================================
# GLOBAL FLAGS
# ============================================================================
${CLEANUP_REQUIRED}             ${TRUE}
${PARALLEL_EXECUTION}           ${FALSE}
${DRY_RUN}                      ${FALSE}
${CAPTURE_SCREENSHOTS}          ${TRUE}
${DETAILED_LOGGING}             ${TRUE}

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================
${LOG_FORMAT}                   [timestamp] [level] [component] message
${LOG_DATE_FORMAT}              %Y-%m-%d %H:%M:%S
${CONSOLE_LOG_LEVEL}            INFO
${FILE_LOG_LEVEL}               DEBUG

# ============================================================================
# HTTP STATUS CODES
# ============================================================================
${HTTP_OK}                      200
${HTTP_CREATED}                 201
${HTTP_ACCEPTED}                202
${HTTP_NO_CONTENT}              204
${HTTP_BAD_REQUEST}             400
${HTTP_UNAUTHORIZED}            401
${HTTP_FORBIDDEN}               403
${HTTP_NOT_FOUND}               404
${HTTP_CONFLICT}                409
${HTTP_SERVER_ERROR}            500

# ============================================================================
# REGEX PATTERNS
# ============================================================================
${REGEX_UUID}                   [a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}
${REGEX_IP_ADDRESS}             \\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}
${REGEX_TIMESTAMP}              \\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}
