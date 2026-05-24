#!/bin/bash
set -e

CERT_NAME="MacWhisper Dev"

echo "=== MacWhisper Dev Certificate Setup ==="
echo ""

# Check if the certificate already exists
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "Certificate '$CERT_NAME' already exists in your keychain."
    echo "No action needed."
    exit 0
fi

echo "Certificate '$CERT_NAME' not found. Creating..."

# Create a temp directory for intermediate files
TMPDIR_CERT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CERT"' EXIT

KEY_FILE="$TMPDIR_CERT/dev.key"
CERT_FILE="$TMPDIR_CERT/dev.crt"
P12_FILE="$TMPDIR_CERT/dev.p12"
CNF_FILE="$TMPDIR_CERT/dev.cnf"

# Create an openssl config with Code Signing EKU
cat > "$CNF_FILE" <<EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
x509_extensions = v3_code_sign

[dn]
CN = $CERT_NAME

[v3_code_sign]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
subjectKeyIdentifier = hash
EOF

# 1. Generate a private key
echo "  -> Generating private key..."
openssl genrsa -out "$KEY_FILE" 2048 2>/dev/null

# 2. Create a self-signed certificate with Code Signing extension
echo "  -> Creating self-signed certificate..."
openssl req -new -x509 -key "$KEY_FILE" \
    -out "$CERT_FILE" \
    -days 3650 \
    -config "$CNF_FILE" \
    2>/dev/null

# 3. Export as .p12
echo "  -> Exporting as .p12..."
P12_PASS="macwhisper-dev"
openssl pkcs12 -export \
    -inkey "$KEY_FILE" \
    -in "$CERT_FILE" \
    -out "$P12_FILE" \
    -passout "pass:${P12_PASS}" \
    -legacy \
    2>/dev/null

# 4. Import into login keychain
echo "  -> Importing into login keychain..."
security import "$P12_FILE" \
    -k ~/Library/Keychains/login.keychain-db \
    -P "$P12_PASS" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

# 5. Set trust to "always trust" for code signing
echo "  -> Setting trust policy (you may be prompted for your password)..."
security add-trusted-cert -d -r trustRoot \
    -p codeSign \
    -k ~/Library/Keychains/login.keychain-db \
    "$CERT_FILE"

echo ""

# Verify it worked
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "=== Success! ==="
    echo "Certificate '$CERT_NAME' has been created and trusted."
    echo ""
    echo "You can now run: ./scripts/dev-build.sh"
    echo ""
    echo "If codesign still complains about trust, open Keychain Access,"
    echo "find '$CERT_NAME', double-click it, expand Trust, and set"
    echo "Code Signing to 'Always Trust'."
else
    echo "=== Warning ==="
    echo "Certificate was imported but could not be verified as a codesigning identity."
    echo "Open Keychain Access and check the '$CERT_NAME' certificate trust settings."
    exit 1
fi
