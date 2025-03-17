#!/bin/bash
set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
CERTS_DIR="./certs"
KEYSTORE_SECRET_FILE="keystore_key.secret"
ENV_FILE=".env"
ENV_EXAMPLE_FILE=".env.example"

# Function to generate a random password (alphanumeric only)
generate_password() {
    # Generate a random alphanumeric password (no special characters)
    cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1
}

# Function to check if .env file exists and create it if it doesn't
check_env_file() {
    # Generate random passwords for new installations
    POSTGRES_PASSWORD=$(generate_password)
    ADMIN_USERNAME="admin"
    ADMIN_PASSWORD=$(generate_password)
    
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${YELLOW}⚠️  No .env file found. Creating one from example or from scratch...${NC}"
        
        if [[ -f "$ENV_EXAMPLE_FILE" ]]; then
            echo -e "${BLUE}📝 Creating .env file from example...${NC}"
            # Copy the example file but replace the passwords with generated ones
            cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
            
            # Update the passwords in the .env file
            TMP_ENV_FILE="${ENV_FILE}.tmp"
            sed "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
            sed "s|KC_BOOTSTRAP_ADMIN_USERNAME=.*|KC_BOOTSTRAP_ADMIN_USERNAME=\"$ADMIN_USERNAME\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
            sed "s|KC_BOOTSTRAP_ADMIN_PASSWORD=.*|KC_BOOTSTRAP_ADMIN_PASSWORD=\"$ADMIN_PASSWORD\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
        else
            echo -e "${BLUE}📝 Creating new .env file...${NC}"
            cat > "$ENV_FILE" << EOF
# Database Configuration
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"

# Keycloak Admin Credentials
KC_BOOTSTRAP_ADMIN_USERNAME="$ADMIN_USERNAME"
KC_BOOTSTRAP_ADMIN_PASSWORD="$ADMIN_PASSWORD"

# Keycloak FQDN (required for Keycloak and Certs generation)
KEYCLOAK_DOMAIN="auth.domain.tld"

# Certificate Generation Settings (adjust)
KEYCLOAK_IP="10.2.20.50"
KEYCLOAK_ADMIN_EMAIL="admin@example.com"
KEYCLOAK_ORGANIZATION="Example Org"
KEYCLOAK_ORG_UNIT="Cloud Infrastructure"

# Certificate Validity (Days)
CERT_VALIDITY_DAYS="3650"
EOF
        fi
        
        # Read current values from the newly created .env file safely
        # Instead of sourcing, which can fail if there are spaces or errors,
        # we'll read the variables explicitly
        if [[ -f "$ENV_FILE" ]]; then
            # Read variables safely using grep and cut
            KEYCLOAK_DOMAIN=$(grep -E "^KEYCLOAK_DOMAIN=" "$ENV_FILE" | cut -d'"' -f2 || echo "auth.domain.tld")
            KEYCLOAK_IP=$(grep -E "^KEYCLOAK_IP=" "$ENV_FILE" | cut -d'"' -f2 || echo "10.2.20.50")
            KEYCLOAK_ADMIN_EMAIL=$(grep -E "^KEYCLOAK_ADMIN_EMAIL=" "$ENV_FILE" | cut -d'"' -f2 || echo "admin@example.com")
            KEYCLOAK_ORGANIZATION=$(grep -E "^KEYCLOAK_ORGANIZATION=" "$ENV_FILE" | cut -d'"' -f2 || echo "Example Org")
            KEYCLOAK_ORG_UNIT=$(grep -E "^KEYCLOAK_ORG_UNIT=" "$ENV_FILE" | cut -d'"' -f2 || echo "Cloud Infrastructure")
            CERT_VALIDITY_DAYS=$(grep -E "^CERT_VALIDITY_DAYS=" "$ENV_FILE" | cut -d'"' -f2 || echo "3650")
        fi
        
        # New installation - always prompt for all values
        echo -e "${BLUE}📝 Please provide values for the following variables:${NC}"
        
        # Always require a valid domain
        while true; do
            read -p "Keycloak Domain: " new_domain
            if [[ -z "$new_domain" ]]; then
                echo -e "${RED}❌ Keycloak Domain is required and cannot be empty.${NC}"
            else
                KEYCLOAK_DOMAIN=$new_domain
                break
            fi
        done
        
        # No longer prompting for Keycloak version - using latest
        
        # Prompt for each variable with validation
        read -p "Keycloak IP: " new_ip
        if [[ -n "$new_ip" ]]; then
            KEYCLOAK_IP=$new_ip
        else
            echo -e "${YELLOW}⚠️  Using default IP: $KEYCLOAK_IP${NC}"
        fi
        
        read -p "Admin Email: " new_email
        if [[ -n "$new_email" ]]; then
            KEYCLOAK_ADMIN_EMAIL=$new_email
        else
            echo -e "${YELLOW}⚠️  Using default email: $KEYCLOAK_ADMIN_EMAIL${NC}"
        fi
        
        read -p "Organization: " new_org
        if [[ -n "$new_org" ]]; then
            KEYCLOAK_ORGANIZATION=$new_org
        else
            echo -e "${YELLOW}⚠️  Using default organization: $KEYCLOAK_ORGANIZATION${NC}"
        fi
        
        read -p "Organizational Unit: " new_unit
        if [[ -n "$new_unit" ]]; then
            KEYCLOAK_ORG_UNIT=$new_unit
        else
            echo -e "${YELLOW}⚠️  Using default organizational unit: $KEYCLOAK_ORG_UNIT${NC}"
        fi
        
        # Update the .env file with new values - using portable sed syntax
        # Create a temporary file
        TMP_ENV_FILE="${ENV_FILE}.tmp"
        
        # Use sed with a temporary file (works on both Linux and macOS)
        sed "s|KEYCLOAK_DOMAIN=.*|KEYCLOAK_DOMAIN=\"$KEYCLOAK_DOMAIN\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
        sed "s|KEYCLOAK_IP=.*|KEYCLOAK_IP=\"$KEYCLOAK_IP\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
        sed "s|KEYCLOAK_ADMIN_EMAIL=.*|KEYCLOAK_ADMIN_EMAIL=\"$KEYCLOAK_ADMIN_EMAIL\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
        sed "s|KEYCLOAK_ORGANIZATION=.*|KEYCLOAK_ORGANIZATION=\"$KEYCLOAK_ORGANIZATION\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
        sed "s|KEYCLOAK_ORG_UNIT=.*|KEYCLOAK_ORG_UNIT=\"$KEYCLOAK_ORG_UNIT\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
        
        # Remove backup file
        rm -f "$ENV_FILE.bak"
        
        echo -e "${GREEN}✅ .env file created with the following credentials:${NC}"
        echo -e "${YELLOW}PostgreSQL Password: $POSTGRES_PASSWORD${NC}"
        echo -e "${YELLOW}Admin Username: $ADMIN_USERNAME${NC}"
        echo -e "${YELLOW}Admin Password: $ADMIN_PASSWORD${NC}"
        echo -e "${GREEN}✅ Make sure to save these credentials!${NC}"
    else
        # Existing .env file - ask user if they want to review/update values
        echo -e "${GREEN}✅ .env file already exists.${NC}"
        
        # Read variables from the existing .env file safely
        if [[ -f "$ENV_FILE" ]]; then
            # Read variables safely using grep and cut
            KEYCLOAK_DOMAIN=$(grep -E "^KEYCLOAK_DOMAIN=" "$ENV_FILE" | cut -d'"' -f2 || echo "auth.domain.tld")
            KEYCLOAK_IP=$(grep -E "^KEYCLOAK_IP=" "$ENV_FILE" | cut -d'"' -f2 || echo "10.2.20.50")
            KEYCLOAK_ADMIN_EMAIL=$(grep -E "^KEYCLOAK_ADMIN_EMAIL=" "$ENV_FILE" | cut -d'"' -f2 || echo "admin@example.com")
            KEYCLOAK_ORGANIZATION=$(grep -E "^KEYCLOAK_ORGANIZATION=" "$ENV_FILE" | cut -d'"' -f2 || echo "Example Org")
            KEYCLOAK_ORG_UNIT=$(grep -E "^KEYCLOAK_ORG_UNIT=" "$ENV_FILE" | cut -d'"' -f2 || echo "Cloud Infrastructure")
            CERT_VALIDITY_DAYS=$(grep -E "^CERT_VALIDITY_DAYS=" "$ENV_FILE" | cut -d'"' -f2 || echo "3650")
        fi
        
        # Show current values and ask if they want to update
        echo -e "${BLUE}Current configuration:${NC}"
        echo -e "Keycloak Domain: ${YELLOW}$KEYCLOAK_DOMAIN${NC}"
        echo -e "Keycloak IP: ${YELLOW}$KEYCLOAK_IP${NC}"
        echo -e "Admin Email: ${YELLOW}$KEYCLOAK_ADMIN_EMAIL${NC}"
        echo -e "Organization: ${YELLOW}$KEYCLOAK_ORGANIZATION${NC}"
        echo -e "Organizational Unit: ${YELLOW}$KEYCLOAK_ORG_UNIT${NC}"
        
        read -p "Do you want to update these values? (y/n): " update_choice
        if [[ "$update_choice" == "y" || "$update_choice" == "Y" ]]; then
            # Always require a valid domain
            while true; do
                read -p "Keycloak Domain [$KEYCLOAK_DOMAIN]: " new_domain
                if [[ -n "$new_domain" ]]; then
                    KEYCLOAK_DOMAIN=$new_domain
                    break
                elif [[ -n "$KEYCLOAK_DOMAIN" ]]; then
                    # Keep existing value
                    break
                else
                    echo -e "${RED}❌ Keycloak Domain is required and cannot be empty.${NC}"
                fi
            done
            
            # No longer prompting for Keycloak version - using latest
            
            read -p "Keycloak IP [$KEYCLOAK_IP]: " new_ip
            if [[ -n "$new_ip" ]]; then
                KEYCLOAK_IP=$new_ip
            fi
            
            read -p "Admin Email [$KEYCLOAK_ADMIN_EMAIL]: " new_email
            if [[ -n "$new_email" ]]; then
                KEYCLOAK_ADMIN_EMAIL=$new_email
            fi
            
            read -p "Organization [$KEYCLOAK_ORGANIZATION]: " new_org
            if [[ -n "$new_org" ]]; then
                KEYCLOAK_ORGANIZATION=$new_org
            fi
            
            read -p "Organizational Unit [$KEYCLOAK_ORG_UNIT]: " new_unit
            if [[ -n "$new_unit" ]]; then
                KEYCLOAK_ORG_UNIT=$new_unit
            fi
            
            # Update the .env file with new values - using portable sed syntax
            # Create a temporary file
            TMP_ENV_FILE="${ENV_FILE}.tmp"
            
            # Use sed with a temporary file (works on both Linux and macOS)
            sed "s|KEYCLOAK_DOMAIN=.*|KEYCLOAK_DOMAIN=\"$KEYCLOAK_DOMAIN\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
            
            # No longer updating Keycloak version - using latest
            
            sed "s|KEYCLOAK_IP=.*|KEYCLOAK_IP=\"$KEYCLOAK_IP\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
            sed "s|KEYCLOAK_ADMIN_EMAIL=.*|KEYCLOAK_ADMIN_EMAIL=\"$KEYCLOAK_ADMIN_EMAIL\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
            sed "s|KEYCLOAK_ORGANIZATION=.*|KEYCLOAK_ORGANIZATION=\"$KEYCLOAK_ORGANIZATION\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
            sed "s|KEYCLOAK_ORG_UNIT=.*|KEYCLOAK_ORG_UNIT=\"$KEYCLOAK_ORG_UNIT\"|g" "$ENV_FILE" > "$TMP_ENV_FILE" && mv "$TMP_ENV_FILE" "$ENV_FILE"
            
            echo -e "${GREEN}✅ .env file updated.${NC}"
        else
            echo -e "${GREEN}✅ Using existing values.${NC}"
        fi
    fi
}

# Function to check if certificates exist and generate them if they don't
check_certificates() {
    if [[ ! -f "$CERTS_DIR/server.crt" || ! -f "$CERTS_DIR/server.key" || ! -f "$CERTS_DIR/server.keystore" ]]; then
        echo -e "${YELLOW}⚠️  Certificates not found. Generating new certificates...${NC}"
        ./generate_certs.sh
        echo -e "${GREEN}✅ Certificates generated.${NC}"
    else
        echo -e "${GREEN}✅ Certificates already exist.${NC}"
    fi
}

# Function to perform a clean installation
clean_install() {
    local with_keywind=$1
    
    echo -e "${BLUE}🚀 Starting clean installation...${NC}"
    
    # Check if .env file exists and create it if it doesn't
    check_env_file
    
    # Check if certificates exist and generate them if they don't
    check_certificates
    
    # Build and start the services
    if [[ "$with_keywind" == "yes" ]]; then
        echo -e "${BLUE}🔨 Building Keycloak with Keywind theme...${NC}"
        docker compose -f docker-compose.yaml -f docker-compose.keywind.yaml build
        echo -e "${BLUE}🚀 Starting Keycloak with Keywind theme...${NC}"
        docker compose -f docker-compose.yaml -f docker-compose.keywind.yaml up -d
    else
        echo -e "${BLUE}🔨 Building Keycloak without Keywind theme...${NC}"
        docker compose build
        echo -e "${BLUE}🚀 Starting Keycloak...${NC}"
        docker compose up -d
    fi
    
    echo -e "${GREEN}✅ Installation complete!${NC}"
}

# Function to perform a reinstallation
reinstall() {
    local with_keywind=$1
    local recreate_certs=$2
    
    echo -e "${BLUE}🚀 Starting reinstallation...${NC}"
    
    # Stop and remove containers
    echo -e "${BLUE}🛑 Stopping and removing containers...${NC}"
    docker compose down
    
    # Remove volumes
    echo -e "${BLUE}🗑️  Removing volumes...${NC}"
    docker volume rm keycloak-postgres-data || echo -e "${YELLOW}⚠️  Volume not found, continuing...${NC}"
    
    # Remove images
    echo -e "${BLUE}🗑️  Removing images...${NC}"
    docker rmi petesmarttech/keycloak:latest || echo -e "${YELLOW}⚠️  Image not found, continuing...${NC}"
    
    # Recreate certificates if requested
    if [[ "$recreate_certs" == "yes" ]]; then
        echo -e "${BLUE}🗑️  Removing old certificates...${NC}"
        rm -rf "$CERTS_DIR"
        rm -f "$KEYSTORE_SECRET_FILE"
        echo -e "${BLUE}🔄 Generating new certificates...${NC}"
        ./generate_certs.sh
        echo -e "${GREEN}✅ Certificates regenerated.${NC}"
    fi
    
    # Build and start the services
    if [[ "$with_keywind" == "yes" ]]; then
        echo -e "${BLUE}🔨 Building Keycloak with Keywind theme...${NC}"
        docker compose -f docker-compose.yaml -f docker-compose.keywind.yaml build
        echo -e "${BLUE}🚀 Starting Keycloak with Keywind theme...${NC}"
        docker compose -f docker-compose.yaml -f docker-compose.keywind.yaml up -d
    else
        echo -e "${BLUE}🔨 Building Keycloak without Keywind theme...${NC}"
        docker compose build
        echo -e "${BLUE}🚀 Starting Keycloak...${NC}"
        docker compose up -d
    fi
    
    echo -e "${GREEN}✅ Reinstallation complete!${NC}"
}

# Main menu
show_menu() {
    echo -e "${BLUE}=== Keycloak Installation Menu ===${NC}"
    echo -e "${BLUE}1. First Install${NC}"
    echo -e "${BLUE}2. Re-install (remove everything and recreate)${NC}"
    echo -e "${BLUE}3. Exit${NC}"
    read -p "Select an option [1-3]: " menu_option
    
    case $menu_option in
        1)
            echo -e "${BLUE}=== Theme Selection ===${NC}"
            echo -e "${BLUE}1. Install without Keywind theme${NC}"
            echo -e "${BLUE}2. Install with Keywind theme${NC}"
            read -p "Select an option [1-2]: " theme_option
            
            if [[ "$theme_option" == "1" ]]; then
                clean_install "no"
            elif [[ "$theme_option" == "2" ]]; then
                clean_install "yes"
            else
                echo -e "${RED}❌ Invalid option. Exiting.${NC}"
                exit 1
            fi
            ;;
        2)
            echo -e "${BLUE}=== Theme Selection ===${NC}"
            echo -e "${BLUE}1. Reinstall without Keywind theme${NC}"
            echo -e "${BLUE}2. Reinstall with Keywind theme${NC}"
            read -p "Select an option [1-2]: " theme_option
            
            echo -e "${BLUE}=== Certificate Recreation ===${NC}"
            echo -e "${BLUE}1. Keep existing certificates${NC}"
            echo -e "${BLUE}2. Recreate certificates${NC}"
            read -p "Select an option [1-2]: " cert_option
            
            if [[ "$theme_option" == "1" ]]; then
                if [[ "$cert_option" == "1" ]]; then
                    reinstall "no" "no"
                elif [[ "$cert_option" == "2" ]]; then
                    reinstall "no" "yes"
                else
                    echo -e "${RED}❌ Invalid option. Exiting.${NC}"
                    exit 1
                fi
            elif [[ "$theme_option" == "2" ]]; then
                if [[ "$cert_option" == "1" ]]; then
                    reinstall "yes" "no"
                elif [[ "$cert_option" == "2" ]]; then
                    reinstall "yes" "yes"
                else
                    echo -e "${RED}❌ Invalid option. Exiting.${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}❌ Invalid option. Exiting.${NC}"
                exit 1
            fi
            ;;
        3)
            echo -e "${GREEN}Exiting.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option. Exiting.${NC}"
            exit 1
            ;;
    esac
}

# Make sure the scripts are executable
chmod +x generate_certs.sh
chmod +x manage.sh

# Show the main menu
show_menu
