#!/bin/bash
set -e

# Upload Terraform state to Terraform Cloud
# This script works around the "resource not found" state lock bug

# Set your Terraform Cloud token via environment variable:
# export TF_TOKEN="your-token-here"
TF_TOKEN="${TF_TOKEN:-}"
WORKSPACE_ID="ws-DL9gtBH8GXfvFQ39"

if [ -z "$TF_TOKEN" ]; then
  echo "❌ Error: TF_TOKEN environment variable is not set" >&2
  echo "Set it with: export TF_TOKEN=\"your-terraform-cloud-token\"" >&2
  exit 1
fi
STATE_FILE="terraform.tfstate"

echo "🔄 Uploading state to Terraform Cloud..."
echo "Workspace: twomindstrading-production"
echo "Workspace ID: $WORKSPACE_ID"

# Base64 encode the state file
STATE_B64=$(cat "$STATE_FILE" | base64 -w 0)

# Get current state version serial
CURRENT_SERIAL=$(cat "$STATE_FILE" | grep '"serial"' | head -1 | grep -o '[0-9]*')
echo "Current serial: $CURRENT_SERIAL"

# Create the JSON payload
cat > /tmp/state-upload.json <<EOF
{
  "data": {
    "type": "state-versions",
    "attributes": {
      "serial": $CURRENT_SERIAL,
      "md5": "$(md5sum $STATE_FILE | cut -d' ' -f1)",
      "state": "$STATE_B64"
    }
  }
}
EOF

# Upload to Terraform Cloud
RESPONSE=$(curl -s \
  --header "Authorization: Bearer $TF_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @/tmp/state-upload.json \
  "https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/state-versions")

# Check if successful
if echo "$RESPONSE" | grep -q '"id":"sv-'; then
  echo "✅ State uploaded successfully!"
  rm /tmp/state-upload.json
else
  echo "❌ Failed to upload state:"
  echo "$RESPONSE"
  rm /tmp/state-upload.json
  exit 1
fi
