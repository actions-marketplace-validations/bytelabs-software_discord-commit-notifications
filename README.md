# Discord Commit Notifications action

Yet another Discord notifications action for commits with optional artifacts upload support.

## Features

- Extracts current commit SHA, message and author
- Reads pull request title and details for PRs
- Creates rich Discord embeds with customizable colors
- Optional file upload support

## Usage

### Basic Usage

```yaml
- name: Send Discord Notification
  uses: bytelabs-software/discord-commit-notifications@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK_URL }}
```

### Advanced Usage

```yaml
- name: Send Discord Notification with File
  uses: bytelabs-software/discord-commit-notifications@v1
  with:
    webhook-url: ${{ secrets.DISCORD_WEBHOOK_URL }}
    file-path: './dist/app.zip'
    embed-color: '0xe74c3c'
    embed-title: 'Build Artifacts Ready'
    username: 'GitHub Bot'
    avatar-url: 'https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png'
```

### Complete Workflow Example

```yaml
name: Build and Notify Discord

on:
  pull_request:
  push:
    branches: [main]

jobs:
  build-and-notify:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build application
        run: |
          # Your build commands here
          mkdir -p dist
          echo "Built application" > dist/app.txt
          zip -r dist/app.zip dist/

      - name: Send Discord Notification
        uses: bytelabs-software/discord-commit-notifications@v1
        with:
          webhook-url: ${{ secrets.DISCORD_WEBHOOK_URL }}
          file-path: './dist/app.zip'
          embed-color: '0x00ff00'
          embed-title: '🚀 Build Complete'
```

## Inputs

| Input               | Description                                                        | Required | Default             |
| ------------------- | ------------------------------------------------------------------ | -------- | ------------------- |
| `webhook-url`       | Discord webhook URL                                                | ✅ Yes    | none                |
| `file-path`         | Path to file to upload                                             | ❌ No     | `''`                |
| `embed-color`       | Embed color in hex format                                          | ❌ No     | `0x3498db`          |
| `embed-title`       | Custom embed title                                                 | ❌ No     | `New commit pushed` |
| `username`          | Override Discord webhook username                                  | ❌ No     | `''`                |
| `avatar-url`        | Override Discord webhook avatar URL                                | ❌ No     | `''`                |
| `include-repo`      | Include repository info in the embed                               | ❌ No     | `true`              |
| `include-branch`    | Include branch info in the embed                                   | ❌ No     | `true`              |
| `include-pr-number` | Include PR number in notification (for `pull_request` events only) | ❌ No     | `true`              |

## Outputs

| Output   | Description                                                 |
| -------- | ----------------------------------------------------------- |
| `status` | Status of the Discord notification (`success` or `failure`) |

## Discord Webhook Setup

1. Go to your Discord server settings
2. Navigate to **Integrations** → **Webhooks**
3. Click **Create Webhook**
4. Configure the webhook (name, channel, avatar)
5. Copy the webhook URL
6. Add it to your repository secrets as `DISCORD_WEBHOOK_URL`

## Embed Information

The action creates rich embeds containing:

- **Pull Request**: Title and link (for PR events)
- **Commit**: Short SHA, message and link
- **Author**: Commit author name
- **Pull Request**: Pull Request number (if `include-pr-number` is `true` and it's a PR event)
- **Repository**: Repository name (if `include-repo` is `true`)
- **Branch**: Current branch name (if `include-branch` is `true`)
- **Timestamp**: When the action was triggered

## Color Codes

Common Discord embed colors:

- `0x3498db` - Blue (default)
- `0x2ecc71` - Green (success)
- `0xe74c3c` - Red (error)
- `0xf39c12` - Orange (warning)
- `0x9b59b6` - Purple
- `0x1abc9c` - Teal

## File Upload

When a file path is provided:

1. The embed is sent first
2. The file is uploaded in a separate message
3. This ensures proper message ordering in Discord

Supported file types include any file Discord accepts (up to 10MB for regular servers, 100MB for boosted servers).

## License

This action is available under the MIT License.
