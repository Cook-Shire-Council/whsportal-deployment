#!/bin/bash
#
# Setup Plone as a systemd service
# Run this once on whsportaldev to install the systemd service
#

set -e

echo "Setting up Plone systemd service..."

# Copy service file
echo "Installing service file..."
sudo cp plone.service /etc/systemd/system/plone.service

# Set permissions
sudo chmod 644 /etc/systemd/system/plone.service

# Validate and install sudoers file
echo "Installing sudoers configuration..."
sudo visudo -c -f sudoers.d-plone
sudo cp sudoers.d-plone /etc/sudoers.d/plone
sudo chmod 440 /etc/sudoers.d/plone

# Reload systemd
echo "Reloading systemd..."
sudo systemctl daemon-reload

# Stop any existing screen sessions or manual processes
echo "Stopping existing Plone processes..."
screen -S plone -X quit 2>/dev/null || true
pkill -f 'runwsgi.*zope.ini' || true
sleep 3

# Enable and start service
echo "Enabling Plone service..."
sudo systemctl enable plone

echo "Starting Plone service..."
sudo systemctl start plone

# Wait for startup
sleep 5

# Check status
echo ""
echo "Plone service status:"
sudo systemctl status plone --no-pager

echo ""
echo "✓ Setup complete!"
echo ""
echo "Service commands:"
echo "  sudo systemctl start plone      # Start Plone"
echo "  sudo systemctl stop plone       # Stop Plone"
echo "  sudo systemctl restart plone    # Restart Plone"
echo "  sudo systemctl status plone     # Check status"
echo "  sudo journalctl -u plone -f     # View logs"
echo ""
echo "After sudoers is configured, restart without sudo:"
echo "  systemctl restart plone         # No sudo needed!"
