"""
Shared Credentials Configuration - Same for ALL environments
Reads from environment variables (set by Jenkins or manually)
Falls back to defaults if not set
"""
import os

# Nexpose Credentials (from Jenkins environment variables or defaults)
# These are the SAME for all environments (staging, prod, prod-us, prod-eu)
NEXPOSE_USERNAME = os.getenv("NEXPOSE_USERNAME", "nxadmin")
NEXPOSE_PASSWORD = os.getenv("NEXPOSE_PASSWORD", "nxadmin")
NEXPOSE_PORT = os.getenv("NEXPOSE_PORT", "3780")
NEXPOSE_SSL_VERIFY = os.getenv("NEXPOSE_SSL_VERIFY", "False").lower() == "true"

# Host is environment-specific, passed from Jenkins or set manually
NEXPOSE_HOST = os.getenv("NEXPOSE_HOST", "")
