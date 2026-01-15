"""
Credential Management Library for Robot Framework
==================================================

This library provides secure credential management with multiple backend options:
1. Environment Variables (recommended for CI/CD)
2. AWS Secrets Manager (recommended for production)
3. HashiCorp Vault (enterprise option)
4. Encrypted JSON files (fallback option)

Security Features:
- No plaintext passwords in code
- Support for multiple secret backends
- Credential rotation support
- Audit logging
- Encrypted fallback storage

Usage in Robot Framework:
    Library    credential_manager.py

    ${username}    ${password}=    Get VM Credentials
    ...    benchmark=CIS
    ...    os=RHEL
    ...    version=9
    ...    credential_type=compliance
    ...    service_type=server
"""

import os
import json
import base64
from pathlib import Path
from typing import Dict, Tuple, Optional
import logging

# Optional imports for secret managers (install if needed)
try:
    import boto3
    from botocore.exceptions import ClientError
    HAS_AWS = True
except ImportError:
    HAS_AWS = False

try:
    import hvac
    HAS_VAULT = False
except ImportError:
    HAS_VAULT = False

try:
    from cryptography.fernet import Fernet
    HAS_CRYPTO = True
except ImportError:
    HAS_CRYPTO = False


class CredentialManager:
    """
    Secure credential management with multiple backend support
    """
    
    ROBOT_LIBRARY_SCOPE = 'GLOBAL'
    
    def __init__(self, backend: str = None):
        """
        Initialize credential manager
        
        Args:
            backend: Credential storage backend
                - 'env' (default): Environment variables
                - 'aws': AWS Secrets Manager
                - 'vault': HashiCorp Vault
                - 'encrypted': Encrypted JSON file
                - 'json': Plain JSON (NOT RECOMMENDED)
        """
        self.logger = logging.getLogger(__name__)
        
        # Determine backend (priority: parameter > env var > default)
        self.backend = backend or os.getenv('CRED_BACKEND', 'env')
        
        # Configuration
        self.aws_region = os.getenv('AWS_REGION', 'us-east-1')
        self.vault_url = os.getenv('VAULT_ADDR', 'http://localhost:8200')
        self.vault_token = os.getenv('VAULT_TOKEN')
        self.encryption_key = os.getenv('ENCRYPTION_KEY')
        
        # File paths
        self.json_path = Path(__file__).parent.parent / 'testdata' / 'vm_config.json'
        self.encrypted_path = Path(__file__).parent.parent / 'testdata' / 'vm_config.encrypted'
        
        self.logger.info(f"Credential Manager initialized with backend: {self.backend}")
    
    def get_vm_credentials(self, benchmark: str, os_name: str, version: str, 
                          credential_type: str, service_type: str) -> Tuple[str, str, str]:
        """
        Get VM credentials from configured backend
        
        Args:
            benchmark: CIS, DISA, etc.
            os_name: Operating system name (e.g., RHEL, Ubuntu)
            version: OS version (e.g., 9, 20.04)
            credential_type: compliance or not-compliance
            service_type: server or database
            
        Returns:
            Tuple of (ip, username, password)
            
        Example:
            ${ip}    ${username}    ${password}=    Get VM Credentials
            ...    CIS    RHEL    9    compliance    server
        """
        if self.backend == 'env':
            return self._get_from_env(benchmark, os_name, version, credential_type, service_type)
        elif self.backend == 'aws' and HAS_AWS:
            return self._get_from_aws(benchmark, os_name, version, credential_type, service_type)
        elif self.backend == 'vault' and HAS_VAULT:
            return self._get_from_vault(benchmark, os_name, version, credential_type, service_type)
        elif self.backend == 'encrypted' and HAS_CRYPTO:
            return self._get_from_encrypted_file(benchmark, os_name, version, credential_type, service_type)
        elif self.backend == 'json':
            self.logger.warning("Using plain JSON backend - NOT RECOMMENDED for production!")
            return self._get_from_json(benchmark, os_name, version, credential_type, service_type)
        else:
            raise ValueError(f"Unsupported backend: {self.backend}")
    
    def _get_from_env(self, benchmark: str, os_name: str, version: str, 
                     credential_type: str, service_type: str) -> Tuple[str, str, str]:
        """
        Get credentials from environment variables
        
        Expected format:
            VM_CIS_RHEL_9_COMPLIANCE_SERVER_IP=10.4.22.212
            VM_CIS_RHEL_9_COMPLIANCE_SERVER_USERNAME=root
            VM_CIS_RHEL_9_COMPLIANCE_SERVER_PASSWORD=secret123
        """
        prefix = f"VM_{benchmark}_{os_name}_{version}_{credential_type}_{service_type}".upper()
        
        ip = os.getenv(f"{prefix}_IP")
        username = os.getenv(f"{prefix}_USERNAME")
        password = os.getenv(f"{prefix}_PASSWORD")
        
        if not all([ip, username, password]):
            # Fallback to generic credentials if specific not found
            self.logger.warning(f"Specific credentials not found for {prefix}, trying generic...")
            ip = ip or os.getenv(f"VM_{benchmark}_{os_name}_IP")
            username = username or os.getenv(f"VM_{benchmark}_{os_name}_USERNAME", "root")
            password = password or os.getenv(f"VM_{benchmark}_{os_name}_PASSWORD")
        
        if not all([ip, username, password]):
            raise ValueError(
                f"Missing environment variables for {prefix}. Required:\n"
                f"  {prefix}_IP\n"
                f"  {prefix}_USERNAME\n"
                f"  {prefix}_PASSWORD"
            )
        
        self.logger.info(f"Retrieved credentials from environment for {benchmark}/{os_name}/{version}")
        return ip, username, password
    
    def _get_from_aws(self, benchmark: str, os_name: str, version: str, 
                     credential_type: str, service_type: str) -> Tuple[str, str, str]:
        """
        Get credentials from AWS Secrets Manager
        
        Secret name format: vm-credentials/{benchmark}/{os}/{version}/{type}/{service}
        """
        secret_name = f"vm-credentials/{benchmark}/{os_name}/{version}/{credential_type}/{service_type}"
        
        session = boto3.session.Session()
        client = session.client(service_name='secretsmanager', region_name=self.aws_region)
        
        try:
            response = client.get_secret_value(SecretId=secret_name)
            secret = json.loads(response['SecretString'])
            
            self.logger.info(f"Retrieved credentials from AWS Secrets Manager: {secret_name}")
            return secret['ip'], secret['username'], secret['password']
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                raise ValueError(f"Secret not found in AWS: {secret_name}")
            else:
                raise
    
    def _get_from_vault(self, benchmark: str, os_name: str, version: str, 
                       credential_type: str, service_type: str) -> Tuple[str, str, str]:
        """
        Get credentials from HashiCorp Vault
        
        Path format: secret/vm-credentials/{benchmark}/{os}/{version}/{type}/{service}
        """
        if not self.vault_token:
            raise ValueError("VAULT_TOKEN environment variable not set")
        
        client = hvac.Client(url=self.vault_url, token=self.vault_token)
        
        if not client.is_authenticated():
            raise ValueError("Vault authentication failed")
        
        path = f"secret/vm-credentials/{benchmark}/{os_name}/{version}/{credential_type}/{service_type}"
        
        try:
            secret = client.secrets.kv.v2.read_secret_version(path=path)
            data = secret['data']['data']
            
            self.logger.info(f"Retrieved credentials from Vault: {path}")
            return data['ip'], data['username'], data['password']
            
        except Exception as e:
            raise ValueError(f"Failed to retrieve secret from Vault: {path}. Error: {e}")
    
    def _get_from_encrypted_file(self, benchmark: str, os_name: str, version: str, 
                                credential_type: str, service_type: str) -> Tuple[str, str, str]:
        """
        Get credentials from encrypted JSON file
        
        Uses Fernet symmetric encryption (AES 128 CBC)
        """
        if not self.encryption_key:
            raise ValueError("ENCRYPTION_KEY environment variable not set")
        
        if not self.encrypted_path.exists():
            raise ValueError(f"Encrypted credentials file not found: {self.encrypted_path}")
        
        # Read and decrypt file
        fernet = Fernet(self.encryption_key.encode())
        with open(self.encrypted_path, 'rb') as f:
            encrypted_data = f.read()
        
        decrypted_data = fernet.decrypt(encrypted_data)
        credentials = json.loads(decrypted_data)
        
        # Navigate JSON structure
        try:
            cred = credentials[benchmark][os_name][version][credential_type][service_type]
            self.logger.info(f"Retrieved credentials from encrypted file for {benchmark}/{os_name}/{version}")
            return cred['ip'], cred['username'], cred['password']
        except KeyError as e:
            raise ValueError(f"Credential path not found in encrypted file: {e}")
    
    def _get_from_json(self, benchmark: str, os_name: str, version: str, 
                      credential_type: str, service_type: str) -> Tuple[str, str, str]:
        """
        Get credentials from plain JSON file (LEGACY - NOT RECOMMENDED)
        """
        if not self.json_path.exists():
            raise ValueError(f"Credentials JSON file not found: {self.json_path}")
        
        with open(self.json_path, 'r') as f:
            credentials = json.load(f)
        
        # Navigate JSON structure
        try:
            cred = credentials[benchmark][os_name][version][credential_type][service_type]
            return cred['ip'], cred['username'], cred['password']
        except KeyError as e:
            raise ValueError(f"Credential path not found in JSON file: {e}")
    
    # Utility methods for credential management
    
    def encrypt_json_file(self, input_path: str, output_path: str, encryption_key: str):
        """
        Encrypt a JSON credentials file
        
        Usage:
            python3 -c "from library.credential_manager import CredentialManager; 
            cm = CredentialManager(); 
            cm.encrypt_json_file('testdata/vm_config.json', 'testdata/vm_config.encrypted', 'YOUR_KEY')"
        """
        fernet = Fernet(encryption_key.encode())
        
        with open(input_path, 'rb') as f:
            data = f.read()
        
        encrypted = fernet.encrypt(data)
        
        with open(output_path, 'wb') as f:
            f.write(encrypted)
        
        print(f"✓ Encrypted {input_path} → {output_path}")
    
    def generate_encryption_key(self) -> str:
        """
        Generate a new Fernet encryption key
        
        Usage:
            python3 -c "from library.credential_manager import CredentialManager; 
            cm = CredentialManager(); 
            print(cm.generate_encryption_key())"
        """
        key = Fernet.generate_key()
        return key.decode()
    
    def create_aws_secret(self, benchmark: str, os_name: str, version: str, 
                         credential_type: str, service_type: str,
                         ip: str, username: str, password: str):
        """
        Create/update secret in AWS Secrets Manager
        
        Usage from command line:
            python3 -c "from library.credential_manager import CredentialManager;
            cm = CredentialManager('aws');
            cm.create_aws_secret('CIS', 'RHEL', '9', 'compliance', 'server', 
                                '10.4.22.212', 'root', 'secret123')"
        """
        if not HAS_AWS:
            raise ImportError("boto3 not installed. Run: pip install boto3")
        
        secret_name = f"vm-credentials/{benchmark}/{os_name}/{version}/{credential_type}/{service_type}"
        secret_value = json.dumps({
            'ip': ip,
            'username': username,
            'password': password
        })
        
        session = boto3.session.Session()
        client = session.client(service_name='secretsmanager', region_name=self.aws_region)
        
        try:
            # Try to update existing secret
            client.update_secret(SecretId=secret_name, SecretString=secret_value)
            print(f"✓ Updated secret: {secret_name}")
        except client.exceptions.ResourceNotFoundException:
            # Create new secret
            client.create_secret(Name=secret_name, SecretString=secret_value)
            print(f"✓ Created secret: {secret_name}")


# Robot Framework keyword interface
def get_vm_credentials(benchmark: str, os_name: str, version: str, 
                      credential_type: str, service_type: str) -> Tuple[str, str, str]:
    """
    Robot Framework keyword to get VM credentials
    """
    cm = CredentialManager()
    return cm.get_vm_credentials(benchmark, os_name, version, credential_type, service_type)
