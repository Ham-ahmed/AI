#!/bin/bash
# ----------------------------------------------------
#   TranslateAI Plugin Installer (Enhanced & Robust)
# ----------------------------------------------------

set -e  # Exit on error
set -o pipefail  # Catch pipe failures

PLUGIN_NAME="TranslateAI"
PLUGIN_VERSION="3.1"
PLUGIN_URL="https://raw.githubusercontent.com/Ham-ahmed/AI/refs/heads/main/TranslatorAI.tar.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Display header
clear
echo ""
echo "#######################################"
echo "      TranslateAI Plugin Installer     "
echo "#######################################"
echo "    This script will install the       "
echo "         plugin TranslateAI            "
echo "  on your Enigma2-based receiver.      "
echo "                                       "
echo "      Version   : $PLUGIN_VERSION      "
echo "    Developer : H-Ahmed                "
echo "#######################################"
echo ""

# Check user permissions
if [ "$(id -u)" != "0" ]; then
    log_error "This script must be run as root. Use: sudo $0"
    exit 1
fi

# Check required commands
MISSING_CMDS=""
for cmd in wget tar grep find stat; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_CMDS="$MISSING_CMDS $cmd"
    fi
done

if [ -n "$MISSING_CMDS" ]; then
    log_error "Missing required commands:$MISSING_CMDS"
    exit 1
fi

# Detect correct installation path
detect_install_dir() {
    local possible_paths=(
        "/usr/lib/enigma2/python/Plugins/Extensions"
        "/usr/local/lib/enigma2/python/Plugins/Extensions"
        "/usr/lib64/enigma2/python/Plugins/Extensions"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -d "$(dirname "$(dirname "$path")")" ] 2>/dev/null; then
            echo "$path"
            return 0
        fi
    done
    
    # Default path if detection fails
    echo "/usr/lib/enigma2/python/Plugins/Extensions"
}

# Define paths
TARBALL_PATH="/tmp/TranslateAI_${PLUGIN_VERSION}_$$.tar.gz"
EXTRACT_DIR="/tmp/TranslateAI_extract_$$"
INSTALL_DIR=$(detect_install_dir)
BACKUP_DIR="/tmp/plugin_backup_$(date +%Y%m%d_%H%M%S)"

log_info "Using installation directory: $INSTALL_DIR"

# Create necessary directories
mkdir -p "$EXTRACT_DIR" || {
    log_error "Cannot create temporary directory"
    exit 1
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$EXTRACT_DIR" 2>/dev/null
    rm -f "$TARBALL_PATH" 2>/dev/null
}
trap cleanup EXIT

# ----------------------------------------------
# Step 1: Download the package
# ----------------------------------------------
log_step "1/5: Downloading plugin package..."
echo "    Source: $PLUGIN_URL"
echo "    Destination: $TARBALL_PATH"

# Create backup if plugin already exists
if [ -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    log_warning "Existing plugin found. Creating backup..."
    mkdir -p "$BACKUP_DIR"
    if cp -r "$INSTALL_DIR/$PLUGIN_NAME" "$BACKUP_DIR/" 2>/dev/null; then
        log_info "Backup created at: $BACKUP_DIR"
    else
        log_warning "Could not create backup, continuing anyway"
    fi
fi

# Download with retry logic
DOWNLOAD_SUCCESS=false
for i in {1..3}; do
    echo "    Download attempt $i/3..."
    
    # Improved download with proper exit code checking
    if wget --no-check-certificate --timeout=30 --tries=1 \
            --progress=dot:giga \
            "$PLUGIN_URL" -O "$TARBALL_PATH" 2>&1; then
        
        # Check if file exists and has content
        if [ -f "$TARBALL_PATH" ] && [ -s "$TARBALL_PATH" ]; then
            DOWNLOAD_SUCCESS=true
            break
        fi
    fi
    
    log_warning "Download attempt $i failed"
    rm -f "$TARBALL_PATH" 2>/dev/null
    sleep 3
done

if [ "$DOWNLOAD_SUCCESS" = false ]; then
    log_error "Failed to download plugin after 3 attempts"
    exit 1
fi

# Verify download size
if command -v stat >/dev/null 2>&1; then
    FILE_SIZE=$(stat -c%s "$TARBALL_PATH" 2>/dev/null || echo "0")
else
    FILE_SIZE=$(wc -c < "$TARBALL_PATH" 2>/dev/null || echo "0")
fi

if [ "$FILE_SIZE" -lt 5000 ]; then
    log_error "Downloaded file is too small ($FILE_SIZE bytes). URL may be invalid."
    exit 1
fi

log_info "Download completed successfully ($FILE_SIZE bytes)"

# ----------------------------------------------
# Step 2: Validate and extract archive
# ----------------------------------------------
log_step "2/5: Validating and extracting archive..."

# Validate archive integrity
if ! tar -tzf "$TARBALL_PATH" >/dev/null 2>&1; then
    log_error "Archive is corrupted or invalid"
    exit 1
fi

# Extract archive
if ! tar -xzf "$TARBALL_PATH" -C "$EXTRACT_DIR" 2>/dev/null; then
    log_error "Extraction failed"
    exit 1
fi

log_info "Extracted to: $EXTRACT_DIR"

# ----------------------------------------------
# Step 3: Locate plugin structure
# ----------------------------------------------
log_step "3/5: Locating plugin files..."

# Function to find plugin directory
find_plugin_dir() {
    local search_dir="$1"
    
    # Look for typical Enigma2 plugin structure
    local plugin_path=$(find "$search_dir" -type f \( -name "plugin.py" -o -name "__init__.py" \) 2>/dev/null | \
        head -1 | xargs dirname 2>/dev/null)
    
    if [ -n "$plugin_path" ] && [ -d "$plugin_path" ]; then
        echo "$plugin_path"
        return 0
    fi
    
    # Look for directory matching plugin name
    plugin_path=$(find "$search_dir" -type d -name "$PLUGIN_NAME" 2>/dev/null | head -1)
    if [ -n "$plugin_path" ] && [ -d "$plugin_path" ]; then
        echo "$plugin_path"
        return 0
    fi
    
    # Check if extract directory itself contains plugin files
    if [ -f "$search_dir/plugin.py" ] || [ -f "$search_dir/__init__.py" ]; then
        echo "$search_dir"
        return 0
    fi
    
    return 1
}

PLUGIN_CONTENT_DIR=$(find_plugin_dir "$EXTRACT_DIR")

if [ -z "$PLUGIN_CONTENT_DIR" ]; then
    log_error "Cannot locate plugin files in extracted archive"
    echo "Archive contents:"
    find "$EXTRACT_DIR" -type f 2>/dev/null | head -20
    exit 1
fi

log_info "Found plugin at: $PLUGIN_CONTENT_DIR"

# Verify plugin structure
if [ ! -f "$PLUGIN_CONTENT_DIR/plugin.py" ] && [ ! -f "$PLUGIN_CONTENT_DIR/__init__.py" ]; then
    log_warning "Plugin directory doesn't contain standard plugin files"
    echo "Files found:"
    ls -la "$PLUGIN_CONTENT_DIR" 2>/dev/null | head -10
fi

# ----------------------------------------------
# Step 4: Install the plugin
# ----------------------------------------------
log_step "4/5: Installing plugin..."

# Create installation directory
mkdir -p "$INSTALL_DIR" || {
    log_error "Cannot create installation directory: $INSTALL_DIR"
    exit 1
}

# Remove old installation
if [ -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    log_info "Removing old installation..."
    rm -rf "$INSTALL_DIR/$PLUGIN_NAME" || {
        log_error "Failed to remove old installation"
        exit 1
    }
fi

# Copy files
log_info "Copying plugin to: $INSTALL_DIR/$PLUGIN_NAME"

if cp -r "$PLUGIN_CONTENT_DIR" "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null; then
    log_info "Files copied successfully"
else
    log_error "Failed to copy plugin files"
    exit 1
fi

# Verify installation
if [ ! -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    log_error "Installation failed - plugin directory not created"
    exit 1
fi

# Count installed files
INSTALLED_COUNT=$(find "$INSTALL_DIR/$PLUGIN_NAME" -type f 2>/dev/null | wc -l)
if [ "$INSTALLED_COUNT" -eq 0 ]; then
    log_error "No files were installed"
    exit 1
fi

log_info "Installed $INSTALLED_COUNT files"

# ----------------------------------------------
# Step 5: Set permissions and finalize
# ----------------------------------------------
log_step "5/5: Setting permissions and finalizing..."

# Set proper permissions
chmod 755 "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null || true
find "$INSTALL_DIR/$PLUGIN_NAME" -type d -exec chmod 755 {} \; 2>/dev/null || true
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.py*" -exec chmod 644 {} \; 2>/dev/null || true
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null || true
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true

# Set ownership (ignore errors if not possible)
chown -R root:root "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null || true

log_info "Permissions set successfully"

# ----------------------------------------------
# Installation Summary
# ----------------------------------------------
echo ""
echo "#######################################"
echo "#        INSTALLATION COMPLETE        #"
echo "#######################################"
echo "#         Plugin: $PLUGIN_NAME        #"
echo "#         Version: $PLUGIN_VERSION    #"
echo "#         Files installed: $INSTALLED_COUNT"
echo "# Location: $INSTALL_DIR/$PLUGIN_NAME #"
echo "#######################################"
echo ""

# Check for potential issues
if [ ! -f "$INSTALL_DIR/$PLUGIN_NAME/plugin.py" ] && [ ! -f "$INSTALL_DIR/$PLUGIN_NAME/__init__.py" ]; then
    log_warning "Plugin may not be properly formatted for Enigma2"
    echo "Missing plugin.py or __init__.py file"
fi

# ----------------------------------------------
# Restart Options
# ----------------------------------------------
echo "###########################################"
echo "#   Plugin installation requires restart  #"
echo "###########################################"
echo ""
echo "Select an option:"
echo "1) Restart Enigma2 now"
echo "2) Restart Enigma2 later"
echo ""

read -t 30 -p "Enter choice [1-2] (default: 1): " CHOICE
CHOICE=${CHOICE:-1}

case "$CHOICE" in
    1)
        echo ""
        log_info "Restarting Enigma2..."
        sleep 2
        
        # Try multiple restart methods
        RESTART_SUCCESS=false
        
        # Check if enigma2 is running
        if ! pgrep -x "enigma2" >/dev/null 2>&1; then
            log_warning "Enigma2 is not running, starting it..."
            RESTART_SUCCESS=true
        fi
        
        # Method 1: Init script
        if [ "$RESTART_SUCCESS" = false ] && [ -f /etc/init.d/enigma2 ]; then
            log_info "Using init script..."
            /etc/init.d/enigma2 restart 2>/dev/null && RESTART_SUCCESS=true
        fi
        
        # Method 2: Systemctl
        if [ "$RESTART_SUCCESS" = false ] && command -v systemctl >/dev/null 2>&1; then
            log_info "Using systemctl..."
            systemctl restart enigma2 2>/dev/null && RESTART_SUCCESS=true
        fi
        
        # Method 3: Traditional method
        if [ "$RESTART_SUCCESS" = false ]; then
            log_info "Using traditional method..."
            killall -9 enigma2 2>/dev/null || true
            sleep 2
            if [ -f /usr/bin/enigma2.sh ]; then
                /usr/bin/enigma2.sh >/dev/null 2>&1 &
                RESTART_SUCCESS=true
            elif [ -f /usr/bin/enigma2 ]; then
                /usr/bin/enigma2 >/dev/null 2>&1 &
                RESTART_SUCCESS=true
            fi
        fi
        
        if [ "$RESTART_SUCCESS" = true ]; then
            log_info "Enigma2 restart initiated"
        else
            log_warning "Could not restart Enigma2 automatically"
            echo "Please restart manually using: init 4 && sleep 2 && init 3"
        fi
        ;;
    
    2)
        echo ""
        log_info "Please restart Enigma2 manually to use the plugin"
        echo ""
        echo "Manual restart methods:"
        echo "  • Via receiver menu: Menu → Standby/Restart → Restart"
        echo "  • Via command line: init 4 && sleep 2 && init 3"
        echo "  • Via systemctl: systemctl restart enigma2"
        ;;
    
    *)
        log_warning "Invalid choice. No restart initiated"
        ;;
esac

# Display backup info if exists
if [ -d "$BACKUP_DIR" ] && [ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo ""
    log_info "Backup of previous version saved at:"
    echo "  $BACKUP_DIR"
    echo "To restore: cp -r \"$BACKUP_DIR/$PLUGIN_NAME\" \"$INSTALL_DIR/\""
fi

echo ""
log_info "Installation completed successfully!"
echo "Thank you for installing TranslateAI plugin!"
exit 0