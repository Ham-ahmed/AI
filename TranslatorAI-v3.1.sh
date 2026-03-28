#!/bin/sh
#################################################################
# TranslatorAI Plugin Installer for Enigma2
# Version: 3.1
# Author: HAMDY_AHMED
# Improved: Added Enigma2 restart after successful installation
#################################################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Script configuration
PLUGIN_NAME="TranslatorAI"
VERSION="3.1"
GITHUB_RAW="https://raw.githubusercontent.com/Ham-ahmed/AI/refs/heads/main"
# Try different possible package names
PACKAGE_NAMES="${PLUGIN_NAME}-${VERSION}.tar.gz ${PLUGIN_NAME}.tar.gz ${PLUGIN_NAME}_${VERSION}.tar.gz plugin.tar.gz"
TEMP_DIR="/var/volatile/tmp"
INSTALL_LOG="${TEMP_DIR}/${PLUGIN_NAME}_install.log"
ENIGMA2_PLUGINS_DIR="/usr/lib/enigma2/python/Plugins/Extensions"
PLUGIN_DIR="${ENIGMA2_PLUGINS_DIR}/${PLUGIN_NAME}"
BACKUP_DIR="${TEMP_DIR}/${PLUGIN_NAME}_backup"

# =======================================
# Function: Cleanup temporary files
# =======================================
cleanup() {
    echo -e "${BLUE}▶ Cleaning up temporary files...${NC}"
    # Remove downloaded packages
    for pkg in ${PACKAGE_NAMES}; do
        rm -f "${TEMP_DIR}/${pkg}" 2>/dev/null
    done
    
    # Remove extracted files
    rm -f "${TEMP_DIR}"/*.ipk "${TEMP_DIR}"/*.tar.gz 2>/dev/null
    rm -rf ./CONTROL ./control ./postinst ./preinst ./prerm ./postrm 2>/dev/null
    rm -f "${INSTALL_LOG}" 2>/dev/null
    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# ============================
# Function: Print banner
# ============================
print_banner() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}        ${PLUGIN_NAME} Plugin Installer v${VERSION}              ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    Developer: HAMDY_AHMED                       ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ===========================================
# Function: Check internet connectivity
# ==========================================
check_internet() {
    echo -e "${BLUE}▶ Checking internet connection...${NC}"
    
    local connected=false
    local test_urls="https://github.com https://raw.githubusercontent.com https://google.com"
    
    for url in $test_urls; do
        if [ "${DOWNLOADER}" = "wget" ]; then
            if wget --spider --timeout=5 -q "$url" 2>/dev/null; then
                connected=true
                echo -e "${GREEN}✓ Internet connection OK ($url reachable)${NC}"
                break
            fi
        elif [ "${DOWNLOADER}" = "curl" ]; then
            if curl -s --head --connect-timeout 5 "$url" >/dev/null 2>&1; then
                connected=true
                echo -e "${GREEN}✓ Internet connection OK ($url reachable)${NC}"
                break
            fi
        fi
    done
    
    if [ "$connected" = false ]; then
        echo -e "${RED}✗ No internet connection detected${NC}"
        echo -e "${YELLOW}  Please check your network settings and try again${NC}"
        exit 1
    fi
}

# =======================================
# Function: Check system requirements
# ======================================
check_requirements() {
    echo -e "${BLUE}▶ Checking system requirements...${NC}"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}✗ This script must be run as root${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Root privileges OK${NC}"
    
    # Check Enigma2 environment
    if [ ! -d "/usr/lib/enigma2" ]; then
        echo -e "${YELLOW}⚠ Warning: This doesn't appear to be an Enigma2 device${NC}"
        echo -e "${YELLOW}  Installation may fail${NC}"
        sleep 2
    else
        echo -e "${GREEN}✓ Enigma2 environment detected${NC}"
    fi
    
    # Check available disk space (need at least 10MB)
    AVAILABLE_SPACE=$(df /usr | awk 'NR==2 {print $4}')
    if [ "${AVAILABLE_SPACE}" -lt 10240 ]; then
        echo -e "${RED}✗ Insufficient disk space. Need at least 10MB${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Sufficient disk space available${NC}"
    
    # Check for required download tools
    if command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
        echo -e "${GREEN}✓ Using wget for download${NC}"
    elif command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
        echo -e "${GREEN}✓ Using curl for download${NC}"
    else
        echo -e "${RED}✗ Neither wget nor curl found. Please install one.${NC}"
        exit 1
    fi
    
    # Check internet connectivity
    check_internet
}

# =============================================
# Function: Find and download package
# =============================================
find_and_download_package() {
    echo -e "${BLUE}▶ Searching for ${PLUGIN_NAME} package...${NC}"
    
    local downloaded=false
    local package_found=""
    
    # Try different package names
    for pkg_name in ${PACKAGE_NAMES}; do
        local pkg_url="${GITHUB_RAW}/${pkg_name}"
        local pkg_path="${TEMP_DIR}/${pkg_name}"
        
        echo -e "${YELLOW}  Trying: ${pkg_name}${NC}"
        
        # Check if URL exists
        if [ "${DOWNLOADER}" = "wget" ]; then
            if wget --spider --timeout=5 -q "${pkg_url}" 2>/dev/null; then
                package_found="${pkg_name}"
                echo -e "${GREEN}  ✓ Package found: ${pkg_name}${NC}"
                
                echo -e "${YELLOW}  Downloading...${NC}"
                wget --no-check-certificate \
                     --timeout=20 \
                     --tries=3 \
                     --show-progress \
                     -O "${pkg_path}" \
                     "${pkg_url}" 2>&1
                
                if [ $? -eq 0 ] && [ -s "${pkg_path}" ]; then
                    downloaded=true
                    PACKAGE="${pkg_path}"
                    break
                fi
            fi
        elif [ "${DOWNLOADER}" = "curl" ]; then
            if curl -s --head --connect-timeout 5 "${pkg_url}" | grep -q "200 OK"; then
                package_found="${pkg_name}"
                echo -e "${GREEN}  ✓ Package found: ${pkg_name}${NC}"
                
                echo -e "${YELLOW}  Downloading...${NC}"
                curl -# -L -k --connect-timeout 20 --retry 3 -o "${pkg_path}" "${pkg_url}"
                
                if [ $? -eq 0 ] && [ -s "${pkg_path}" ]; then
                    downloaded=true
                    PACKAGE="${pkg_path}"
                    break
                fi
            fi
        fi
    done
    
    if [ "$downloaded" = false ]; then
        echo -e "${RED}✗ Could not find any package${NC}"
        echo -e "${YELLOW}  Tried names: ${PACKAGE_NAMES}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Download completed successfully${NC}"
    echo -e "  📦 Package: $(basename ${PACKAGE})"
    echo -e "  📊 Size: $(du -h ${PACKAGE} | cut -f1)"
}

# ==============================
# Function: Remove old version
# ==============================
remove_old_version() {
    echo -e "${BLUE}▶ Checking for previous installation...${NC}"
    
    # Check multiple possible locations
    local old_locations="
        ${PLUGIN_DIR}
        /usr/lib/enigma2/python/Plugins/Extensions/${PLUGIN_NAME}
        /home/root/${PLUGIN_NAME}
        /usr/share/enigma2/${PLUGIN_NAME}
    "
    
    local found=false
    
    for loc in $old_locations; do
        if [ -d "$loc" ]; then
            echo -e "${YELLOW}  Found previous installation at: ${loc}${NC}"
            found=true
            
            # Backup configuration if exists
            if [ -f "${loc}/etc/config.xml" ] || [ -f "${loc}/config.xml" ]; then
                echo -e "${BLUE}  Backing up configuration...${NC}"
                mkdir -p "${BACKUP_DIR}"
                
                # Try to find config files
                find "${loc}" -name "*.xml" -o -name "*.conf" -o -name "config.*" 2>/dev/null | while read -r cfg; do
                    rel_path="${cfg#$loc/}"
                    cfg_dir=$(dirname "${rel_path}")
                    mkdir -p "${BACKUP_DIR}/${cfg_dir}"
                    cp -f "$cfg" "${BACKUP_DIR}/${cfg_dir}/" 2>/dev/null
                    echo -e "    Backed up: ${rel_path}"
                done
                
                echo -e "${GREEN}  ✓ Configuration backed up to ${BACKUP_DIR}${NC}"
            fi
            
            # Remove old version
            echo -e "${BLUE}  Removing old version...${NC}"
            rm -rf "$loc"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}  ✓ Removed: ${loc}${NC}"
            else
                echo -e "${RED}  ✗ Failed to remove: ${loc}${NC}"
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo -e "${GREEN}✓ No previous installation found${NC}"
    fi
}

# ==============================
# Function: Install package
# ==============================
install_package() {
    echo -e "${BLUE}▶ Installing ${PLUGIN_NAME}...${NC}"
    
    # Remove any old version
    remove_old_version
    
    # Create plugin directory if it doesn't exist
    mkdir -p "${ENIGMA2_PLUGINS_DIR}"
    
    # Extract package
    echo -e "${BLUE}▶ Extracting files...${NC}"
    
    # First, check what's in the archive
    echo -e "${YELLOW}  Analyzing package contents...${NC}"
    tar -tzf "${PACKAGE}" > "${TEMP_DIR}/package_contents.txt" 2>&1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot read package contents${NC}"
        exit 1
    fi
    
    # Check if package contains the plugin directory structure
    if grep -q "${PLUGIN_NAME}/" "${TEMP_DIR}/package_contents.txt"; then
        echo -e "${GREEN}  Package contains correct directory structure${NC}"
        # Extract directly
        tar -xzf "${PACKAGE}" -C / > "${INSTALL_LOG}" 2>&1
    elif grep -q "^${PLUGIN_NAME}/" "${TEMP_DIR}/package_contents.txt"; then
        echo -e "${GREEN}  Package contains plugin directory at root${NC}"
        # Extract to root
        tar -xzf "${PACKAGE}" -C / > "${INSTALL_LOG}" 2>&1
    else
        echo -e "${YELLOW}  Package doesn't contain plugin directory, creating structure...${NC}"
        # Create temporary extraction directory
        mkdir -p "${TEMP_DIR}/extract"
        tar -xzf "${PACKAGE}" -C "${TEMP_DIR}/extract" > "${INSTALL_LOG}" 2>&1
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ Extraction failed${NC}"
            rm -rf "${TEMP_DIR}/extract"
            exit 1
        fi
        
        # Move contents to plugin directory
        mkdir -p "${PLUGIN_DIR}"
        cp -rf "${TEMP_DIR}/extract"/* "${PLUGIN_DIR}/" 2>/dev/null
        cp -rf "${TEMP_DIR}/extract"/.[!.]* "${PLUGIN_DIR}/" 2>/dev/null
        rm -rf "${TEMP_DIR}/extract"
        echo -e "${GREEN}  ✓ Files organized into plugin directory${NC}"
    fi
    
    # Verify installation
    if [ ! -d "${PLUGIN_DIR}" ]; then
        echo -e "${RED}✗ Installation failed - plugin directory not created${NC}"
        echo -e "${YELLOW}  Expected: ${PLUGIN_DIR}${NC}"
        exit 1
    fi
    
    # Restore configuration if backup exists
    if [ -d "${BACKUP_DIR}" ]; then
        echo -e "${BLUE}▶ Restoring configuration...${NC}"
        cp -rf "${BACKUP_DIR}"/* "${PLUGIN_DIR}/" 2>/dev/null
        echo -e "${GREEN}✓ Configuration restored${NC}"
    fi
    
    # Set proper permissions
    echo -e "${BLUE}▶ Setting permissions...${NC}"
    chmod -R 755 "${PLUGIN_DIR}" 2>/dev/null
    find "${PLUGIN_DIR}" -type f -exec chmod 644 {} \; 2>/dev/null
    find "${PLUGIN_DIR}" -name "*.py" -exec chmod 755 {} \; 2>/dev/null
    find "${PLUGIN_DIR}" -name "*.sh" -exec chmod 755 {} \; 2>/dev/null
    find "${PLUGIN_DIR}" -name "*.so" -exec chmod 755 {} \; 2>/dev/null
    find "${PLUGIN_DIR}" -name "*.bin" -exec chmod 755 {} \; 2>/dev/null
    
    # Run post-installation scripts if exist
    for script in "postinst" "install.sh" "setup.sh"; do
        if [ -f "${PLUGIN_DIR}/${script}" ]; then
            echo -e "${BLUE}▶ Running ${script}...${NC}"
            chmod 755 "${PLUGIN_DIR}/${script}"
            cd "${PLUGIN_DIR}" && ./${script}
        fi
    done
    
    # Check if plugin.py or __init__.py exists
    if [ ! -f "${PLUGIN_DIR}/plugin.py" ] && [ ! -f "${PLUGIN_DIR}/__init__.py" ]; then
        echo -e "${YELLOW}⚠ Warning: plugin.py or __init__.py not found${NC}"
        echo -e "${YELLOW}  The plugin may not work correctly${NC}"
    fi
    
    # Count installed files
    FILE_COUNT=$(find "${PLUGIN_DIR}" -type f | wc -l)
    DIR_COUNT=$(find "${PLUGIN_DIR}" -type d | wc -l)
    echo -e "${GREEN}✓ Installation completed (${FILE_COUNT} files in ${DIR_COUNT} directories)${NC}"
}

# ==========================================
# Function: Display completion message
# ==========================================
show_completion() {
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              ✅ INSTALLATION SUCCESSFUL!                         ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}   Plugin:     ${CYAN}${PLUGIN_NAME}${NC}"
    echo -e "${WHITE}   Version:    ${CYAN}${VERSION}${NC}"
    echo -e "${WHITE}   Location:   ${YELLOW}${PLUGIN_DIR}${NC}"
    echo -e "${WHITE}   Files:      ${YELLOW}$(find ${PLUGIN_DIR} -type f | wc -l) files${NC}"
    echo -e "${WHITE}   Directories:${YELLOW}$(find ${PLUGIN_DIR} -type d | wc -l) dirs${NC}"
    echo -e "${WHITE}   Developer:  ${MAGENTA}HAMDY_AHMED${NC}"
    echo -e "${WHITE}   Facebook:   ${BLUE}https://www.facebook.com/share/g/18qCRuHz26/${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # List important files
    echo -e "${CYAN}📋 Important files:${NC}"
    if [ -f "${PLUGIN_DIR}/plugin.py" ]; then
        echo -e "  ${GREEN}✓${NC} plugin.py (main plugin file)"
    fi
    if [ -f "${PLUGIN_DIR}/__init__.py" ]; then
        echo -e "  ${GREEN}✓${NC} __init__.py"
    fi
    if [ -f "${PLUGIN_DIR}/setup.xml" ]; then
        echo -e "  ${GREEN}✓${NC} setup.xml (configuration)"
    fi
    echo ""
    
    # Show backup info if any
    if [ -d "${BACKUP_DIR}" ]; then
        echo -e "${YELLOW}⚠ Backup folder exists at ${BACKUP_DIR}${NC}"
        echo -e "${WHITE}  You can manually restore files from there if needed${NC}"
        echo -e "${WHITE}  To restore: cp -rf ${BACKUP_DIR}/* ${PLUGIN_DIR}/${NC}"
        echo ""
    fi
}

# ==============================
# Function: Restart Enigma2
# =============================
restart_enigma2() {
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}              🔄 RESTARTING ENIGMA2                             ${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}⏳ Enigma2 will restart in 5 seconds...${NC}"
    echo -e "${WHITE}   Press Ctrl+C to cancel restart${NC}"
    echo ""
    
    # Countdown
    for i in 5 4 3 2 1; do
        echo -ne "\r${YELLOW}   Restarting in ${i} seconds...${NC} "
        sleep 1
    done
    echo ""
    
    echo -e "${BLUE}▶ Restarting Enigma2...${NC}"
    
    # Try different methods to restart Enigma2
    local restarted=false
    
    # Method 1: init (most common in Enigma2)
    if command -v init >/dev/null 2>&1; then
        echo -e "${BLUE}  📡 Using init method...${NC}"
        init 4
        sleep 2
        init 3
        restarted=true
        echo -e "${GREEN}  ✓ Enigma2 restarted successfully using init${NC}"
    fi
    
    # Method 2: systemctl
    if [ "$restarted" = false ] && command -v systemctl >/dev/null 2>&1; then
        echo -e "${BLUE}  📡 Using systemctl method...${NC}"
        systemctl restart enigma2
        restarted=true
        echo -e "${GREEN}  ✓ Enigma2 restarted successfully using systemctl${NC}"
    fi
    
    # Method 3: killall
    if [ "$restarted" = false ] && command -v killall >/dev/null 2>&1; then
        echo -e "${BLUE}  📡 Using killall method...${NC}"
        killall enigma2
        restarted=true
        echo -e "${GREEN}  ✓ Enigma2 restart initiated using killall${NC}"
    fi
    
    # Method 4: init script
    if [ "$restarted" = false ] && [ -f "/etc/init.d/enigma2" ]; then
        echo -e "${BLUE}  📡 Using init script method...${NC}"
        /etc/init.d/enigma2 restart
        restarted=true
        echo -e "${GREEN}  ✓ Enigma2 restarted successfully using init script${NC}"
    fi
    
    # Method 5: wget to webif
    if [ "$restarted" = false ]; then
        echo -e "${BLUE}  📡 Trying web interface...${NC}"
        if command -v wget >/dev/null 2>&1; then
            wget -qO- "http://127.0.0.1/web/powerstate?newstate=3" >/dev/null 2>&1
            restarted=true
            echo -e "${GREEN}  ✓ Enigma2 restart requested via web interface${NC}"
        elif command -v curl >/dev/null 2>&1; then
            curl -s "http://127.0.0.1/web/powerstate?newstate=3" >/dev/null 2>&1
            restarted=true
            echo -e "${GREEN}  ✓ Enigma2 restart requested via web interface${NC}"
        fi
    fi
    
    # Method 6: enigma2 restart command
    if [ "$restarted" = false ] && [ -f "/usr/bin/enigma2" ]; then
        echo -e "${BLUE}  📡 Using enigma2 restart command...${NC}"
        /usr/bin/enigma2 --restart >/dev/null 2>&1
        restarted=true
        echo -e "${GREEN}  ✓ Enigma2 restart initiated${NC}"
    fi
    
    if [ "$restarted" = false ]; then
        echo -e "${RED}  ✗ Could not restart Enigma2 automatically${NC}"
        echo -e "${YELLOW}  ⚠ Please restart Enigma2 manually:${NC}"
        echo -e "${WHITE}    1. Using remote: Menu → Standby/Restart → Restart Enigma2${NC}"
        echo -e "${WHITE}    2. Via Telnet: killall enigma2${NC}"
        echo -e "${WHITE}    3. Via Webif: http://[box-ip]/web/powerstate?newstate=3${NC}"
    else
        echo ""
        echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}              ✅ ENIGMA2 RESTARTED SUCCESSFULLY!                 ${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}   The plugin ${CYAN}${PLUGIN_NAME}${WHITE} should now appear in extensions${NC}"
        echo -e "${WHITE}   Press OK/Blue button to access plugins${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    fi
}

# ==============================
# Function: Ask for restart
# =============================
ask_for_restart() {
    echo ""
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}              🔄 ENIGMA2 RESTART OPTION                          ${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}   To activate the plugin properly, Enigma2 needs to restart${NC}"
    echo -e "${WHITE}   This will reload all plugins and apply changes${NC}"
    echo ""
    echo -e "${CYAN}   Do you want to restart Enigma2 now?${NC}"
    echo -e "${WHITE}   - Press ${GREEN}Y${WHITE} for Yes (recommended)${NC}"
    echo -e "${WHITE}   - Press ${RED}N${WHITE} for No (restart manually later)${NC}"
    echo ""
    echo -e "${YELLOW}   Choice (y/n):${NC} \c"
    
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]|"")
            restart_enigma2
            ;;
        [nN][oO]|[nN])
            echo -e "${BLUE}▶ Restart cancelled by user${NC}"
            echo -e "${WHITE}  Please restart Enigma2 manually to activate the plugin${NC}"
            echo -e "${WHITE}  To restart manually: killall enigma2${NC}"
            echo -e "${WHITE}  Or use: init 4; init 3${NC}"
            ;;
        *)
            echo -e "${RED}  ✗ Invalid choice${NC}"
            echo -e "${YELLOW}  ⚠ Please restart Enigma2 manually to activate the plugin${NC}"
            ;;
    esac
}

# ===============================
# Main installation process
# ===============================
main() {
    # Set trap for cleanup
    trap cleanup EXIT INT TERM
    
    # Print banner
    print_banner
    
    # Check requirements
    check_requirements
    
    # Find and download package
    find_and_download_package
    
    # Install package
    install_package
    
    # Show completion message
    show_completion
    
    # Ask for restart confirmation
    ask_for_restart
    
    # Final cleanup
    echo -e "${BLUE}▶ Final cleanup...${NC}"
    rm -f "${TEMP_DIR}/package_contents.txt" 2>/dev/null
    
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              🎉 INSTALLATION PROCESS COMPLETED!                  ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    
    exit 0
}

# =========================
# Execute main function
# ========================
main "$@"
