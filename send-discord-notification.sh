#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check required environment variables
if [[ -z "$WEBHOOK_URL" ]]; then
    error "WEBHOOK_URL environment variable is required"
    exit 1
fi

# Set default values
EMBED_COLOR=${EMBED_COLOR:-"0x3498db"}
EMBED_TITLE=${EMBED_TITLE:-"New commit pushed"}

log "Starting Discord notification process..."

# Get pull request information
if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
    PR_TITLE=$(jq -r '.pull_request.title' "$GITHUB_EVENT_PATH")
    PR_NUMBER=$(jq -r '.pull_request.number' "$GITHUB_EVENT_PATH")
    PR_URL=$(jq -r '.pull_request.html_url' "$GITHUB_EVENT_PATH")
    PR_AUTHOR=$(jq -r '.pull_request.user.login' "$GITHUB_EVENT_PATH")
    log "Found pull request: #$PR_NUMBER - $PR_TITLE"
else
    # Fallback for non-PR events
    PR_TITLE="Direct Push"
    PR_NUMBER=""
    PR_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY"
    PR_AUTHOR="$GITHUB_ACTOR"
    warn "Not a pull request event, using fallback values"
fi

# Get current commit information
COMMIT_SHA=$(git rev-parse --short HEAD)
COMMIT_MESSAGE=$(git log -1 --pretty=format:"%s")
COMMIT_AUTHOR=$(git log -1 --pretty=format:"%an")
COMMIT_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/commit/$(git rev-parse HEAD)"

log "Commit info: $COMMIT_SHA by $COMMIT_AUTHOR"

# Convert hex color to decimal
if [[ "$EMBED_COLOR" =~ ^0x[0-9a-fA-F]+$ ]]; then
    EMBED_COLOR_DECIMAL=$((EMBED_COLOR))
else
    warn "Invalid color format, using default blue"
    EMBED_COLOR_DECIMAL=$((0x3498db))
fi

# Create embed description
EMBED_DESCRIPTION=""
if [[ -n "$PR_NUMBER" ]]; then
    EMBED_DESCRIPTION="**Pull Request:** [#$PR_NUMBER $PR_TITLE]($PR_URL)\n"
fi
EMBED_DESCRIPTION="${EMBED_DESCRIPTION}**Commit:** [\`$COMMIT_SHA\`]($COMMIT_URL) $COMMIT_MESSAGE\n"
if [[ "$INCLUDE_AUTHOR" == "true" ]]; then
    EMBED_DESCRIPTION="${EMBED_DESCRIPTION}**Author:** $COMMIT_AUTHOR"
fi

# Create the JSON payload for Discord webhook
create_embed_payload() {
    local fields_array=()

    # Add PR number field if enabled and it's a PR event
    if [[ "$INCLUDE_PR_NUMBER" == "true" && -n "$PR_NUMBER" ]]; then
        fields_array+=('{"name": "Pull Request", "value": "#'"$PR_NUMBER"'", "inline": true}')
    fi

    if [[ "$INCLUDE_REPO" == "true" ]]; then
        fields_array+=('{"name": "Repository", "value": "'"$GITHUB_REPOSITORY"'", "inline": true}')
    fi
    if [[ "$INCLUDE_BRANCH" == "true" ]]; then
        fields_array+=('{"name": "Branch", "value": "'"$GITHUB_REF_NAME"'", "inline": true}')
    fi

    local fields_json=""
    if [[ ${#fields_array[@]} -gt 0 ]]; then
        fields_json=$(IFS=,; echo "${fields_array[*]}")
    fi

    local payload='{
  "embeds": [
    {
      "title": "'"$EMBED_TITLE"'",
      "description": "'"$EMBED_DESCRIPTION"'",
      "color": '"$EMBED_COLOR_DECIMAL"',
      "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'",
      "footer": {
        "text": "GitHub Actions",
        "icon_url": "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png"
      },
      "fields": ['"$fields_json"']
    }
  ]'

    # Add username if provided
    if [[ -n "$USERNAME" ]]; then
        payload="$payload"',
  "username": "'"$USERNAME"'"'
    fi

    # Add avatar_url if provided
    if [[ -n "$AVATAR_URL" ]]; then
        payload="$payload"',
  "avatar_url": "'"$AVATAR_URL"'"'
    fi

    payload="$payload"'
}'
    echo "$payload"
}

# Send embed to Discord
log "Sending embed to Discord..."
EMBED_PAYLOAD=$(create_embed_payload)

RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$EMBED_PAYLOAD" \
    "$WEBHOOK_URL")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    success "Embed sent successfully to Discord"
else
    error "Failed to send embed to Discord. HTTP Code: $HTTP_CODE"
    error "Response: $RESPONSE_BODY"
    exit 1
fi

# Send file if provided
if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
    log "Sending file: $FILE_PATH"
    
    # Get file name from path
    FILE_NAME=$(basename "$FILE_PATH")
    
    # Send file to Discord
    CURL_CMD="curl -s -w \"%{http_code}\" -X POST -F \"file=@$FILE_PATH\""
    if [[ -n "$USERNAME" ]]; then
        CURL_CMD="$CURL_CMD -F \"username=$USERNAME\""
    fi
    if [[ -n "$AVATAR_URL" ]]; then
        CURL_CMD="$CURL_CMD -F \"avatar_url=$AVATAR_URL\""
    fi
    CURL_CMD="$CURL_CMD \"$WEBHOOK_URL\""

    RESPONSE=$(eval "$CURL_CMD")
    
    HTTP_CODE="${RESPONSE: -3}"
    RESPONSE_BODY="${RESPONSE%???}"
    
    if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
        success "File '$FILE_NAME' sent successfully to Discord"
    else
        error "Failed to send file to Discord. HTTP Code: $HTTP_CODE"
        error "Response: $RESPONSE_BODY"
        exit 1
    fi
elif [[ -n "$FILE_PATH" ]]; then
    warn "File path provided but file does not exist: $FILE_PATH"
fi

success "Discord notification completed successfully!"

# Set output for GitHub Actions
echo "status=success" >> "$GITHUB_OUTPUT"
