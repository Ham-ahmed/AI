#!/bin/bash

# ----------------------------------------------------
#   TranslateAI Plugin Installer (Updated & Improved)
# ----------------------------------------------------

PLUGIN_NAME="TranslateAI"
PLUGIN_VERSION="3.1"
PLUGIN_URL="https://raw.githubusercontent.com/Ham-ahmed/AI/refs/heads/main/TranslatorAI.tar.gz"

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
    echo " This script must be run as root. Use: sudo $0"
    exit 1
fi

# Check required commands
for cmd in wget tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo " $cmd is not installed. Aborting."
        exit 1
    fi
done

# Define paths
ZIP_PATH="/tmp/TranslateAI.tar.gz"
EXTRACT_BASE_DIR="/tmp"
EXTRACT_DIR="/tmp/TranslateAI"
INSTALL_DIR="/usr/lib/enigma2/python/Plugins/Extensions"
BACKUP_DIR="/tmp/plugin_backup_$(date +%Y%m%d_%H%M%S)"

# Create download directory
mkdir -p /tmp || {
    echo " Cannot create /tmp directory. Aborting."
    exit 1
}

# ----------------------------------------------
# Step 1: Download the package
# ----------------------------------------------
echo "[1/5] Downloading plugin package..."
echo "    Source: $PLUGIN_URL"
echo "    Destination: $ZIP_PATH"

# Create backup if plugin already exists
if [ -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    echo "    Existing plugin found. Creating backup..."
    mkdir -p "$BACKUP_DIR"
    if cp -r "$INSTALL_DIR/$PLUGIN_NAME" "$BACKUP_DIR/" 2>/dev/null; then
        echo "    Backup created at: $BACKUP_DIR"
    else
        echo "    Warning: Could not create backup"
    fi
fi

# Download attempts
DOWNLOAD_SUCCESS=0
for i in 1 2 3; do
    echo "    Download attempt $i/3..."
    
    # Use wget with improved options
    if wget --no-check-certificate --timeout=30 --tries=1 \
            --show-progress --progress=dot:giga \
            "$PLUGIN_URL" -O "$ZIP_PATH" 2>&1 | \
            grep -q '100%'; then
        DOWNLOAD_SUCCESS=1
        break
    else
        echo "    Download attempt $i failed."
        rm -f "$ZIP_PATH" 2>/dev/null
        if [ $i -eq 3 ]; then
            echo "    All download attempts failed. Please check your internet connection."
            exit 1
        fi
        sleep 2
    fi
done

# Check downloaded file
if [ ! -f "$ZIP_PATH" ]; then
    echo "    Downloaded file is missing. Aborting."
    exit 1
fi

FILE_SIZE=$(stat -c%s "$ZIP_PATH" 2>/dev/null || echo 0)
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "    Downloaded file is too small ($FILE_SIZE bytes). Please check the URL."
    rm -f "$ZIP_PATH"
    exit 1
fi

echo "    Download completed successfully. Size: $FILE_SIZE bytes"

# ----------------------------------------------
# Step 2: Extract files
# ----------------------------------------------
echo "[2/5] Extracting files..."

# Clean old temporary files
rm -rf "$EXTRACT_DIR" 2>/dev/null

# Validate archive
if ! tar -tzf "$ZIP_PATH" >/dev/null 2>&1; then
    echo "    Archive is corrupted or invalid."
    rm -f "$ZIP_PATH"
    exit 1
fi

# Extract archive
if ! tar -xzf "$ZIP_PATH" -C "$EXTRACT_BASE_DIR" 2>/dev/null; then
    echo "    Extraction failed. The archive may be corrupted."
    rm -f "$ZIP_PATH"
    exit 1
fi

# Find main plugin directory
if [ ! -d "$EXTRACT_DIR" ]; then
    EXTRACT_DIR=$(find "$EXTRACT_BASE_DIR" -maxdepth 2 -type d \
        \( -name "*$PLUGIN_NAME*" -o -name "*Translate*" \) | head -1)
    
    if [ -z "$EXTRACT_DIR" ] || [ ! -d "$EXTRACT_DIR" ]; then
        EXTRACT_DIR="/tmp/${PLUGIN_NAME}_extract"
        rm -rf "$EXTRACT_DIR" 2>/dev/null
        mkdir -p "$EXTRACT_DIR"
        if ! tar -xzf "$ZIP_PATH" -C "$EXTRACT_DIR" 2>/dev/null; then
            echo "    Cannot extract plugin files from archive."
            rm -f "$ZIP_PATH"
            rm -rf "$EXTRACT_DIR"
            exit 1
        fi
    fi
fi

if [ ! -d "$EXTRACT_DIR" ] || [ -z "$(ls -A "$EXTRACT_DIR" 2>/dev/null)" ]; then
    echo "    Cannot find plugin files in archive."
    rm -f "$ZIP_PATH"
    exit 1
fi

echo "    Extracted to: $EXTRACT_DIR"

# ----------------------------------------------
# Step 3: Locate plugin files
# ----------------------------------------------
echo "[3/5] Locating plugin files..."

PLUGIN_CONTENT_DIR=""

# Possible plugin paths
possible_paths=(
    "$EXTRACT_DIR/$PLUGIN_NAME"
    "$EXTRACT_DIR/usr/lib/enigma2/python/Plugins/Extensions/$PLUGIN_NAME"
    "$EXTRACT_DIR/Extensions/$PLUGIN_NAME"
    "$EXTRACT_DIR/plugin"
    "$EXTRACT_DIR"
)

for path in "${possible_paths[@]}"; do
    if [ -d "$path" ] && { [ -f "$path/__init__.py" ] || [ -f "$path/plugin.py" ] || [ -f "$path/Plugin.py" ]; }; then
        PLUGIN_CONTENT_DIR="$path"
        echo "    Found plugin structure at: $path"
        break
    fi
done

# Auto-search if path not found
if [ -z "$PLUGIN_CONTENT_DIR" ]; then
    SEARCH_DIR=$(find "$EXTRACT_DIR" -type f \
        \( -name "plugin.py" -o -name "__init__.py" -o -name "Plugin.py" \) \
        -exec dirname {} \; 2>/dev/null | head -1)
    
    if [ -n "$SEARCH_DIR" ]; then
        PLUGIN_CONTENT_DIR="$SEARCH_DIR"
        echo "    Found plugin files at: $PLUGIN_CONTENT_DIR"
    fi
fi

if [ -z "$PLUGIN_CONTENT_DIR" ]; then
    echo "    Cannot locate plugin files in the extracted archive."
    echo "    Archive structure:"
    find "$EXTRACT_DIR" -type f 2>/dev/null | head -20
    rm -rf "$EXTRACT_DIR"
    rm -f "$ZIP_PATH"
    exit 1
fi

# ----------------------------------------------
# Step 4: Install the plugin
# ----------------------------------------------
echo "[4/5] Installing plugin..."

# Create installation directory
mkdir -p "$INSTALL_DIR" || {
    echo "    Cannot create installation directory: $INSTALL_DIR"
    exit 1
}

# Remove old installation
if [ -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    echo "    Removing old installation..."
    rm -rf "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null
fi

# Copy files
echo "    Copying to: $INSTALL_DIR/$PLUGIN_NAME"
if cp -r "$PLUGIN_CONTENT_DIR" "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null; then
    echo "    Files copied successfully."
else
    echo "    Copy failed, trying alternative method..."
    
    # Alternative method using rsync or cpio
    if command -v rsync >/dev/null 2>&1; then
        if rsync -a "$PLUGIN_CONTENT_DIR/" "$INSTALL_DIR/$PLUGIN_NAME/" 2>/dev/null; then
            echo "    Files copied successfully using rsync."
        else
            echo "    Copy failed. Aborting."
            exit 1
        fi
    else
        # Use cpio as last resort
        (cd "$PLUGIN_CONTENT_DIR" && find . -type f -print0 | \
            cpio -p0dum "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null) || {
            echo "    Failed to copy plugin files."
            exit 1
        }
    fi
fi

# Verify installation
if [ ! -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    echo "    Installation failed. Plugin directory not created."
    exit 1
fi

# ----------------------------------------------
# Step 5: Set permissions and cleanup
# ----------------------------------------------
echo "[5/5] Setting permissions and cleaning up..."

# Set directory permissions
find "$INSTALL_DIR/$PLUGIN_NAME" -type d -exec chmod 755 {} \; 2>/dev/null

# Set file permissions
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.py" -exec chmod 644 {} \; 2>/dev/null
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.pyo" -exec chmod 644 {} \; 2>/dev/null
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.pyc" -exec chmod 644 {} \; 2>/dev/null
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null

# Set owner
chown -R root:root "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null

# Clean temporary files
rm -rf "$EXTRACT_DIR" 2>/dev/null
rm -f "$ZIP_PATH" 2>/dev/null

echo "    Permissions set."
echo "    Temporary files cleaned."

# Display installation summary
echo ""
echo "#######################################"
echo "#        INSTALLATION COMPLETE        #"
echo "#######################################"
echo "#         Plugin: $PLUGIN_NAME        #"
echo "#         Version: $PLUGIN_VERSION    #"
echo "# Location: $INSTALL_DIR/$PLUGIN_NAME #"
echo "#######################################"
echo ""

# Display installed file count
FILE_COUNT=$(find "$INSTALL_DIR/$PLUGIN_NAME" -type f 2>/dev/null | wc -l)
echo "Files installed: $FILE_COUNT"
echo ""

# Restart options
echo "###########################################"
echo "#   Plugin installation requires restart  #"
echo "###########################################"
echo ""
echo "Select an option:"
echo "1) Restart Enigma2 now"
echo "2) Restart Enigma2 later"
echo "3) Test plugin without restart (experimental)"
echo ""

# Read choice with default timeout
CHOICE="1"
read -t 30 -p "Enter choice [1-3] (default: 1): " user_choice
if [ -n "$user_choice" ]; then
    CHOICE="$user_choice"
fi

case "$CHOICE" in
    1)
        echo ""
        echo "Restarting Enigma2 in 3 seconds..."
        sleep 3
        
        # Various restart attempts
        echo "Attempting to restart Enigma2..."
        
        if [ -f /etc/init.d/enigma2 ]; then
            /etc/init.d/enigma2 restart && echo "Enigma2 restart initiated via init script."
        elif command -v systemctl >/dev/null 2>&1; then
            systemctl restart enigma2 2>/dev/null && \
                echo "Enigma2 restart initiated via systemctl." || \
                echo "Systemctl restart failed, trying alternative method."
        fi
        
        # Alternative method
        killall -9 enigma2 2>/dev/null
        sleep 2
        if [ -f /usr/bin/enigma2.sh ]; then
            /usr/bin/enigma2.sh >/dev/null 2>&1 &
            echo "Enigma2 started via enigma2.sh script."
        fi
        ;;
    
    2)
        echo ""
        echo "Please restart Enigma2 manually to use the plugin."
        echo ""
        echo "Manual restart methods:"
        echo "  - Via receiver menu: Menu → Standby/Restart → Restart"
        echo "  - Via telnet: init 4 && sleep 2 && init 3"
        echo "  - Via SSH: systemctl restart enigma2"
        ;;
    
    3)
        echo ""
        echo "Experimental: Trying to reload plugins without restart..."
        echo "Note: This may not work on all receivers."
        
        # Try to reload plugins
        if python3 -c "import sys; sys.path.append('/usr/lib/enigma2/python');" 2>/dev/null; then
            echo "Python environment check passed."
            # Plugin reload code can be added here
        else
            echo "Python environment not available for plugin reload."
        fi
        
        echo ""
        echo "For full functionality, please restart Enigma2."
        ;;
    
    *)
        echo "Invalid choice. No restart initiated."
        ;;
esac

# Final message
echo ""
echo "######################################"
echo "#   Installation process completed!  #"
echo "######################################"

if [ -d "$BACKUP_DIR" ] && [ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo ""
    echo "Backup of previous version saved at:"
    echo "  $BACKUP_DIR"
    echo "To restore: cp -r \"$BACKUP_DIR/$PLUGIN_NAME\" \"$INSTALL_DIR/\""
fi

echo ""
echo "Thank you for installing TranslateAI plugin!"
exit 0