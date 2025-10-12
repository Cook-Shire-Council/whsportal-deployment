#!/bin/bash
#
# WHS Portal Addon Deployment Script (systemd version)
# Builds wheel, deploys to whsportaldev, and restarts Plone via systemd
#
# Usage:
#   ./deploy-systemd.sh csc           # Deploy csc.whs addon
#   ./deploy-systemd.sh theme         # Deploy cook.whs.barceloneta theme
#   ./deploy-systemd.sh both          # Deploy both addons
#
# Prerequisites:
#   - Plone running as systemd service (run setup-systemd.sh once)
#   - Sudoers configured for passwordless systemctl restart

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

# Restart Plone instance via systemd
echo ""
print_info "Restarting Plone service..."

# Check if systemd service exists
if ssh ${DEV_SERVER} "systemctl list-unit-files plone.service" | grep -q "plone.service"; then
    # Use systemctl restart (requires sudoers configuration)
    print_info "Using systemd to restart Plone..."
    ssh ${DEV_SERVER} "sudo systemctl restart plone"

    # Wait for service to stabilize
    sleep 5

    # Check service status
    if ssh ${DEV_SERVER} "systemctl is-active plone" | grep -q "^active$"; then
        print_success "Plone service restarted successfully"

        # Show brief status
        echo ""
        ssh ${DEV_SERVER} "systemctl status plone --no-pager -l" | head -15

        # Clear nginx cache
        echo ""
        print_info "Clearing nginx cache..."
        if ssh ${DEV_SERVER} "sudo rm -rf /opt/cache/nginx/plone/* 2>/dev/null && sudo systemctl restart nginx"; then
            print_success "Nginx cache cleared and service restarted"
        else
            print_warning "Could not clear nginx cache (may not be configured)"
        fi
    else
        print_error "Plone service failed to start!"
        print_info "Check logs with: ssh ${DEV_SERVER} 'sudo journalctl -u plone -n 50'"
        exit 1
    fi
else
    # Fallback to manual restart if systemd not configured
    print_warning "Systemd service not found, using manual restart..."
    print_info "Run setup-systemd.sh to configure systemd service"

    # Kill any existing screen session
    ssh ${DEV_SERVER} "screen -S plone -X quit 2>/dev/null || true"

    # Kill any running processes
    ssh ${DEV_SERVER} "pkill -f 'runwsgi.*zope.ini' || true"
    sleep 3

    # Start in screen
    ssh ${DEV_SERVER} "cd /opt/plone && screen -dmS plone ${PLONE_VENV}/bin/runwsgi -v ${PLONE_INSTANCE}/etc/zope.ini"
    sleep 5

    # Verify
    if ssh ${DEV_SERVER} "pgrep -f 'runwsgi.*zope.ini' > /dev/null"; then
        print_success "Plone restarted in screen session"
    else
        print_warning "Could not verify Plone started"
    fi
fi

# Cleanup
print_info "Cleaning up..."
ssh ${DEV_SERVER} "rm -rf ${TMP_DIR}"
print_success "Deployment complete!"

echo ""
print_info "Next steps:"
echo "  1. Check status: ssh ${DEV_SERVER} 'sudo systemctl status plone'"
echo "  2. View logs: ssh ${DEV_SERVER} 'sudo journalctl -u plone -f'"
echo "  3. Test portal: https://whsportal.cook.qld.gov.au"
