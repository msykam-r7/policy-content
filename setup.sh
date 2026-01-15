#!/bin/bash

# Robot Framework Test Suite Setup Script
# This script installs all required dependencies automatically

set -e

echo "================================================"
echo "Robot Framework Test Suite - Setup"
echo "================================================"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed"
    echo "Please install Python 3.8 or higher"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo "✓ Python version: $PYTHON_VERSION"

# Check if pip is available
if ! python3 -m pip --version &> /dev/null; then
    echo "❌ Error: pip is not installed"
    echo "Please install pip for Python 3"
    exit 1
fi

echo "✓ pip is available"
echo ""

# Install/upgrade pip
echo "Upgrading pip..."
python3 -m pip install --upgrade pip --quiet

# Install requirements
echo ""
echo "Installing Robot Framework dependencies..."
echo "================================================"

if [ -f "requirements.txt" ]; then
    python3 -m pip install -r requirements.txt
    echo ""
    echo "✅ All dependencies installed successfully!"
else
    echo "❌ Error: requirements.txt not found"
    exit 1
fi

# Verify installations
echo ""
echo "================================================"
echo "Verifying installations..."
echo "================================================"

# Check Robot Framework
if python3 -c "import robot" 2>/dev/null; then
    RF_VERSION=$(python3 -c "import robot; print(robot.__version__)")
    echo "✓ Robot Framework: $RF_VERSION"
else
    echo "❌ Robot Framework installation failed"
    exit 1
fi

# Check Pabot
if python3 -c "import pabot" 2>/dev/null; then
    echo "✓ Pabot: installed"
else
    echo "⚠ Pabot: not installed (parallel execution will not work)"
fi

# Check RequestsLibrary
if python3 -c "import RequestsLibrary" 2>/dev/null; then
    echo "✓ RequestsLibrary: installed"
else
    echo "❌ RequestsLibrary installation failed"
    exit 1
fi

echo ""
echo "================================================"
echo "Generating Parallel Execution Locks..."
echo "================================================"

# Generate pabot locks for safe parallel execution
if [ -f "scripts/generate_pabot_locks.py" ]; then
    python3 scripts/generate_pabot_locks.py
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Parallel execution locks generated!"
    else
        echo ""
        echo "⚠️  Could not generate locks (run manually later)"
    fi
fi

echo ""
echo "================================================"
echo "✅ Setup completed successfully!"
echo "================================================"
echo ""
echo "You can now run tests:"
echo "  Single test:"
echo "    robot --outputdir results tests/CIS/Windows/windows_server_2019_standard.robot"
echo ""
echo "  Parallel tests (RECOMMENDED - with automatic protection):"
echo "    pabot --argumentfile .pabotsuitenames --processes 4"
echo ""
echo "  Parallel tests (manual):"
echo "    pabot --processes 4 tests/CIS/"
echo ""
echo "================================================"
