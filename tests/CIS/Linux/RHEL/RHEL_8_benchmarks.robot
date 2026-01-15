*** Settings ***
Documentation     Red Hat Enterprise Linux 8 (RHEL 8) CIS Benchmark Compliance Testing
...               
...               ═══════════════════════════════════════════════════════════════════
...               TARGET OPERATING SYSTEM: Red Hat Enterprise Linux 8 (RHEL 8)
...               BENCHMARK STANDARD: CIS (Center for Internet Security)
...               COMPLIANCE FRAMEWORK: CIS Benchmark v2.0.0
...               ═══════════════════════════════════════════════════════════════════
...               
...               This test suite validates RHEL 8 systems against CIS security benchmarks.
...               It performs end-to-end compliance testing including scan execution,
...               XCCDF report generation, and validation against predefined security rules.
...               
...               OS DETAILS:
...               • Operating System: Red Hat Enterprise Linux 8
...               • OS Family: Linux
...               • Distribution: RHEL (Red Hat)
...               • Benchmark Version: 4.0.0
...               • Supported Profiles: Level 1 Server, Level 1 Workstation, Level 2 Server, Level 2 Workstation
...               
...               TEST WORKFLOW:
...               1. Authenticate to Nexpose/InsightVM console
...               2. Load RHEL 8 CIS policies from configuration
...               3. Select and configure scan engine
...               4. Create scan template with RHEL 8 CIS benchmark policies
...               5. Configure site with RHEL 8 target credentials (SSH)
...               6. Execute compliance scan on RHEL 8 system
...               7. Monitor scan progress until completion
...               8. Generate XCCDF compliance report
...               9. Validate results against RHEL 8 CIS Level 1 Server rules
...               
...               CONFIGURATION REQUIREMENTS:
...               • Target System: RHEL 8 server with SSH access
...               • Credentials: Root or privileged account
...               • Network: Connectivity to target RHEL 8 system
...               • Validation Rules: testdata/validation_rules/CIS/RHEL9/level1_server.csv
...               • Policy Configuration: data/policies/cis_policies.json
...               
...               VM CONFIGURATION PATH:
...               CIS → RHEL → 9 → compliance → server

# Global Framework Imports
Resource          ${CURDIR}/../../../../common/global_imports.robot

# Suite and Test Lifecycle
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Suite-level tags
Force Tags        rhel    rhel8    linux    cis    benchmark    compliance

*** Test Cases ***
RHEL 8 - CIS Benchmark Level 1 Server Compliance Test
    [Documentation]    Validates Red Hat Enterprise Linux 8 against CIS Level 1 Server benchmark
    ...    
    ...    This test case performs comprehensive compliance testing of RHEL 8 systems
    ...    against CIS Level 1 Server security baseline. It includes:
    ...    • Authentication to vulnerability management platform
    ...    • Scan template creation with RHEL 8 CIS policies
    ...    • Credentialed scan execution via SSH
    ...    • XCCDF report generation
    ...    • Validation of 235 CIS Level 1 Server controls
    ...    
    ...    Expected Result: All 235 security controls should pass validation
    [Tags]    rhel    rhel8    linux    red-hat    cis    benchmark    level1    server    compliance    e2e
    
    # Generate unique identifiers for this test run
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    RHEL8_CIS_Level1_Server_${timestamp}
    ${template_name}=    Set Variable    RHEL8_CIS_Template_${timestamp}
    
    # Execute RHEL 8 CIS Level 1 Server compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_RHEL_8
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=CIS_Red_Hat_Enterprise_Linux_8_Benchmark
    ...    version=4.0.0
    ...    scan_template=cis
    ...    server_service=ssh
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EXECDIR}/testdata/validation_rules/CIS/RHEL/8/baseline_rules.csv
   


























  # Validate against multiple CSV files
   # @{csv_files}=    Create List
   # ...    ${EXECDIR}/testdata/validation_rules/CIS/RHEL9/level1_server.csv
   # ...    ${EXECDIR}/testdata/validation_rules/CIS/RHEL9/level2_server.csv
   # ...    ${EXECDIR}/testdata/validation_rules/CIS/RHEL9/level1_workstation.csv
    
   # FOR    ${csv_file}    IN    @{csv_files}
     #   ${csv_name}=    Evaluate    "${csv_file}".split('/')[-1]
     #   Log    <span style="color: blue; font-weight: bold;">Validating ${csv_name}...</span>    html=True
     #   Validate Report From Excel    ${results}[xccdf_report]    ${csv_file}
   # END
