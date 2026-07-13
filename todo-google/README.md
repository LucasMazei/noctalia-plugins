## Todo List (Google Tasks) - Noctalia Plugin

A todo list manager plugin for Noctalia Shell with full two-way synchronization to Google Tasks.

### Features

- **Full Todo Management**: Create, edit, complete, and delete todos
- **Multiple Pages**: Organize todos into different pages/categories
- **Google Tasks Integration**: Two-way sync with Google Tasks
- **Automatic Sync**: Periodic background synchronization (configurable interval)
- **Manual Sync**: Trigger sync on demand from the panel or settings
- **OAuth Authentication**: Secure connection to Google Tasks using OAuth 2.0
- **Sync Status Indicators**: Visual feedback for sync status in panel and bar widget
- **Error Handling**: Comprehensive error handling with user-friendly messages

### Installation

1. Clone or download this repository
2. Create a symlink to the plugin directory:

```bash
ln -s /path/to/noctalia-plugins/todo-google ~/.config/noctalia/plugins/todo-google
systemctl --user restart noctalia
```

3. Enable the plugin in **Noctalia Settings → Plugins → Todo List (Google Tasks)**

### Google Tasks Setup

Before using Google Tasks integration, you need to set up OAuth credentials:

1. **Create a Google Cloud Project**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one

2. **Enable Google Tasks API**:
   - Navigate to "APIs & Services" → "Library"
   - Search for "Google Tasks API"
   - Click "Enable"

3. **Create OAuth 2.0 Credentials**:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth client ID"
   - Choose "Web application" as the application type
   - Add authorized redirect URI: `http://localhost:8080`
   - Copy the Client ID and Client Secret

4. **Configure in Plugin Settings**:
   - Open Noctalia Settings → Plugins → Todo List (Google Tasks) → Settings
   - Enter your Client ID and Client Secret
   - Click "Generate Authorization URL"
   - Open the URL in your browser and authorize the application
   - Copy the authorization code from the redirect URL (the `code` parameter)
   - Paste the code and click "Connect"

### Usage

#### Basic Todo Management

- **Add Todo**: Type in the input field at the bottom of the panel and press Enter
- **Complete Todo**: Click the checkbox next to a todo item
- **Edit Todo**: Click the pencil icon next to a todo item
- **Delete Todo**: Click the X icon next to a todo item
- **Clear Completed**: Click the "Clear Completed" button in the panel header

#### Google Tasks Sync

- **Automatic Sync**: When enabled, the plugin syncs with Google Tasks every 5 minutes (configurable)
- **Manual Sync**: Click the refresh icon in the panel header or use the "Sync Now" button in settings
- **Sync Status**: Check the cloud icon in the panel header or bar widget:
  - Green cloud: Synced successfully
  - Blue cloud: Currently syncing
  - Red cloud: Sync error (check settings for details)

#### Pages

- **Add Page**: Enter a page name in the settings and click "Add Page"
- **Switch Pages**: Click on the page tabs at the top of the panel
- **Rename Page**: Click the pencil icon next to a page in settings
- **Delete Page**: Click the trash icon next to a page in settings

### Settings

- **Show Completed**: Toggle visibility of completed todos
- **Show Background**: Toggle background color in the panel
- **Google Tasks Integration**:
  - Client ID and Client Secret: Your OAuth credentials
  - Task List: Select which Google Tasks list to sync with
  - Enable Sync: Toggle automatic synchronization
  - Sync Interval: Set how often to sync (in minutes, 1-60)

### IPC Commands

The plugin exposes the following IPC commands:

- `plugin:todo-google togglePanel` - Open/close the todo panel
- `plugin:todo-google addTodo <text> <pageId>` - Add a todo to a specific page
- `plugin:todo-google addTodoDefault <text>` - Add a todo to the default page
- `plugin:todo-google toggleTodo <id>` - Toggle completion status of a todo
- `plugin:todo-google removeTodo <id>` - Remove a todo
- `plugin:todo-google clearCompleted` - Clear all completed todos
- `plugin:todo-google syncNow` - Trigger manual sync with Google Tasks
- `plugin:todo-google disconnectGoogle` - Disconnect from Google Tasks

### Troubleshooting

**Sync not working:**
- Check that you're connected to Google Tasks in settings
- Verify that a task list is selected
- Check the sync status indicator for error messages
- Try manually syncing from settings

**Authentication errors:**
- Verify your Client ID and Client Secret are correct
- Make sure the redirect URI matches exactly: `http://localhost:8080`
- Try disconnecting and reconnecting

**Tasks not syncing:**
- Check your internet connection
- Verify the Google Tasks API is enabled in your Google Cloud project
- Check the sync status in settings for error details

### License

MIT

### Author

Usuario
