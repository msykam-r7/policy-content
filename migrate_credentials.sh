#!/usr/bin/env bash
#
# Migration Script: Move credentials from plaintext JSON to secure backend
#
# Usage:
#   ./migrate_credentials.sh env        # Migrate to environment variables
#   ./migrate_credentials.sh aws        # Migrate to AWS Secrets Manager
#   ./migrate_credentials.sh encrypted  # Migrate to encrypted file
#   ./migrate_credentials.sh vault      # Migrate to HashiCorp Vault
#

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

BACKEND=${1:-env}
JSON_FILE="testdata/vm_config.json"

echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}Credential Migration Tool${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo "Target Backend: $BACKEND"
echo ""

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo -e "${RED}Error: $JSON_FILE not found${NC}"
    exit 1
fi

# Function to extract credentials from JSON
extract_credentials() {
    python3 << 'EOF'
import json
import sys

def flatten_credentials(data, prefix=""):
    """Recursively flatten nested credential structure"""
    credentials = []
    
    for key, value in data.items():
        if isinstance(value, dict):
            if 'ip' in value and 'username' in value and 'password' in value:
                # This is a credential leaf node
                credentials.append({
                    'path': prefix,
                    'ip': value['ip'],
                    'username': value['username'],
                    'password': value['password']
                })
            else:
                # Recurse deeper
                new_prefix = f"{prefix}_{key}" if prefix else key
                credentials.extend(flatten_credentials(value, new_prefix))
    
    return credentials

with open('testdata/vm_config.json', 'r') as f:
    data = json.load(f)

credentials = flatten_credentials(data)

for cred in credentials:
    print(f"{cred['path']}|{cred['ip']}|{cred['username']}|{cred['password']}")
EOF
}

# Migration to Environment Variables
migrate_to_env() {
    echo -e "${YELLOW}Migrating to Environment Variables...${NC}"
    echo ""
    
    OUTPUT_FILE=".env.credentials"
    
    echo "# Credential Environment Variables" > $OUTPUT_FILE
    echo "# Generated on $(date)" >> $OUTPUT_FILE
    echo "# DO NOT COMMIT THIS FILE TO GIT!" >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
    echo "CRED_BACKEND=env" >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
    
    while IFS='|' read -r path ip username password; do
        # Convert path to env var format (uppercase, replace special chars)
        env_prefix=$(echo "VM_${path}" | tr '[:lower:]' '[:upper:]' | tr '-' '_' | tr '.' '_')
        
        echo "export ${env_prefix}_IP=\"${ip}\"" >> $OUTPUT_FILE
        echo "export ${env_prefix}_USERNAME=\"${username}\"" >> $OUTPUT_FILE
        echo "export ${env_prefix}_PASSWORD=\"${password}\"" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
        
        echo -e "  ✓ Exported ${env_prefix}"
    done < <(extract_credentials)
    
    echo ""
    echo -e "${GREEN}✓ Migration complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review generated file: $OUTPUT_FILE"
    echo "2. Load credentials: source $OUTPUT_FILE"
    echo "3. Test: robot tests/CIS/Linux/RHEL/RHEL9benchmarks.robot"
    echo "4. Add to CI/CD as secrets"
    echo "5. Delete plaintext JSON: rm $JSON_FILE"
    echo ""
    echo -e "${YELLOW}⚠️  Remember to add $OUTPUT_FILE to .gitignore!${NC}"
}

# Migration to AWS Secrets Manager
migrate_to_aws() {
    echo -e "${YELLOW}Migrating to AWS Secrets Manager...${NC}"
    echo ""
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI not installed${NC}"
        echo "Install with: pip install awscli"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured${NC}"
        echo "Configure with: aws configure"
        exit 1
    fi
    
    echo "AWS Account: $(aws sts get-caller-identity --query Account --output text)"
    echo "AWS Region: ${AWS_REGION:-us-east-1}"
    echo ""
    
    read -p "Proceed with migration? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    python3 << 'EOF'
import json
import boto3
from botocore.exceptions import ClientError

# Load credentials
with open('testdata/vm_config.json', 'r') as f:
    data = json.load(f)

def migrate_recursive(data, path_parts):
    """Recursively migrate credentials to AWS Secrets Manager"""
    for key, value in data.items():
        current_path = path_parts + [key]
        
        if isinstance(value, dict):
            if 'ip' in value and 'username' in value and 'password' in value:
                # This is a credential - create secret
                secret_name = f"vm-credentials/{'/'.join(current_path)}"
                secret_value = json.dumps({
                    'ip': value['ip'],
                    'username': value['username'],
                    'password': value['password']
                })
                
                client = boto3.client('secretsmanager')
                
                try:
                    client.create_secret(
                        Name=secret_name,
                        SecretString=secret_value
                    )
                    print(f"  ✓ Created: {secret_name}")
                except ClientError as e:
                    if e.response['Error']['Code'] == 'ResourceExistsException':
                        # Update existing
                        client.update_secret(
                            SecretId=secret_name,
                            SecretString=secret_value
                        )
                        print(f"  ✓ Updated: {secret_name}")
                    else:
                        print(f"  ✗ Failed: {secret_name} - {e}")
            else:
                # Recurse deeper
                migrate_recursive(value, current_path)

migrate_recursive(data, [])
print("\n✓ Migration complete!")
EOF
    
    echo ""
    echo -e "${GREEN}✓ Migration complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Set backend: export CRED_BACKEND=aws"
    echo "2. Test: robot tests/CIS/Linux/RHEL/RHEL9benchmarks.robot"
    echo "3. Delete plaintext JSON: rm $JSON_FILE"
    echo "4. Configure IAM policies for access control"
}

# Migration to Encrypted File
migrate_to_encrypted() {
    echo -e "${YELLOW}Migrating to Encrypted File...${NC}"
    echo ""
    
    # Check if cryptography is installed
    python3 -c "import cryptography" 2>/dev/null || {
        echo -e "${RED}Error: cryptography library not installed${NC}"
        echo "Install with: pip install cryptography"
        exit 1
    }
    
    # Generate encryption key
    echo "Generating encryption key..."
    ENCRYPTION_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    
    echo -e "${GREEN}Generated Encryption Key:${NC}"
    echo "$ENCRYPTION_KEY"
    echo ""
    echo -e "${RED}⚠️  SAVE THIS KEY SECURELY - YOU CANNOT RECOVER IT!${NC}"
    echo ""
    
    read -p "Have you saved the key? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Aborted. Please save the key and run again."
        exit 0
    fi
    
    # Encrypt file
    python3 << EOF
from cryptography.fernet import Fernet

key = "$ENCRYPTION_KEY"
fernet = Fernet(key.encode())

with open('testdata/vm_config.json', 'rb') as f:
    data = f.read()

encrypted = fernet.encrypt(data)

with open('testdata/vm_config.encrypted', 'wb') as f:
    f.write(encrypted)

print("✓ Created encrypted file: testdata/vm_config.encrypted")
EOF
    
    echo ""
    echo -e "${GREEN}✓ Migration complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Store encryption key securely (e.g., AWS Secrets Manager)"
    echo "2. Set environment variables:"
    echo "   export CRED_BACKEND=encrypted"
    echo "   export ENCRYPTION_KEY=\"$ENCRYPTION_KEY\""
    echo "3. Test: robot tests/CIS/Linux/RHEL/RHEL9benchmarks.robot"
    echo "4. Delete plaintext JSON: rm $JSON_FILE"
}

# Migration to HashiCorp Vault
migrate_to_vault() {
    echo -e "${YELLOW}Migrating to HashiCorp Vault...${NC}"
    echo ""
    
    # Check if vault CLI is available
    if ! command -v vault &> /dev/null; then
        echo -e "${RED}Error: Vault CLI not installed${NC}"
        echo "Install from: https://www.vaultproject.io/downloads"
        exit 1
    fi
    
    # Check Vault connection
    if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
        echo -e "${RED}Error: VAULT_ADDR and VAULT_TOKEN must be set${NC}"
        exit 1
    fi
    
    echo "Vault Address: $VAULT_ADDR"
    echo ""
    
    read -p "Proceed with migration? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    python3 << 'EOF'
import json
import subprocess

# Load credentials
with open('testdata/vm_config.json', 'r') as f:
    data = json.load(f)

def migrate_recursive(data, path_parts):
    """Recursively migrate credentials to Vault"""
    for key, value in data.items():
        current_path = path_parts + [key]
        
        if isinstance(value, dict):
            if 'ip' in value and 'username' in value and 'password' in value:
                # This is a credential - store in Vault
                path = f"secret/vm-credentials/{'/'.join(current_path)}"
                
                cmd = [
                    'vault', 'kv', 'put', path,
                    f"ip={value['ip']}",
                    f"username={value['username']}",
                    f"password={value['password']}"
                ]
                
                try:
                    subprocess.run(cmd, check=True, capture_output=True)
                    print(f"  ✓ Stored: {path}")
                except subprocess.CalledProcessError as e:
                    print(f"  ✗ Failed: {path} - {e}")
            else:
                # Recurse deeper
                migrate_recursive(value, current_path)

migrate_recursive(data, [])
print("\n✓ Migration complete!")
EOF
    
    echo ""
    echo -e "${GREEN}✓ Migration complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Set backend: export CRED_BACKEND=vault"
    echo "2. Test: robot tests/CIS/Linux/RHEL/RHEL9benchmarks.robot"
    echo "3. Delete plaintext JSON: rm $JSON_FILE"
    echo "4. Configure Vault policies for access control"
}

# Main migration logic
case $BACKEND in
    env)
        migrate_to_env
        ;;
    aws)
        migrate_to_aws
        ;;
    encrypted)
        migrate_to_encrypted
        ;;
    vault)
        migrate_to_vault
        ;;
    *)
        echo -e "${RED}Error: Unknown backend '$BACKEND'${NC}"
        echo ""
        echo "Usage: $0 [env|aws|encrypted|vault]"
        echo ""
        echo "Backends:"
        echo "  env       - Environment variables (recommended for CI/CD)"
        echo "  aws       - AWS Secrets Manager (recommended for production)"
        echo "  encrypted - Encrypted JSON file (fallback option)"
        echo "  vault     - HashiCorp Vault (enterprise option)"
        exit 1
        ;;
esac
