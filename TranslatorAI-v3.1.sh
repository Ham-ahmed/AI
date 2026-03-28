#!/bin/sh
#################################################################
# TranslatorAI Plugin Installer for Enigma2
# Version: 3.1
# Author: HAMDY_AHMED
# Modified: Auto-restart after successful installation
# Fixed: Internet check, extraction logic, and error handling
#################################################################

# Color definitions (with fallback for non-tty)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    WHITE='\033[1;37m'
    NC='\033[0m'
else
    RED=''; GREEN=''; BLUE=''; YELLOW=''; CYAN=''; MAGENTA=''; WHITE=''; NC=''
fi

# Script configuration
PLUGIN_NAME="TranslatorAI"
VERSION="3.1"
GITHUB_RAW="https://raw.githubusercontent.com/Ham-ahmed/AI/refs/heads/main"
PACKAGE_NAMES="${PLUGIN_NAME}-${VERSION}.tar.gz ${PLUGIN_NAME}.tar.gz ${PLUGIN_NAME}_${VERSION}.tar.gz plugin.tar.gz"
TEMP_DIR="/var/volatile/tmp"
INSTALL_LOG="${TEMP_DIR}/${PLUGIN_NAME}_install.log"
ENIGMA2_PLUGINS_DIR="/usr/lib/enigma2/python/Plugins/Extensions"
PLUGIN_DIR="${ENIGMA2_PLUGINS_DIR}/${PLUGIN_NAME}"
BACKUP_DIR="${TEMP_DIR}/${PLUGIN_NAME}_backup"
DOWNLOADER=""

# =======================================
# Function: Cleanup temporary files
# =======================================
cleanup() {
    # Remove downloaded packages
    for pkg in ${PACKAGE_NAMES}; do
        [ -f "${TEMP_DIR}/${pkg}" ] && rm -f "${TEMP_DIR}/${pkg}" 2>/dev/null
    done
    
    # Remove extracted files
    rm -f "${TEMP_DIR}"/*.ipk "${TEMP_DIR}"/*.tar.gz 2>/dev/null
    rm -rf "${TEMP_DIR}/extract" 2>/dev/null
    rm -f "${INSTALL_LOG}" 2>/dev/null
    rm -f "${TEMP_DIR}/package_contents.txt" 2>/dev/null
}

# ============================
# Function: Print banner
# ============================
print_banner() {
    clear 2>/dev/null || printf "\n\n"
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
    local connected=false
    local test_urls="https://github.com https://raw.githubusercontent.com https://google.com"
    
    # First determine downloader
    if command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    elif command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    else
        echo -e "${RED}✗ Neither wget nor curl found. Please install one.${NC}"
        exit 1
    fi
    
    for url in $test_urls; do
        if [ "${DOWNLOADER}" = "wget" ]; then
            if wget --spider --timeout=3 -q "$url" 2>/dev/null; then
                connected=true
                break
            fi
        elif [ "${DOWNLOADER}" = "curl" ]; then
            if curl -s --head --connect-timeout 3 -m 5 "$url" >/dev/null 2>&1; then
                connected=true
                break
            fi
        fi
    done
    
    if [ "$connected" = false ]; then
        echo -e "${RED}✗ No internet connection detected${NC}"
        exit 1
    fi
}

# =======================================
# Function: Check system requirements
# ======================================
check_requirements() {
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}✗ This script must be run as root${NC}"
        exit 1
    fi
    
    # Check Enigma2 environment
    if [ ! -d "/usr/lib/enigma2" ]; then
        echo -e "${YELLOW}⚠ Warning: This doesn't appear to be an Enigma2 device${NC}"
        sleep 1
    fi
    
    # Check available disk space (need at least 10MB)
    if [ -d "/usr" ]; then
        AVAILABLE_SPACE=$(df /usr 2>/dev/null | awk 'NR==2 {print $4}')
        if [ -n "${AVAILABLE_SPACE}" ] && [ "${AVAILABLE_SPACE}" -lt 10240 ] 2>/dev/null; then
            echo -e "${RED}✗ Insufficient disk space. Need at least 10MB${NC}"
            exit 1
        fi
    fi
    
    # Check internet connectivity (sets DOWNLOADER)
    check_internet
}

# =============================================
# Function: Find and download package
# =============================================
find_and_download_package() {
    local downloaded=false
    
    # Try different package names
    for pkg_name in ${PACKAGE_NAMES}; do
        local pkg_url="${GITHUB_RAW}/${pkg_name}"
        local pkg_path="${TEMP_DIR}/${pkg_name}"
        
        # Check if URL exists
        if [ "${DOWNLOADER}" = "wget" ]; then
            if wget --spider --timeout=3 -q "${pkg_url}" 2>/dev/null; then
                echo -e "${GREEN}✓ Found: ${pkg_name}${NC}"
                wget --no-check-certificate \
                     --timeout=15 \
                     --tries=2 \
                     -q \
                     -O "${pkg_path}" \
                     "${pkg_url}" 2>/dev/null
                
                if [ $? -eq 0 ] && [ -s "${pkg_path}" ]; then
                    downloaded=true
                    PACKAGE="${pkg_path}"
                    break
                fi
            fi
        elif [ "${DOWNLOADER}" = "curl" ]; then
            if curl -s --head --connect-timeout 3 -m 5 "${pkg_url}" 2>/dev/null | grep -q "200 OK"; then
                echo -e "${GREEN}✓ Found: ${pkg_name}${NC}"
                curl -s -L -k --connect-timeout 15 --retry 2 -o "${pkg_path}" "${pkg_url}"
                
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
        exit 1
    fi
}

# ==============================
# Function: Remove old version
# ==============================
remove_old_version() {
    # Check multiple possible locations
    local old_locations="
        ${PLUGIN_DIR}
        /usr/lib/enigma2/python/Plugins/Extensions/${PLUGIN_NAME}
        /home/root/${PLUGIN_NAME}
        /usr/share/enigma2/${PLUGIN_NAME}
    "
    
    for loc in $old_locations; do
        if [ -d "$loc" ]; then
            # Backup configuration if exists
            if [ -f "${loc}/etc/config.xml" ] || [ -f "${loc}/config.xml" ]; then
                mkdir -p "${BACKUP_DIR}" 2>/dev/null
                
                # Try to find config files
                find "${loc}" -name "*.xml" -o -name "*.conf" -o -name "config.*" 2>/dev/null | while read -r cfg; do
                    rel_path="${cfg#$loc/}"
                    cfg_dir=$(dirname "${rel_path}")
                    mkdir -p "${BACKUP_DIR}/${cfg_dir}" 2>/dev/null
                    cp -f "$cfg" "${BACKUP_DIR}/${cfg_dir}/" 2>/dev/null
                done
            fi
            
            # Remove old version
            rm -rf "$loc" 2>/dev/null
        fi
    done
}

# ==============================
# Function: Install package
# ==============================
install_package() {
    # Remove any old version
    remove_old_version
    
    # Create plugin directory if it doesn't exist
    mkdir -p "${ENIGMA2_PLUGINS_DIR}" 2>/dev/null
    
    # First, check what's in the archive
    tar -tzf "${PACKAGE}" > "${TEMP_DIR}/package_contents.txt" 2>&1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot read package contents${NC}"
        exit 1
    fi
    
    # Create temporary extraction directory
    mkdir -p "${TEMP_DIR}/extract" 2>/dev/null
    rm -rf "${TEMP_DIR}/extract"/* 2>/dev/null
    
    # Extract to temporary directory first
    tar -xzf "${PACKAGE}" -C "${TEMP_DIR}/extract" > "${INSTALL_LOG}" 2>&1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Extraction failed${NC}"
        exit 1
    fi
    
    # Check extracted contents and copy to correct location
    if [ -d "${TEMP_DIR}/extract/${PLUGIN_NAME}" ]; then
        # Package contains plugin directory
        mkdir -p "${PLUGIN_DIR}" 2>/dev/null
        cp -rf "${TEMP_DIR}/extract/${PLUGIN_NAME}"/* "${PLUGIN_DIR}/" 2>/dev/null
    elif [ -d "${TEMP_DIR}/extract/usr/lib/enigma2/python/Plugins/Extensions/${PLUGIN_NAME}" ]; then
        # Package contains full path
        mkdir -p "${ENIGMA2_PLUGINS_DIR}" 2>/dev/null
        cp -rf "${TEMP_DIR}/extract/usr/lib/enigma2/python/Plugins/Extensions/${PLUGIN_NAME}" "${ENIGMA2_PLUGINS_DIR}/" 2>/dev/null
    elif [ -f "${TEMP_DIR}/extract/plugin.py" ] || [ -f "${TEMP_DIR}/extract/__init__.py" ]; then
        # Package contains plugin files directly
        mkdir -p "${PLUGIN_DIR}" 2>/dev/null
        cp -rf "${TEMP_DIR}/extract"/* "${PLUGIN_DIR}/" 2>/dev/null
    else
        # Unknown structure, copy everything
        mkdir -p "${PLUGIN_DIR}" 2>/dev/null
        cp -rf "${TEMP_DIR}/extract"/* "${PLUGIN_DIR}/" 2>/dev/null
    fi
    
    # Clean up temporary extraction
    rm -rf "${TEMP_DIR}/extract" 2>/dev/null
    
    # Verify installation
    if [ ! -d "${PLUGIN_DIR}" ]; then
        echo -e "${RED}✗ Installation failed - plugin directory not created${NC}"
        exit 1
    fi
    
    # Restore configuration if backup exists
    if [ -d "${BACKUP_DIR}" ]; then
        cp -rf "${BACKUP_DIR}"/* "${PLUGIN_DIR}/" 2>/dev/null
        rm -rf "${BACKUP_DIR}" 2>/dev/null
    fi
    
    # Set proper permissions
    chmod -R 755 "${PLUGIN_DIR}" 2>/dev/null
    find "${PLUGIN_DIR}" -type f -exec chmod 644 {} \; 2>/dev/null
    find "${PLUGIN_DIR}" -name "*.py" -exec chmod 755 {} \; 2>/dev/null
    find "${PLUGIN_DIR}" -name "*.sh" -exec chmod 755 {} \; 2>/dev/null
    
    # Run post-installation scripts if exist
    for script in "postinst" "install.sh" "setup.sh"; do
        if [ -f "${PLUGIN_DIR}/${script}" ]; then
            chmod 755 "${PLUGIN_DIR}/${script}" 2>/dev/null
            (cd "${PLUGIN_DIR}" && ./${script}) >/dev/null 2>&1 &
        fi
    done
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
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ==============================
# Function: Restart Enigma2
# =============================
restart_enigma2() {
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}              🔄 RESTARTING ENIGMA2                             ${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local restarted=false
    
    # Method 1: init (most common in Enigma2)
    if command -v init >/dev/null 2>&1; then
        echo -e "${BLUE}  📡 Restarting via init...${NC}"
        init 4 2>/dev/null
        sleep 2
        init 3 2>/dev/null
        restarted=true
    fi
    
    # Method 2: systemctl
    if [ "$restarted" = false ] && command -v systemctl >/dev/null 2>&1; then
        echo -e "${BLUE}  📡 Restarting via systemctl...${NC}"
        systemctl restart enigma2 2>/dev/null
        restarted=true
    fi
    
    # Method 3: killall
    if [ "$restarted" = false ] && command -v killall >/dev/null 2>&1; then
        echo -e "${BLUE}  📡 Restarting via killall...${NC}"
        killall enigma2 2>/dev/null
        restarted=true
    fi
    
    # Method 4: init script
    if [ "$restarted" = false ] && [ -f "/etc/init.d/enigma2" ]; then
        echo -e "${BLUE}  📡 Restarting via init script...${NC}"
        /etc/init.d/enigma2 restart 2>/dev/null
        restarted=true
    fi
    
    # Method 5: web interface
    if [ "$restarted" = false ]; then
        echo -e "${BLUE}  📡 Trying web interface...${NC}"
        if command -v wget >/dev/null 2>&1; then
            wget -qO- "http://127.0.0.1/web/powerstate?newstate=3" >/dev/null 2>&1
            restarted=true
        elif command -v curl >/dev/null 2>&1; then
            curl -s "http://127.0.0.1/web/powerstate?newstate=3" >/dev/null 2>&1
            restarted=true
        fi
    fi
    
    if [ "$restarted" = false ]; then
        echo -e "${RED}  ✗ Could not restart Enigma2 automatically${NC}"
        echo -e "${YELLOW}  ⚠ Please restart Enigma2 manually:${NC}"
        echo -e "${WHITE}    1. Using remote: Menu → Standby/Restart → Restart Enigma2${NC}"
        echo -e "${WHITE}    2. Via Telnet: killall enigma2${NC}"
    else
        echo -e "${GREEN}  ✓ Enigma2 restart initiated successfully${NC}"
        echo ""
        echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}              ✅ ENIGMA2 RESTARTED SUCCESSFULLY!                 ${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}   The plugin ${CYAN}${PLUGIN_NAME}${WHITE} should now appear in extensions${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    fi
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
    
    # Auto restart Enigma2 without any prompts
    restart_enigma2
    
    exit 0
}

# =========================
# Execute main function
# ========================
main "$@"