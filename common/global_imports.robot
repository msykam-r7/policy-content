*** Settings ***
Documentation     Global imports and common setup for CIS Compliance Testing Framework
...               
...               This file serves as the central import hub for all test suites.
...               Import this file in your test suite to get access to all common
...               libraries, resources, keywords, and global variables.
...               
...               USAGE:
...               Resource    ${CURDIR}/../common/global_imports.robot
...
...               STRUCTURE:
...               - Standard Robot Framework Libraries
...               - Third-party Libraries (requests, SSH, etc.)
...               - Custom Python Libraries
...               - Common Keywords and Resources
...               - Global Variables

# ============================================================================
# STANDARD ROBOT FRAMEWORK LIBRARIES
# ============================================================================
Library           Collections
Library           DateTime
Library           OperatingSystem
Library           String
Library           Process
Library           XML
Library           JSONLibrary

# ============================================================================
# THIRD-PARTY LIBRARIES
# ============================================================================
Library           RequestsLibrary
# Note: SSHLibrary should only be imported in test files that need SSH connections
# Importing it globally causes conflicts with OperatingSystem library keywords

# ============================================================================
# CUSTOM PYTHON LIBRARIES
# ============================================================================
Library           ${EXECDIR}/library/credential_manager.py
Library           ${EXECDIR}/library/excel_validator.py
Library           ${EXECDIR}/library/format_xml.py
Library           ${EXECDIR}/library/generate_xccdf_report.py

# ============================================================================
# ENVIRONMENT VARIABLES (Must be loaded BEFORE global_variables.robot)
# ============================================================================
Variables         ${EXECDIR}/config/variables/local.py

# ============================================================================
# GLOBAL VARIABLES FILE
# ============================================================================
Resource          ${CURDIR}/global_variables.robot

# ============================================================================
# COMMON KEYWORDS
# ============================================================================
Resource          ${CURDIR}/keywords/common_setup_teardown.robot

# ============================================================================
# DOMAIN-SPECIFIC RESOURCES
# ============================================================================
Resource          ${EXECDIR}/resources/e2e_benchmark_testing.robot
Resource          ${EXECDIR}/resources/login.robot
Resource          ${EXECDIR}/resources/scan_operations.robot
Resource          ${EXECDIR}/resources/report_operations.robot
Resource          ${EXECDIR}/resources/site.robot
Resource          ${EXECDIR}/resources/vm_config.robot
Resource          ${EXECDIR}/resources/engines.robot
Resource          ${EXECDIR}/resources/scan_template_api.robot
Resource          ${EXECDIR}/resources/parallel_utils.robot

*** Variables ***
# ============================================================================
# IMPORT METADATA
# ============================================================================
${GLOBAL_IMPORTS_VERSION}       2.0.0
${GLOBAL_IMPORTS_LOADED}        ${TRUE}

*** Keywords ***
Verify Global Imports Loaded
    [Documentation]    Verifies that global imports were successfully loaded
    [Tags]             utility    verification
    
    Should Be True    ${GLOBAL_IMPORTS_LOADED}    Global imports should be loaded
    Log    Global imports v${GLOBAL_IMPORTS_VERSION} loaded successfully    INFO

Get Framework Info
    [Documentation]    Returns a dictionary with framework information
    [Tags]             utility    info
    
    &{info}=    Create Dictionary
    ...    name=${FRAMEWORK_NAME}
    ...    version=${FRAMEWORK_VERSION}
    ...    author=${FRAMEWORK_AUTHOR}
    ...    environment=${TEST_ENVIRONMENT}
    ...    imports_version=${GLOBAL_IMPORTS_VERSION}
    
    RETURN    &{info}
*** Keywords ***
# This section intentionally left empty - keywords are imported from resource files