#!/bin/bash
set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
ENV_FILE=".env"

# Function to check if Keywind theme is installed
is_keywind_installed() {
    # Check if the keywind.jar exists in the themes directory
    if [[ -f "./themes/keywind.jar" ]]; then
        return 0  # true
    fi
    
    # Check if there's a running container with the Keywind theme
    if docker ps -a | grep -q "keycloak" && docker exec -it $(docker ps -a --filter "name=keycloak" --format "{{.ID}}") ls -la /opt/keycloak/providers/ 2>/dev/null | grep -q "keywind.jar"; then
        return 0  # true
    fi
    
    return 1  # false
}

# Function to run docker-compose with the appropriate files
run_docker_compose() {
    local command=$1
    
    if is_keywind_installed; then
        echo -e "${BLUE}🔍 Detected Keywind theme installation${NC}"
        docker compose -f docker-compose.yaml -f docker-compose.keywind.yaml $command
    else
        echo -e "${BLUE}🔍 Using standard Keycloak installation${NC}"
        docker compose $command
    fi
}

# Function to start the environment
start_environment() {
    echo -e "${BLUE}🚀 Starting Keycloak environment...${NC}"
    run_docker_compose "up -d"
    echo -e "${GREEN}✅ Keycloak environment started${NC}"
    
    # Display access information
    source_env_if_exists
    echo -e "${GREEN}🌐 Keycloak is now accessible at:${NC}"
    echo -e "${YELLOW}https://localhost:8443${NC}"
    if [[ -n "$KEYCLOAK_DOMAIN" ]]; then
        echo -e "${YELLOW}https://$KEYCLOAK_DOMAIN${NC} (if DNS is configured)"
    fi
}

# Function to stop the environment
stop_environment() {
    echo -e "${BLUE}🛑 Stopping Keycloak environment...${NC}"
    run_docker_compose "down"
    echo -e "${GREEN}✅ Keycloak environment stopped${NC}"
}

# Function to restart the environment
restart_environment() {
    echo -e "${BLUE}🔄 Restarting Keycloak environment...${NC}"
    stop_environment
    start_environment
}

# Function to check the status of the environment
check_status() {
    echo -e "${BLUE}🔍 Checking Keycloak environment status...${NC}"
    docker ps -a | grep -E 'keycloak|postgres'
    
    # Check if Keycloak is accessible
    if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Keycloak is accessible at https://localhost:8443${NC}"
    else
        echo -e "${YELLOW}⚠️  Keycloak is not accessible at https://localhost:8443${NC}"
    fi
}

# Function to view logs
view_logs() {
    local service=$1
    local lines=$2
    
    if [[ -z "$service" ]]; then
        echo -e "${BLUE}📋 Viewing logs for all services...${NC}"
        run_docker_compose "logs --tail=${lines:-100} -f"
    else
        echo -e "${BLUE}📋 Viewing logs for $service...${NC}"
        run_docker_compose "logs --tail=${lines:-100} -f $service"
    fi
}

# Function to update the environment
update_environment() {
    echo -e "${BLUE}🔄 Updating Keycloak environment...${NC}"
    
    # Pull the latest images
    run_docker_compose "pull"
    
    # Rebuild the images
    run_docker_compose "build"
    
    # Restart the environment
    restart_environment
    
    echo -e "${GREEN}✅ Keycloak environment updated${NC}"
}

# Function to source the .env file if it exists
source_env_if_exists() {
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
    fi
}

# Function to show help
show_help() {
    echo -e "${BLUE}=== Keycloak Environment Management ===${NC}"
    echo -e "Usage: $0 [command]"
    echo -e ""
    echo -e "Commands:"
    echo -e "  ${GREEN}start${NC}       Start the Keycloak environment"
    echo -e "  ${GREEN}stop${NC}        Stop the Keycloak environment"
    echo -e "  ${GREEN}restart${NC}     Restart the Keycloak environment"
    echo -e "  ${GREEN}status${NC}      Check the status of the Keycloak environment"
    echo -e "  ${GREEN}logs${NC}        View logs for all services"
    echo -e "  ${GREEN}logs:keycloak${NC} View logs for the Keycloak service"
    echo -e "  ${GREEN}logs:postgres${NC} View logs for the PostgreSQL service"
    echo -e "  ${GREEN}update${NC}      Update the Keycloak environment (pull latest images and rebuild)"
    echo -e "  ${GREEN}help${NC}        Show this help message"
    echo -e ""
    echo -e "Examples:"
    echo -e "  $0 start"
    echo -e "  $0 logs:keycloak"
}

# Main function
main() {
    local command=$1
    local service=$2
    
    case $command in
        start)
            start_environment
            ;;
        stop)
            stop_environment
            ;;
        restart)
            restart_environment
            ;;
        status)
            check_status
            ;;
        logs)
            if [[ "$service" == "keycloak" ]]; then
                view_logs "keycloak"
            elif [[ "$service" == "postgres" ]]; then
                view_logs "postgres"
            else
                view_logs
            fi
            ;;
        logs:keycloak)
            view_logs "keycloak"
            ;;
        logs:postgres)
            view_logs "postgres"
            ;;
        update)
            update_environment
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Check if a command was provided
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

# Run the main function with the provided arguments
main "$@"