# CIS Compliance Testing Framework

Automated CIS and DISA benchmark compliance testing using Robot Framework and Nexpose.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
- [Configuration](#configuration)
- [Local Execution](#local-execution)
- [Jenkins CI/CD](#jenkins-cicd)
- [Parallel Testing](#parallel-testing)
- [Available Profiles](#available-profiles)
- [Troubleshooting](#troubleshooting)

---

## Overview

This framework automates CIS (Center for Internet Security) and DISA STIG benchmark compliance testing by:

1. Connecting to Nexpose Security Console
2. Creating scan templates with specific benchmark policies
3. Creating sites with target VM credentials
4. Running compliance scans
5. Generating XCCDF reports
6. Cleaning up resources after tests

### Supported Benchmarks

| Category | Examples |
|----------|----------|
| **Linux** | Ubuntu 22.04, RHEL 8/9, Amazon Linux, Oracle Linux |
| **Windows** | Windows Server 2019/2022, Windows 10/11 |
| **macOS** | macOS 12 Monterey, macOS 13 Ventura |
| **Databases** | Oracle 19c, PostgreSQL, MySQL |
| **Applications** | Apache, Nginx, Tomcat |
| **Network** | Cisco IOS, Palo Alto Firewall |

---

## Project Structure

```
poc_robot_framework/
├── Jenkinsfile                    # CI/CD pipeline definition
├── robot.toml                     # Robot Framework profiles
├── setup.sh                       # Dependency installation script
├── requirements.txt               # Python dependencies
│
├── common/
│   ├── global_imports.robot       # Shared library imports
│   ├── global_variables.robot     # Global variables
│   └── keywords/
│       └── common_setup_teardown.robot  # Test lifecycle keywords
│
├── config/
│   ├── environments/              # YAML environment configs
│   │   ├── local.yaml
│   │   ├── staging.yaml
│   │   ├── prod.yaml
│   │   ├── prod_us.yaml
│   │   └── prod_eu.yaml
│   └── variables/                 # Python variable files
│       ├── credentials.py         # Shared credentials (env vars)
│       ├── local.py
│       ├── staging.py
│       ├── prod.py
│       ├── prod_us.py
│       └── prod_eu.py
│
├── data/
│   ├── policies/                  # CIS/DISA policy definitions
│   │   ├── cis_policies.json
│   │   └── disa_policies.json
│   └── templates/                 # Scan template XML files
│       ├── cis_template.xml
│       └── disa_template.xml
│
├── library/                       # Python helper libraries
│   ├── credential_manager.py
│   ├── excel_validator.py
│   ├── format_xml.py
│   └── generate_xccdf_report.py
│
├── resources/                     # Robot Framework keywords
│   ├── login.robot               # Nexpose authentication
│   ├── site.robot                # Site management
│   ├── scan_operations.robot     # Scan control
│   ├── report_operations.robot   # Report generation
│   ├── scan_template_api.robot   # Template management
│   ├── engines.robot             # Engine operations
│   └── e2e_benchmark_testing.robot  # End-to-end workflow
│
├── testdata/
│   ├── vm_config.json            # Target VM configurations
│   └── validation_rules/         # Expected results CSVs
│
├── tests/                         # Test suites
│   ├── CIS/
│   │   ├── Linux/
│   │   │   ├── Ubuntu/
│   │   │   │   └── ubuntu_22.04_benchmarks.robot
│   │   │   └── RHEL/
│   │   │       └── RHEL9benchmarks.robot
│   │   ├── Windows/
│   │   │   └── windows_server_2022_stig_benchmark.robot
│   │   ├── Apple/
│   │   │   └── MacOS_12_Benchmarks.robot
│   │   └── Oracle/
│   │       └── oracle19cbenchmark.robot
│   └── DISA/
│       └── windows10benchmark.robot
│
└── results/                       # Test output (gitignored)
    └── <environment>/
        ├── output.xml
        ├── log.html
        └── report.html
```

---

## How It Works

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TEST EXECUTION FLOW                          │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Command    │    │   robot.toml │    │  variables/  │
│  --profile   │───▶│   Profile    │───▶│  <env>.py    │
│   staging    │    │   Settings   │    │  Credentials │
└──────────────┘    └──────────────┘    └──────────────┘
                                               │
                                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                      SUITE SETUP                                  │
│  1. Login to Nexpose Console (NEXPOSE_HOST + credentials)        │
│  2. Cleanup orphaned resources (old templates & sites)           │
└──────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                      TEST EXECUTION                               │
│  1. Load VM config from vm_config.json (or --variable VM_IP)     │
│  2. Load policies from cis_policies.json                         │
│  3. Create scan template with CIS/DISA policies                  │
│  4. Check host reachability (TCP port check + ping fallback)     │
│  5. Create site with VM credentials                              │
│  6. Start scan and monitor progress                              │
│  7. Wait for scan completion                                     │
│  8. Generate XCCDF report                                        │
│  9. Download and validate report                                 │
└──────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                      SUITE TEARDOWN                               │
│  1. Delete scan template                                         │
│  2. Delete site                                                  │
│  3. Logout from Nexpose                                          │
└──────────────────────────────────────────────────────────────────┘
```

### Where Configuration Comes From

| Setting | Source | Override |
|---------|--------|----------|
| **NEXPOSE_HOST** | `config/variables/<env>.py` | `--variable NEXPOSE_HOST:x.x.x.x` |
| **NEXPOSE_PORT** | `config/variables/<env>.py` | `--variable NEXPOSE_PORT:3780` |
| **Credentials** | `config/variables/credentials.py` | Environment variables |
| **VM IP** | `testdata/vm_config.json` | `--variable VM_IP:x.x.x.x` |
| **Engine ID** | `testdata/vm_config.json` | `--variable ENGINE_ID:3` |
| **Policies** | `data/policies/cis_policies.json` | Test file variables |

### Credentials Hierarchy

```
Environment Variables (highest priority)
         │
         ▼
    NEXPOSE_USERNAME, NEXPOSE_PASSWORD
         │
         ▼
    credentials.py defaults (nxadmin/nxadmin)
```

---

## Configuration

### 1. Environment Variables (Recommended for CI/CD)

```bash
export NEXPOSE_USERNAME="your-username"
export NEXPOSE_PASSWORD="your-password"
```

### 2. VM Configuration (`testdata/vm_config.json`)

```json
{
  "CIS": {
    "Ubuntu": {
      "Ubuntu-22-04": {
        "ip": "10.4.30.59",
        "engine_id": 3,
        "ssh_username": "root",
        "ssh_password": "password",
        "os_name": "CIS Ubuntu Linux 22.04 LTS",
        "os_version": "1.0.0"
      }
    }
  }
}
```

### 3. Environment Profiles (`robot.toml`)

Available profiles: `local`, `staging`, `prod`, `prod-us`, `prod-eu`

Each profile defines:
- Output directory
- Log level
- Variable files to load

---

## Local Execution

### Prerequisites

```bash
# Install dependencies
./setup.sh

# Or manually
pip install -r requirements.txt
```

### Basic Commands

```bash
# Run with specific profile
robot --profile staging tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot

# Override VM IP from command line
robot --profile prod --variable VM_IP:10.1.2.3 tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot

# Override Nexpose host
robot --profile local --variable NEXPOSE_HOST:192.168.1.100 tests/

# Specify output directory
robot --profile staging --outputdir results/ubuntu2204 tests/CIS/Linux/Ubuntu/

# Run with multiple variable overrides
robot --profile prod \
      --variable VM_IP:10.1.2.3 \
      --variable ENGINE_ID:5 \
      --variable NEXPOSE_HOST:nexpose.company.com \
      --outputdir results/custom \
      tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot
```

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--profile` | Environment profile | `--profile staging` |
| `--variable` | Override any variable | `--variable VM_IP:10.1.2.3` |
| `--outputdir` | Results directory | `--outputdir results/mytest` |
| `--include` | Run tests with tag | `--include smoke` |
| `--exclude` | Skip tests with tag | `--exclude slow` |
| `--loglevel` | Log verbosity | `--loglevel DEBUG` |

### Examples by Environment

```bash
# Local development
robot --profile local --outputdir results/local tests/

# Staging (pre-production)
robot --profile staging --outputdir results/staging tests/

# Production
robot --profile prod --variable VM_IP:10.1.2.3 --outputdir results/prod tests/

# Production US region
robot --profile prod-us --variable VM_IP:10.2.0.50 tests/

# Production EU region
robot --profile prod-eu --variable VM_IP:10.3.0.75 tests/
```

---

## Jenkins CI/CD

### Setup Requirements

1. **Jenkins Plugins**:
   - Pipeline
   - Git
   - Robot Framework
   - Credentials

2. **Jenkins Credentials** (Manage Jenkins → Credentials):
   - `nexpose-username`: Secret text with Nexpose username
   - `nexpose-password`: Secret text with Nexpose password

3. **Pipeline Job Configuration**:
   - Pipeline from SCM: Git
   - Repository: `https://github.com/msykam-r7/policycontent_poc_robot_framework.git`
   - Branch: `feature/benchmark-testing-automation`
   - Script Path: `Jenkinsfile`

### Trigger Types

| Trigger | When | Environment | Configuration |
|---------|------|-------------|---------------|
| **Nightly** | 2:00 AM daily | Staging only | Automatic (cron) |
| **Manual** | On demand | Your choice | Build with Parameters |
| **On Push** | Code pushed | Configurable | GitHub webhook (optional) |

### Jenkins Parameters

When clicking "Build with Parameters":

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ENVIRONMENT` | Target environment | staging |
| `NEXPOSE_HOST_IP` | Console IP (optional override) | (empty) |
| `VM_IP` | Target VM to scan (optional) | (empty) |
| `TEST_SUITE` | Test scope | regression |
| `TEST_PATH` | Test file/folder | tests/ |

### How Nightly Runs Work

```
┌─────────────────────────────────────────────────────────────────┐
│                    NIGHTLY RUN (2:00 AM)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Jenkins cron triggers build  │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Pull latest code from GitHub │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Load credentials from        │
              │  Jenkins Credentials Store    │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Run: robot --profile staging │
              │        tests/                 │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Archive results & reports    │
              │  Publish Robot Framework      │
              │  test results                 │
              └───────────────────────────────┘
```

### Manual Build Example

To run Ubuntu 22.04 benchmark on production:

1. Go to Jenkins job → "Build with Parameters"
2. Set parameters:
   - `ENVIRONMENT` = `prod`
   - `VM_IP` = `10.4.30.59`
   - `TEST_PATH` = `tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot`
3. Click "Build"

This executes:
```bash
robot --profile prod --variable VM_IP:10.4.30.59 \
      --outputdir results/prod \
      tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot
```

---

## Parallel Testing

### Using Pabot (Parallel Robot Framework)

Install pabot:
```bash
pip install robotframework-pabot
```

### Run Tests in Parallel

```bash
# Run all CIS Linux tests in parallel (one process per test file)
pabot --profile staging tests/CIS/Linux/

# Run with 4 parallel processes
pabot --processes 4 --profile staging tests/CIS/

# Run specific tests in parallel
pabot --profile staging \
      tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot \
      tests/CIS/Linux/RHEL/RHEL9benchmarks.robot \
      tests/CIS/Windows/windows_server_2022_stig_benchmark.robot
```

### Parallel Execution Flow

```
┌────────────────────────────────────────────────────────────────┐
│                    PABOT PARALLEL EXECUTION                    │
└────────────────────────────────────────────────────────────────┘

pabot --processes 3 tests/CIS/Linux/

        ┌─────────────────┐
        │     PABOT       │
        │   Controller    │
        └────────┬────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
┌────────┐  ┌────────┐  ┌────────┐
│Process1│  │Process2│  │Process3│
│Ubuntu  │  │RHEL 9  │  │Windows │
│22.04   │  │        │  │2022    │
└────────┘  └────────┘  └────────┘
    │            │            │
    ▼            ▼            ▼
┌────────┐  ┌────────┐  ┌────────┐
│Nexpose │  │Nexpose │  │Nexpose │
│Scan 1  │  │Scan 2  │  │Scan 3  │
└────────┘  └────────┘  └────────┘
    │            │            │
    └────────────┼────────────┘
                 │
                 ▼
        ┌─────────────────┐
        │ Combined Report │
        │   output.xml    │
        └─────────────────┘
```

### Jenkins Parallel Execution

Update Jenkinsfile for parallel stages:

```groovy
stage('Run Tests') {
    parallel {
        stage('Linux Tests') {
            steps {
                sh 'robot --profile staging --outputdir results/linux tests/CIS/Linux/'
            }
        }
        stage('Windows Tests') {
            steps {
                sh 'robot --profile staging --outputdir results/windows tests/CIS/Windows/'
            }
        }
        stage('macOS Tests') {
            steps {
                sh 'robot --profile staging --outputdir results/macos tests/CIS/Apple/'
            }
        }
    }
}
```

### Important Notes for Parallel Testing

1. **Unique Resource Names**: The framework generates unique names for templates and sites to avoid conflicts
2. **Engine Capacity**: Ensure your Nexpose engines can handle concurrent scans
3. **VM Availability**: Each parallel test needs its own target VM
4. **Resource Cleanup**: Each test cleans up its own resources

---

## Available Profiles

| Profile | Use Case | Log Level | Output Dir |
|---------|----------|-----------|------------|
| `local` | Development | DEBUG | results/local |
| `staging` | Pre-production testing | INFO | results/staging |
| `prod` | Production | INFO | results/prod |
| `prod-us` | US region production | INFO | results/prod-us |
| `prod-eu` | EU region production | INFO | results/prod-eu |
| `smoke` | Quick validation | INFO | results/smoke |
| `regression` | Full regression | INFO | results/regression |
| `ci` | CI/CD pipeline | INFO | results/ci |
| `debug` | Troubleshooting | TRACE | results/debug |
| `dryrun` | Syntax validation | INFO | results/dryrun |

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Host unreachable | Firewall blocking | Check TCP ports 22, 3389, 5985 |
| Login failed | Invalid credentials | Verify NEXPOSE_USERNAME/PASSWORD |
| Template creation failed | Invalid policies | Check cis_policies.json |
| Scan timeout | VM not responding | Verify VM is running and accessible |
| Permission denied | SSH credentials wrong | Check vm_config.json credentials |

### Debug Mode

```bash
# Run with maximum verbosity
robot --profile debug --loglevel TRACE tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot

# Dry run (validate syntax only)
robot --profile dryrun tests/
```

### View Logs

```bash
# Open HTML report
open results/staging/report.html

# View detailed log
open results/staging/log.html
```

---

## Quick Reference

### Local Run Command Template

```bash
robot --profile <env> \
      --variable VM_IP:<target-ip> \
      --outputdir results/<name> \
      tests/<path>
```

### Jenkins Build Parameters

| Running on Prod with custom VM |
|-------------------------------|
| ENVIRONMENT: `prod` |
| VM_IP: `10.1.2.3` |
| TEST_PATH: `tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot` |

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Robot Framework logs in `results/<env>/log.html`
3. Contact the team with the log files

---

*Last updated: January 2026*
