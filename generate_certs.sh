#!/bin/bash
set -e  # Exit on error

# Load .env file if it exists
if [[ -f ".env" ]]; then
    echo "📖 Loading environment variables from .env file..."
    # Read variables safely using grep and cut instead of export
    if [[ -f ".env" ]]; then
        KEYCLOAK_DOMAIN=$(grep -E "^KEYCLOAK_DOMAIN=" ".env" | cut -d'"' -f2 || echo "auth.example.com")
        KEYCLOAK_IP=$(grep -E "^KEYCLOAK_IP=" ".env" | cut -d'"' -f2 || echo "10.2.20.50")
        CERT_VALIDITY_DAYS=$(grep -E "^CERT_VALIDITY_DAYS=" ".env" | cut -d'"' -f2 || echo "3650")
        KEYCLOAK_ADMIN_EMAIL=$(grep -E "^KEYCLOAK_ADMIN_EMAIL=" ".env" | cut -d'"' -f2 || echo "admin@example.com")
        KEYCLOAK_ORGANIZATION=$(grep -E "^KEYCLOAK_ORGANIZATION=" ".env" | cut -d'"' -f2 || echo "ACME Corp")
        KEYCLOAK_ORG_UNIT=$(grep -E "^KEYCLOAK_ORG_UNIT=" ".env" | cut -d'"' -f2 || echo "Cloud Infrastructure")
    fi
else
    echo "⚠️  .env file not found. Using default values."
fi

# Variables (use values from .env if available)
DOMAIN="${KEYCLOAK_DOMAIN:-auth.example.com}"
IP="${KEYCLOAK_IP:-10.2.20.50}"
DAYS="${CERT_VALIDITY_DAYS:-3650}"  # Default: 10 years
ADMIN_EMAIL="${KEYCLOAK_ADMIN_EMAIL:-admin@example.com}"
ORGANIZATION="${KEYCLOAK_ORGANIZATION:-ACME Corp}"
ORGANIZATIONAL_UNIT="${KEYCLOAK_ORG_UNIT:-Cloud Infrastructure}"
KEYSTORE_SECRET_FILE="keystore_key.secret"

# Generate a secure keystore password (only if the file doesn't exist)
if [[ -f "$KEYSTORE_SECRET_FILE" ]]; then
    echo "🔒 Using existing keystore password from $KEYSTORE_SECRET_FILE"
    KEYSTORE_PASSWORD=$(cat "$KEYSTORE_SECRET_FILE")
else
    echo "🔑 Generating a new keystore password..."
    # Generate a random alphanumeric password (no special characters)
    KEYSTORE_PASSWORD=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
    echo "$KEYSTORE_PASSWORD" > "$KEYSTORE_SECRET_FILE"
    chmod 600 "$KEYSTORE_SECRET_FILE"
    echo "✅ Keystore password saved to $KEYSTORE_SECRET_FILE (root access only)"
fi

echo "🔐 Generating self-signed certificate for $DOMAIN (IP: $IP) valid for $DAYS days..."

# Create directory for certificates
mkdir -p ./certs

# Create OpenSSL configuration file
cat > ./certs/openssl.cnf << EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
CN = $DOMAIN
O = $ORGANIZATION
OU = $ORGANIZATIONAL_UNIT
emailAddress = $ADMIN_EMAIL

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = $IP
IP.2 = 127.0.0.1
EOF

# Generate private key
openssl genrsa -out ./certs/server.key 4096

# Generate certificate
openssl req -x509 -new -nodes -key ./certs/server.key \
  -config ./certs/openssl.cnf \
  -sha256 -days "$DAYS" \
  -out ./certs/server.crt

# Create PKCS12 keystore for Keycloak
openssl pkcs12 -export -name server \
  -in ./certs/server.crt \
  -inkey ./certs/server.key \
  -out ./certs/server.keystore \
  -password pass:"$KEYSTORE_PASSWORD"

# Set proper permissions
chmod 600 ./certs/server.key
chmod 644 ./certs/server.crt
chmod 600 ./certs/server.keystore

echo "✅ Certificate generation completed successfully"
echo "📂 Files created in ./certs directory:"
ls -la ./certs/

echo
echo "🔑 Keystore password is securely stored in $KEYSTORE_SECRET_FILE"
echo "✅ You can now build the Docker image with these certificates."
