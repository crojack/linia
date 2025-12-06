#!/bin/bash
# Linia Uninstall Script
# Removes Linia from ~/.local/bin and optionally removes configuration
# Removes desktop integration (menu entry, MIME types, icons)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "  Linia Uninstall Script"
echo "========================================="
echo ""

# Define installation paths
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/linia"
APPLICATIONS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor"
MIME_DIR="$HOME/.local/share/mime/packages"

# Remove executable
if [ -f "$BIN_DIR/linia" ]; then
    echo -e "${GREEN}Removing $BIN_DIR/linia...${NC}"
    rm -f "$BIN_DIR/linia"
else
    echo -e "${YELLOW}Executable not found at $BIN_DIR/linia${NC}"
fi

# Remove desktop file
if [ -f "$APPLICATIONS_DIR/linia.desktop" ]; then
    echo -e "${GREEN}Removing desktop menu entry...${NC}"
    rm -f "$APPLICATIONS_DIR/linia.desktop"
fi

# Remove MIME type
if [ -f "$MIME_DIR/linia.xml" ]; then
    echo -e "${GREEN}Removing MIME type...${NC}"
    rm -f "$MIME_DIR/linia.xml"
fi

# Remove application icon
if [ -f "$ICONS_DIR/scalable/apps/linia.svg" ]; then
    echo -e "${GREEN}Removing application icon...${NC}"
    rm -f "$ICONS_DIR/scalable/apps/linia.svg"
fi

# Remove MIME type icons
echo -e "${GREEN}Removing MIME type icons...${NC}"
MIME_ICON_REMOVED=0

# Remove from scalable directory
if [ -f "$ICONS_DIR/scalable/mimetypes/application-x-linia.svg" ]; then
    rm -f "$ICONS_DIR/scalable/mimetypes/application-x-linia.svg"
    MIME_ICON_REMOVED=1
fi

# Remove alternate naming variants
for icon_name in application-linia gnome-mime-application-x-linia image-x-linia; do
    if [ -f "$ICONS_DIR/scalable/mimetypes/${icon_name}.svg" ]; then
        rm -f "$ICONS_DIR/scalable/mimetypes/${icon_name}.svg"
        MIME_ICON_REMOVED=1
    fi
done

if [ $MIME_ICON_REMOVED -eq 0 ]; then
    echo -e "${YELLOW}No MIME type icons found${NC}"
fi

# Update desktop database
echo -e "${GREEN}Updating desktop database...${NC}"
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null || true
fi

# Update MIME database
echo -e "${GREEN}Updating MIME database...${NC}"
if command -v update-mime-database &> /dev/null; then
    update-mime-database "$HOME/.local/share/mime" 2>/dev/null || true
fi

# Update icon cache
echo -e "${GREEN}Updating icon cache...${NC}"
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t "$ICONS_DIR" 2>/dev/null || true
fi

# Ask about config directory
echo ""
echo -e "${YELLOW}Configuration directory: $CONFIG_DIR${NC}"
echo ""
echo "This directory contains:"
echo "  - Your settings and preferences"
echo "  - Recent files list"
echo "  - Custom icons and SVGs"
echo "  - Thumbnail cache"
echo ""
read -p "Do you want to remove the configuration directory? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "$CONFIG_DIR" ]; then
        echo -e "${GREEN}Removing $CONFIG_DIR...${NC}"
        rm -rf "$CONFIG_DIR"
    else
        echo -e "${YELLOW}Config directory not found${NC}"
    fi
else
    echo -e "${GREEN}Keeping configuration directory${NC}"
    echo "You can manually remove it later with: rm -rf $CONFIG_DIR"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Uninstall Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Linia has been removed from:"
echo "  - Application menu"
echo "  - File associations"
echo "  - System icons"
echo "  - MIME type icons"
echo ""
echo -e "${YELLOW}Note: You may need to log out and log back in for the menu${NC}"
echo -e "${YELLOW}entry to disappear completely from your desktop environment.${NC}"
echo ""
