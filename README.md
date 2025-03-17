# Keycloak with PostgreSQL (Docker Compose Setup)

This repository contains a Docker Compose setup for Keycloak with PostgreSQL, including custom certificates and optional Keywind theme integration.

## Quick Start

1. Make the scripts executable:
   ```bash
   chmod +x install.sh
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Follow the on-screen prompts to complete the installation.

## ATTENTION
**Keycloak** in this setup is configured to work behind **reverse-proxy**. Docker will expose port 8443, but **it will not work**.
You can use for example HAProxy, example HAProxy in Docker repository can be found here: [Click!](https://github.com/PeteSmartTech/haproxy-cloudflare-homeassistant)
This way your reverse-proxy would reach Keycloak at `<keycloak_IP>:8443` but everything else will work via FQDN.

## Installation Options

The `install.sh` script provides the following options:

- **First Install**: Sets up Keycloak for the first time
  - Creates `.env` file if it doesn't exist
  - Generates certificates if they don't exist
  - Builds and starts the Docker containers

- **Re-install**: Removes everything and recreates from scratch
  - Option to keep or recreate certificates
  - Removes containers, volumes, and images
  - Rebuilds and starts the Docker containers

- **Theme Selection**: For both installation types
  - Install without Keywind theme (default Keycloak theme)
  - Install with Keywind theme (modern, Tailwind CSS-based theme)

## Configuration

The installation is configured through the `.env` file, which contains:

- Database credentials
- Keycloak admin credentials
- Domain settings
- Certificate generation settings

The script handles configuration in the following ways:

- **First-time setup**: If no `.env` file exists, the script will create one and prompt you for all necessary values. The Keycloak domain is required and cannot be empty.
- **Existing configuration**: If an `.env` file already exists, the script will show the current values and ask if you want to update them.
- **Secure credentials**: PostgreSQL password, admin username, and admin password are automatically generated for new installations and displayed at the end of the setup process.

## Certificates

Self-signed certificates are generated using the `generate_certs.sh` script. The certificates are used for HTTPS access to Keycloak.

## Managing the Environment

After installation, you can use the `manage.sh` script to control the Keycloak environment:

```bash
# Make the script executable
chmod +x manage.sh

# Start the environment
./manage.sh start

# Stop the environment
./manage.sh stop

# Restart the environment
./manage.sh restart

# Check the status
./manage.sh status

# View logs
./manage.sh logs
./manage.sh logs:keycloak
./manage.sh logs:postgres

# Update the environment
./manage.sh update

# Show help
./manage.sh help
```

## Accessing Keycloak

After starting the environment, Keycloak will be available at:

```
https://localhost:8443
```

Or at the domain you specified in the `.env` file.

## Login with Initial Admin User

1. Go to your Keycloak URL
2. Log in with the admin credentials specified in the `.env` file
3. You can now configure Keycloak as needed

## Adding new Admin user.
Make sure you are on Realm -> Master

Go to `Users` -> `Add User`
Set the new admin:
- Username
- E-mail
- First name (optional)
- Last name (optional)
- E-mail verified -> Check

Then `Create`.

After creation, go to `Role mapping`, you will be at `Assign roles to <your_username>` screen.

Select `Filter` -> `Filter by realm roles`, you will see a list of Realm roles.

Select role named `admin` with description `role_admin` and then -> `Assign`.

Go to `Credentials` and set new password for our admin user. You can set it as temporary password and make the user set the password at first login.


## Using the Keywind Theme

If you installed Keycloak with the Keywind theme, you can enable it by:

1. Log in to the Keycloak Admin Console
2. Go to `Realm Settings` -> `Theme`
3. Select `Keywind` as the Login theme
4. Click `Save`

## Customization

- **Dockerfile.base**: Base Keycloak image without Keywind theme
- **Dockerfile.keywind**: Keycloak image with Keywind theme
- **docker-compose.yaml**: Main Docker Compose configuration
- **docker-compose.keywind.yaml**: Override for Keywind theme integration

- **Dockerfile.bringyourowntheme**: You can put your own theme in ./themes, and edit lines 33, 36 and 37; then use this Dockerfile to build image with Your theme.
