#!/bin/bash
# Linia Installation Script
# Installs Linia to ~/.local/bin and sets up configuration directory
# Creates desktop integration with menu entry and file associations

# Colors for output (define early for dependency check)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for critical dependencies
echo -e "${GREEN}Checking dependencies...${NC}"
MISSING_DEPS=0
for module in Gtk3 Cairo Pango Image::Magick XML::Simple; do
    if ! perl -M$module -e 1 2>/dev/null; then
        echo -e "${YELLOW}Warning: Perl module $module is missing.${NC}"
        MISSING_DEPS=1
    fi
done

if [ $MISSING_DEPS -eq 1 ]; then
    echo -e "${RED}Some dependencies are missing.${NC}"
    echo "On Debian/Ubuntu/Mint, run:"
    echo "sudo apt install libgtk3-perl libcairo-perl libpango-perl libimage-magick-perl libxml-simple-perl"
    echo ""
    read -p "Continue installation anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

set -e  # Exit on error

echo "========================================="
echo "  Linia Installation Script"
echo "========================================="
echo ""

# Determine script directory (where install.sh is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Installation source: $SCRIPT_DIR"

# Define installation paths
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/linia"
APPLICATIONS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor"
MIME_DIR="$HOME/.local/share/mime/packages"

# Check if linia.pl exists
if [ ! -f "$SCRIPT_DIR/linia.pl" ]; then
    echo -e "${RED}Error: linia.pl not found in $SCRIPT_DIR${NC}"
    echo "Please run this script from the linia directory."
    exit 1
fi

# Create bin directory if it doesn't exist
if [ ! -d "$BIN_DIR" ]; then
    echo -e "${YELLOW}Creating $BIN_DIR...${NC}"
    mkdir -p "$BIN_DIR"
fi

# Install linia.pl to ~/.local/bin
echo -e "${GREEN}Installing linia.pl to $BIN_DIR...${NC}"
cp "$SCRIPT_DIR/linia.pl" "$BIN_DIR/linia"
chmod 755 "$BIN_DIR/linia"

# Create config directory structure
echo -e "${GREEN}Creating configuration directory structure...${NC}"
mkdir -p "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR/callouts"
mkdir -p "$CONFIG_DIR/emojis"
mkdir -p "$CONFIG_DIR/icons/application-icon"
mkdir -p "$CONFIG_DIR/icons/toolbar-icons/white"
mkdir -p "$CONFIG_DIR/icons/toolbar-icons/black"
mkdir -p "$CONFIG_DIR/icons/toolbar-icons/color"
mkdir -p "$CONFIG_DIR/objects"
mkdir -p "$CONFIG_DIR/settings"
mkdir -p "$CONFIG_DIR/svgs"
mkdir -p "$CONFIG_DIR/thumbnails"

# Copy callouts
if [ -d "$SCRIPT_DIR/callouts" ]; then
    echo -e "${GREEN}Copying callouts...${NC}"
    cp -r "$SCRIPT_DIR/callouts/"* "$CONFIG_DIR/callouts/" 2>/dev/null || true
fi

# Copy icons
if [ -d "$SCRIPT_DIR/icons" ]; then
    echo -e "${GREEN}Copying icons...${NC}"
    
    # Copy application icon
    if [ -d "$SCRIPT_DIR/icons/application-icon" ]; then
        cp -r "$SCRIPT_DIR/icons/application-icon/"* "$CONFIG_DIR/icons/application-icon/" 2>/dev/null || true
    fi
    
    # Copy toolbar icons (white, black, color subdirectories)
    if [ -d "$SCRIPT_DIR/icons/toolbar-icons" ]; then
        if [ -d "$SCRIPT_DIR/icons/toolbar-icons/white" ]; then
            cp -r "$SCRIPT_DIR/icons/toolbar-icons/white/"* "$CONFIG_DIR/icons/toolbar-icons/white/" 2>/dev/null || true
        fi
        if [ -d "$SCRIPT_DIR/icons/toolbar-icons/black" ]; then
            cp -r "$SCRIPT_DIR/icons/toolbar-icons/black/"* "$CONFIG_DIR/icons/toolbar-icons/black/" 2>/dev/null || true
        fi
        if [ -d "$SCRIPT_DIR/icons/toolbar-icons/color" ]; then
            cp -r "$SCRIPT_DIR/icons/toolbar-icons/color/"* "$CONFIG_DIR/icons/toolbar-icons/color/" 2>/dev/null || true
        fi
    fi
fi

# Copy objects
if [ -d "$SCRIPT_DIR/objects" ]; then
    echo -e "${GREEN}Copying objects...${NC}"
    cp -r "$SCRIPT_DIR/objects/"* "$CONFIG_DIR/objects/" 2>/dev/null || true
fi

# Copy SVGs
if [ -d "$SCRIPT_DIR/svgs" ]; then
    echo -e "${GREEN}Copying SVG files...${NC}"
    cp -r "$SCRIPT_DIR/svgs/"* "$CONFIG_DIR/svgs/" 2>/dev/null || true
fi

# Set correct permissions
echo -e "${GREEN}Setting permissions...${NC}"
chmod 755 "$CONFIG_DIR"
chmod 755 "$CONFIG_DIR/callouts"
chmod 755 "$CONFIG_DIR/emojis"
chmod 755 "$CONFIG_DIR/icons"
chmod 755 "$CONFIG_DIR/icons/application-icon"
chmod 755 "$CONFIG_DIR/icons/toolbar-icons"
chmod 755 "$CONFIG_DIR/icons/toolbar-icons/white"
chmod 755 "$CONFIG_DIR/icons/toolbar-icons/black"
chmod 755 "$CONFIG_DIR/icons/toolbar-icons/color"
chmod 755 "$CONFIG_DIR/objects"
chmod 755 "$CONFIG_DIR/settings"
chmod 755 "$CONFIG_DIR/svgs"
chmod 755 "$CONFIG_DIR/thumbnails"

# Set file permissions (non-executable for SVGs and config files)
find "$CONFIG_DIR" -type f -name "*.svg" -exec chmod 644 {} \;
find "$CONFIG_DIR" -type f -name "*.json" -exec chmod 644 {} \;
find "$CONFIG_DIR" -type f -name "*.txt" -exec chmod 644 {} \;

# Install application icon
echo -e "${GREEN}Installing application icon...${NC}"
mkdir -p "$ICONS_DIR/scalable/apps"

if [ -f "$CONFIG_DIR/icons/application-icon/linia.svg" ]; then
    cp "$CONFIG_DIR/icons/application-icon/linia.svg" "$ICONS_DIR/scalable/apps/linia.svg"
    chmod 644 "$ICONS_DIR/scalable/apps/linia.svg"
else
    echo -e "${YELLOW}Warning: Application icon not found at $CONFIG_DIR/icons/application-icon/linia.svg${NC}"
fi

# Install MIME type icons for .linia files
echo -e "${GREEN}Installing MIME type icons...${NC}"
if [ -d "$SCRIPT_DIR/icons/mime-icons" ]; then
    # Install to various sizes for better compatibility
    for size in 16 22 24 32 48 64 128 256; do
        mkdir -p "$ICONS_DIR/${size}x${size}/mimetypes"
    done
    mkdir -p "$ICONS_DIR/scalable/mimetypes"
    
    # Copy MIME icons to scalable directory (SVG icons work for all sizes)
    if [ -f "$SCRIPT_DIR/icons/mime-icons/application-x-linia.svg" ]; then
        cp "$SCRIPT_DIR/icons/mime-icons/application-x-linia.svg" "$ICONS_DIR/scalable/mimetypes/"
        chmod 644 "$ICONS_DIR/scalable/mimetypes/application-x-linia.svg"
    fi
    
    # Also copy alternate naming variants if they exist
    for icon_name in application-linia gnome-mime-application-x-linia image-x-linia; do
        if [ -f "$SCRIPT_DIR/icons/mime-icons/${icon_name}.svg" ]; then
            cp "$SCRIPT_DIR/icons/mime-icons/${icon_name}.svg" "$ICONS_DIR/scalable/mimetypes/"
            chmod 644 "$ICONS_DIR/scalable/mimetypes/${icon_name}.svg"
        fi
    done
    
    echo -e "${GREEN}MIME type icons installed${NC}"
else
    echo -e "${YELLOW}Warning: MIME icons directory not found at $SCRIPT_DIR/icons/mime-icons${NC}"
fi

# Create MIME type for .linia files
echo -e "${GREEN}Creating MIME type for .linia files...${NC}"
mkdir -p "$MIME_DIR"

cat > "$MIME_DIR/linia.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-linia-project">
    <comment>Linia Project File</comment>
    <glob pattern="*.linia"/>
    <icon name="application-x-linia"/>
  </mime-type>
</mime-info>
EOF

# Create desktop file
echo -e "${GREEN}Creating desktop menu entry...${NC}"
mkdir -p "$APPLICATIONS_DIR"

cat > "$APPLICATIONS_DIR/linia.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Linia
GenericName=Image Annotator
Comment=Professional image annotation tool for Linux
Exec=$BIN_DIR/linia %F
Icon=linia
Terminal=false
Categories=Graphics;2DGraphics;RasterGraphics;
MimeType=image/png;image/jpeg;image/jpg;image/bmp;image/gif;image/tiff;application/x-linia-project;
Keywords=annotation;screenshot;markup;image;drawing;
StartupNotify=true
EOF

chmod 644 "$APPLICATIONS_DIR/linia.desktop"

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

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo -e "${YELLOW}WARNING: $HOME/.local/bin is not in your PATH${NC}"
    echo "Add the following line to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "Then run: source ~/.bashrc (or source ~/.zshrc)"
    echo ""
fi

# Installation complete
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installation summary:"
echo "  - Executable: $BIN_DIR/linia"
echo "  - Config dir: $CONFIG_DIR"
echo "  - Desktop file: $APPLICATIONS_DIR/linia.desktop"
echo "  - Application icon: $ICONS_DIR/scalable/apps/linia.svg"
echo "  - MIME type icons: $ICONS_DIR/scalable/mimetypes/"
echo "  - MIME type: $MIME_DIR/linia.xml"
echo ""
echo "Linia has been integrated with your desktop environment!"
echo ""
echo "You can now:"
echo "  - Launch Linia from your application menu (Graphics category)"
echo "  - Open images by right-clicking and selecting 'Open with Linia'"
echo "  - Double-click .linia project files to open them"
echo "  - .linia files will display with custom icons in file managers"
echo ""
echo "To run Linia from command line:"
if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    echo "  $ linia"
else
    echo "  $ $BIN_DIR/linia"
    echo "  (or add ~/.local/bin to your PATH as shown above)"
fi
echo ""
echo "To open an image directly:"
echo "  $ linia /path/to/image.png"
echo ""
echo "To open a project file:"
echo "  $ linia /path/to/project.linia"
echo ""
echo -e "${YELLOW}Note: You may need to log out and log back in for the menu${NC}"
echo -e "${YELLOW}entry to appear in some desktop environments.${NC}"
echo ""
