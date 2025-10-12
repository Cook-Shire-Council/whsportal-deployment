#!/bin/bash
#
# WHS Portal Addon Deployment Script
# Builds wheel, deploys to whsportaldev, and restarts Plone instance
#
# Usage:
#   ./deploy.sh csc           # Deploy csc.whs addon
#   ./deploy.sh theme         # Deploy cook.whs.barceloneta theme
#   ./deploy.sh both          # Deploy both addons

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEV_SERVER="whsportaldev"
DEV_USER="cscadmin"
PLONE_VENV="/opt/plone/venv"
PLONE_INSTANCE="/opt/plone/instance"
TMP_DIR="/tmp/whs_deploy"

# Parse arguments
ADDON="${1:-}"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to build and deploy an addon
deploy_addon() {
    local addon_name=$1
    local addon_dir=$2
    local package_name=$3

    print_info "Deploying ${addon_name}..."

    # Navigate to addon directory
    cd "${addon_dir}"

    # Clean previous builds
    print_info "Cleaning previous builds..."
    rm -rf dist/ build/ *.egg-info 2>/dev/null || true

    # Build wheel
    print_info "Building wheel for ${package_name}..."
    python3 -m build --wheel

    if [ ! -d "dist" ] || [ -z "$(ls -A dist/*.whl 2>/dev/null)" ]; then
        print_error "Wheel build failed for ${package_name}"
        return 1
    fi

    # Get the wheel filename
    WHEEL_FILE=$(ls dist/*.whl | head -1)
    WHEEL_NAME=$(basename "${WHEEL_FILE}")

    print_success "Built ${WHEEL_NAME}"

    # Create temp directory on remote server
    print_info "Preparing remote server..."
    ssh ${DEV_SERVER} "mkdir -p ${TMP_DIR}"

    # Copy wheel to server
    print_info "Copying wheel to ${DEV_SERVER}..."
    scp "${WHEEL_FILE}" ${DEV_SERVER}:${TMP_DIR}/
    print_success "Copied to server"

    # Install wheel on server
    print_info "Installing ${package_name} on ${DEV_SERVER}..."
    ssh ${DEV_SERVER} "${PLONE_VENV}/bin/pip install ${TMP_DIR}/${WHEEL_NAME} --force-reinstall --no-deps"
    print_success "Installed ${package_name}"

    # Verify installation
    print_info "Verifying installation..."
    INSTALLED_VERSION=$(ssh ${DEV_SERVER} "${PLONE_VENV}/bin/pip show ${package_name} | grep Version:" || echo "")
    if [ -n "${INSTALLED_VERSION}" ]; then
        print_success "${INSTALLED_VERSION}"
    else
        print_warning "Could not verify installation"
    fi
}

# Main deployment logic
case "${ADDON}" in
    csc)
        deploy_addon "csc.whs addon" "/home/ceo/Development/WHSPortal/csc" "csc.whs"
        ;;
    theme)
        deploy_addon "cook.whs.barceloneta theme" "/home/ceo/Development/WHSPortal/csc.whstheme" "cook.whs.barceloneta"
        ;;
    both)
        deploy_addon "csc.whs addon" "/home/ceo/Development/WHSPortal/csc" "csc.whs"
        echo ""
        deploy_addon "cook.whs.barceloneta theme" "/home/ceo/Development/WHSPortal/csc.whstheme" "cook.whs.barceloneta"
        ;;
    *)
        print_error "Usage: $0 {csc|theme|both}"
        exit 1
        ;;
esac

# Restart Plone instance
echo ""
print_info "Restarting Plone instance..."

# Kill any existing screen session named 'plone'
print_info "Stopping any existing Plone screen sessions..."
ssh ${DEV_SERVER} "screen -S plone -X quit 2>/dev/null || true"

# Kill any running Plone processes
print_info "Stopping any running Plone processes..."
ssh ${DEV_SERVER} "pkill -f 'runwsgi.*zope.ini' || true"
sleep 3

# Start Plone in a new screen session
print_info "Starting Plone in screen session..."
ssh ${DEV_SERVER} "cd /opt/plone && screen -dmS plone ${PLONE_VENV}/bin/runwsgi -v ${PLONE_INSTANCE}/etc/zope.ini"
sleep 5

# Verify Plone is starting
print_info "Verifying Plone is starting..."
if ssh ${DEV_SERVER} "pgrep -f 'runwsgi.*zope.ini' > /dev/null"; then
    print_success "Plone instance restarted successfully in screen session 'plone'"
else
    print_warning "Plone may not have started successfully. Check logs manually."
    print_info "View logs: ssh ${DEV_SERVER} 'tail -f ${PLONE_INSTANCE}/var/log/instance.log'"
fi

# Cleanup
print_info "Cleaning up..."
ssh ${DEV_SERVER} "rm -rf ${TMP_DIR}"
print_success "Deployment complete!"

echo ""
print_info "Next steps:"
echo "  1. Check logs: ssh ${DEV_SERVER} 'tail -f ${PLONE_INSTANCE}/var/log/instance.log'"
echo "  2. Test portal: https://whsportal.cook.qld.gov.au"
echo "  3. View console: ssh ${DEV_SERVER} 'screen -r plone'"
