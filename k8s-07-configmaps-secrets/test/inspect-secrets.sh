#!/bin/bash
# filepath: /Users/in04844/Personal Project/Kubernet-from-zero-to-hero/k8s-07-configmaps-secrets/test/inspect-secrets.sh
# Script to demonstrate secret encoding/decoding

set -e

echo "========================================="
echo "Secrets Inspection Demo"
echo "========================================="
echo ""

echo "🔐 Viewing Secret in Kubernetes (base64 encoded)..."
kubectl get secret app-secrets -o yaml
echo ""
echo "----------------------------------------"
echo ""

echo "🔓 Decoding API_KEY secret..."
API_KEY_ENCODED=$(kubectl get secret app-secrets -o jsonpath='{.data.API_KEY}')
echo "Encoded: $API_KEY_ENCODED"
echo "Decoded: $(echo $API_KEY_ENCODED | base64 -d)"
echo ""

echo "🔓 Decoding DB_PASSWORD secret..."
DB_PASSWORD_ENCODED=$(kubectl get secret app-secrets -o jsonpath='{.data.DB_PASSWORD}')
echo "Encoded: $DB_PASSWORD_ENCODED"
echo "Decoded: $(echo $DB_PASSWORD_ENCODED | base64 -d)"
echo ""

echo "========================================="
echo "How to create secrets manually:"
echo "========================================="
echo ""
echo "# Method 1: From literal values"
echo 'kubectl create secret generic my-secret --from-literal=key1=value1 --from-literal=key2=value2'
echo ""
echo "# Method 2: From files"
echo 'kubectl create secret generic my-secret --from-file=ssh-key=~/.ssh/id_rsa'
echo ""
echo "# Method 3: Encode manually"
echo 'echo -n "my-secret-value" | base64'
echo ""
echo "# Method 4: Using stringData (auto-encodes)"
echo "cat <<EOF | kubectl apply -f -"
echo "apiVersion: v1"
echo "kind: Secret"
echo "metadata:"
echo "  name: my-secret"
echo "stringData:"
echo "  username: admin"
echo "  password: supersecret"
echo "EOF"
echo ""

echo "========================================="
echo "⚠️  IMPORTANT SECURITY NOTES"
echo "========================================="
echo "1. Base64 is NOT encryption - it's just encoding"
echo "2. Anyone with kubectl access can decode secrets"
echo "3. Never commit secrets to Git"
echo "4. Use RBAC to restrict secret access"
echo "5. Consider using:"
echo "   - Sealed Secrets (bitnami-labs/sealed-secrets)"
echo "   - External Secrets Operator"
echo "   - HashiCorp Vault"
echo "   - Cloud provider secret managers (AWS Secrets Manager, etc.)"
echo "========================================="
