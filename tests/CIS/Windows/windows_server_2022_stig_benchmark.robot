*** Settings ***
Documentation     Windows Server 2022 CIS Benchmark Compliance Testing
...               
...               ═══════════════════════════════════════════════════════════════════
...               TARGET OPERATING SYSTEM: Windows Server 2022
...               BENCHMARK STANDARD: CIS (Center for Internet Security)
...               COMPLIANCE FRAMEWORKS: Standard Benchmark & STIG Benchmark
...               ═══════════════════════════════════════════════════════════════════
...               
...               This test suite validates Windows Server 2022 systems against CIS security benchmarks.
...               It supports both Standard and STIG benchmark policies.
...               
...               AVAILABLE BENCHMARKS:
...               
...               1. STANDARD BENCHMARK (v4.0.0):
...                  • xccdf_org.cisecurity.benchmarks_benchmark_4.0.0_CIS_Microsoft_Windows_Server_2022_Benchmark
...                  • Policies: Level 1, Level 2, Next Generation Windows Security (NGWS)
...               
...               2. STIG BENCHMARK (v3.0.0):
...                  • xccdf_org.cisecurity.benchmarks_benchmark_3.0.0_CIS_Microsoft_Windows_Server_2022_STIG_Benchmark
...                  • Policies: DC CAT I/II/III, MS CAT I/II/III
...               
...               TEST WORKFLOW:
...               1. Authenticate to Nexpose/InsightVM console
...               2. Load Windows Server 2022 CIS policies from configuration
...               3. Select and configure scan engine
...               4. Create scan template with specified benchmark policies
...               5. Configure site with Windows Server 2022 target credentials (CIFS)
...               6. Execute compliance scan on Windows Server 2022 system
...               7. Monitor scan progress until completion
...               8. Generate XCCDF compliance report
...               
...               CONFIGURATION:
...               • Target System: Windows Server 2022 with CIFS/SMB access
...               • Credentials: Administrator account
...               • VM Config Path: CIS → Windows → 2022 → compliance → server

# Global Framework Imports
Resource          ${CURDIR}/../../../common/global_imports.robot

# Suite and Test Lifecycle
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Suite-level tags
Force Tags        windows    windows2022    cis    stig    benchmark    compliance


*** Variables ***
# Windows Server 2022 Standard Benchmark Policies (v4.0.0)
${WS2022_STANDARD_LEVEL1}    xccdf_org.cisecurity.benchmarks_profile_Level_1_-_Domain_Controller
${WS2022_STANDARD_LEVEL2}    xccdf_org.cisecurity.benchmarks_profile_Level_2_-_Domain_Controller
${WS2022_STANDARD_NGWS}      xccdf_org.cisecurity.benchmarks_profile_Next_Generation_Windows_Security_-_Domain_Controller

# Windows Server 2022 STIG Benchmark Policies (v3.0.0)
${WS2022_STIG_DC_CAT_I}      xccdf_org.cisecurity.benchmarks_profile_DC_SEVERITY_CAT_I
${WS2022_STIG_DC_CAT_II}     xccdf_org.cisecurity.benchmarks_profile_DC_SEVERITY_CAT_II
${WS2022_STIG_DC_CAT_III}    xccdf_org.cisecurity.benchmarks_profile_DC_SEVERITY_CAT_III
${WS2022_STIG_MS_CAT_I}      xccdf_org.cisecurity.benchmarks_profile_MS_SEVERITY_CAT_I
${WS2022_STIG_MS_CAT_II}     xccdf_org.cisecurity.benchmarks_profile_MS_SEVERITY_CAT_II
${WS2022_STIG_MS_CAT_III}    xccdf_org.cisecurity.benchmarks_profile_MS_SEVERITY_CAT_III


*** Test Cases ***
Windows Server 2022 - STIG DC CAT I
    [Documentation]    Tests Windows Server 2022 STIG Domain Controller Category I policies
    [Tags]    windows    windows-2022    stig    dc    cat1
    
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    WS2022_STIG_DC_CAT_I_${timestamp}
    ${template_name}=    Set Variable    WS2022_STIG_Template_${timestamp}
    
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Windows_2022
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=Microsoft_Windows_Server_2022_STIG_Benchmark
    ...    version=3.0.0
    ...    scan_template=cis
    ...    server_service=cifs
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=${WS2022_STIG_DC_CAT_I}
    ...    csv_file=${EMPTY}
    ...    validate_compliance=${FALSE}
    
    Log Test Results    ${results}


Windows Server 2022 - STIG DC All Categories
    [Documentation]    Tests Windows Server 2022 STIG Domain Controller ALL Categories (I, II, III)
    [Tags]    windows    windows-2022    stig    dc    comprehensive
    
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    WS2022_STIG_DC_ALL_${timestamp}
    ${template_name}=    Set Variable    WS2022_STIG_DC_Template_${timestamp}
    
    # Test with multiple STIG DC policies
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Windows_2022
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=Microsoft_Windows_Server_2022_STIG_Benchmark
    ...    version=3.0.0
    ...    scan_template=cis
    ...    server_service=cifs
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=${WS2022_STIG_DC_CAT_I},${WS2022_STIG_DC_CAT_II},${WS2022_STIG_DC_CAT_III}
    ...    csv_file=${EMPTY}
    ...    validate_compliance=${FALSE}
    
    Log Test Results    ${results}


Windows Server 2022 - STIG Member Server All Categories
    [Documentation]    Tests Windows Server 2022 STIG Member Server ALL Categories (I, II, III)
    [Tags]    windows    windows-2022    stig    member-server    comprehensive
    
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    WS2022_STIG_MS_ALL_${timestamp}
    ${template_name}=    Set Variable    WS2022_STIG_MS_Template_${timestamp}
    
    # Test with multiple STIG Member Server policies
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Windows_2022
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=Microsoft_Windows_Server_2022_STIG_Benchmark
    ...    version=3.0.0
    ...    scan_template=cis
    ...    server_service=cifs
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=${WS2022_STIG_MS_CAT_I},${WS2022_STIG_MS_CAT_II},${WS2022_STIG_MS_CAT_III}
    ...    csv_file=${EMPTY}
    ...    validate_compliance=${FALSE}
    
    Log Test Results    ${results}


*** Keywords ***
Log Test Results
    [Documentation]    Logs the E2E test results in a formatted manner
    [Arguments]    ${results}
    
    Log    ========================================    console=True
    Log    E2E TEST COMPLETE - WINDOWS SERVER 2022    console=True
    Log    ========================================    console=True
    Log    Session ID: ${results}[session_id]    console=True
    Log    Engine ID: ${results}[engine_id]    console=True
    Log    Template ID: ${results}[template_id]    console=True
    Log    Site ID: ${results}[site_id]    console=True
    Log    Scan ID: ${results}[scan_id]    console=True
    Log    Scan Status: ${results}[scan_status]    console=True
    Log    Scan Time: ${results}[scan_elapsed_time]s    console=True
    Log    Policy Count: ${results}[policy_count]    console=True
    Log    ========================================    console=True
    


