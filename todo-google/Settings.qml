import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "./common/functions/google_tasks_api.js" as GoogleTasksAPI

ColumnLayout {
  id: root

  property var pluginApi: null

  property bool valueShowCompleted: pluginApi?.pluginSettings?.showCompleted !== undefined ? pluginApi.pluginSettings.showCompleted : pluginApi?.manifest?.metadata?.defaultSettings?.showCompleted
  property bool valueShowBackground: pluginApi?.pluginSettings?.showBackground !== undefined ? pluginApi.pluginSettings.showBackground : pluginApi?.manifest?.metadata?.defaultSettings?.showBackground

  property bool isConnecting: false
  property bool isLoadingTaskLists: false
  property var availableTaskLists: []

  spacing: Style.marginL

  Component.onCompleted: {
    Logger.i("TodoGoogle", "Settings UI loaded");
    loadTaskListsIfConnected();
  }

  // Google Tasks Integration Section
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NText {
      text: "Google Tasks Integration"
      font.pointSize: Style.fontSizeL
      font.weight: Font.Bold
      Layout.topMargin: Style.marginM
    }

    // Connection Status
    Rectangle {
      Layout.fillWidth: true
      height: 40
      color: Color.mSurfaceVariant
      radius: Style.radiusM

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        NIcon {
          icon: {
            var status = pluginApi?.pluginSettings?.syncStatus || "disconnected";
            if (status === "synced" || status === "syncing") return "cloud-done";
            if (status === "error") return "cloud-off";
            return "cloud-off";
          }
          color: {
            var status = pluginApi?.pluginSettings?.syncStatus || "disconnected";
            if (status === "synced") return Color.mPrimary;
            if (status === "syncing") return Color.mTertiary;
            if (status === "error") return Color.mError;
            return Color.mOnSurfaceVariant;
          }
        }

        NText {
          Layout.fillWidth: true
          text: {
            var status = pluginApi?.pluginSettings?.syncStatus || "disconnected";
            if (status === "synced") return "Connected to Google Tasks";
            if (status === "syncing") return "Syncing...";
            if (status === "error") return "Error: " + (pluginApi?.pluginSettings?.syncError || "Unknown error");
            return "Not connected to Google Tasks";
          }
          color: Color.mOnSurface
        }

        NButton {
          visible: pluginApi?.pluginSettings?.googleAccessToken
          text: "Disconnect"
          textColor: Color.mOnError
          backgroundColor: Color.mError
          onClicked: {
            if (pluginApi) {
              pluginApi.pluginSettings.googleAccessToken = "";
              pluginApi.pluginSettings.googleRefreshToken = "";
              pluginApi.pluginSettings.googleTaskListId = "";
              pluginApi.pluginSettings.syncEnabled = false;
              pluginApi.pluginSettings.syncStatus = "disconnected";
              pluginApi.pluginSettings.syncError = null;
              pluginApi.saveSettings();
              availableTaskLists = [];
              ToastService.showNotice("Disconnected from Google Tasks");
            }
          }
        }
      }
    }

    // Client ID and Secret Input
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      visible: !pluginApi?.pluginSettings?.googleAccessToken

      NText {
        text: "OAuth Credentials"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
      }

      NText {
        Layout.fillWidth: true
        text: "Enter your Google Cloud OAuth 2.0 Client ID and Client Secret. You can get these from the Google Cloud Console after creating OAuth credentials."
        wrapMode: Text.Wrap
        color: Color.mOnSurfaceVariant
        font.pointSize: Style.fontSizeS
      }

      NTextInput {
        id: clientIdInput
        Layout.fillWidth: true
        placeholderText: "Client ID"
        text: pluginApi?.pluginSettings?.googleClientId || ""
        onTextChanged: {
          if (pluginApi) {
            pluginApi.pluginSettings.googleClientId = text;
            pluginApi.saveSettings();
          }
        }
      }

      NTextInput {
        id: clientSecretInput
        Layout.fillWidth: true
        placeholderText: "Client Secret"
        text: pluginApi?.pluginSettings?.googleClientSecret || ""
        onTextChanged: {
          if (pluginApi) {
            pluginApi.pluginSettings.googleClientSecret = text;
            pluginApi.saveSettings();
          }
        }
      }
    }

    // OAuth Flow
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      visible: !pluginApi?.pluginSettings?.googleAccessToken && clientIdInput.text && clientSecretInput.text

      NText {
        text: "Connect to Google Tasks"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
      }

      NText {
        Layout.fillWidth: true
        text: "1. Click the button below to generate an authorization URL\n2. Open the URL in your browser\n3. Authorize the application\n4. Copy the authorization code from the redirect URL (the 'code' parameter)\n5. Paste it below and click 'Connect'"
        wrapMode: Text.Wrap
        color: Color.mOnSurfaceVariant
        font.pointSize: Style.fontSizeS
      }

      NButton {
        Layout.fillWidth: true
        text: "Generate Authorization URL"
        onClicked: {
          var clientId = pluginApi?.pluginSettings?.googleClientId || "";
          if (!clientId) {
            ToastService.showError("Please enter your Client ID first");
            return;
          }
          var authUrl = GoogleTasksAPI.generateAuthUrl(clientId);
          if (authUrl) {
            authUrlText.text = authUrl;
            authUrlText.visible = true;
            ToastService.showNotice("Authorization URL generated. Copy it and open in your browser.");
          } else {
            ToastService.showError("Failed to generate authorization URL");
          }
        }
      }

      NTextInput {
        id: authUrlText
        Layout.fillWidth: true
        visible: false
        readOnly: true
        text: ""
        placeholderText: "Authorization URL will appear here"
      }

      NTextInput {
        id: authCodeInput
        Layout.fillWidth: true
        placeholderText: "Paste authorization code here"
      }

      NButton {
        Layout.fillWidth: true
        text: isConnecting ? "Connecting..." : "Connect"
        enabled: !isConnecting && authCodeInput.text.trim() !== ""
        onClicked: {
          connectToGoogle();
        }
      }
    }

    // Task List Selection
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      visible: pluginApi?.pluginSettings?.googleAccessToken && !isLoadingTaskLists

      NText {
        text: "Task List"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
      }

      ComboBox {
        id: taskListCombo
        Layout.fillWidth: true
        model: availableTaskLists
        textRole: "title"
        currentIndex: {
          var currentListId = pluginApi?.pluginSettings?.googleTaskListId || "";
          for (var i = 0; i < availableTaskLists.length; i++) {
            if (availableTaskLists[i].id === currentListId) {
              return i;
            }
          }
          return -1;
        }
        onActivated: function(index) {
          if (pluginApi && index >= 0 && index < availableTaskLists.length) {
            pluginApi.pluginSettings.googleTaskListId = availableTaskLists[index].id;
            pluginApi.saveSettings();
            ToastService.showNotice("Task list selected: " + availableTaskLists[index].title);
          }
        }
      }

      NButton {
        Layout.fillWidth: true
        text: "Refresh Task Lists"
        onClicked: {
          loadTaskListsIfConnected();
        }
      }
    }

    // Loading indicator for task lists
    Item {
      Layout.fillWidth: true
      height: 40
      visible: isLoadingTaskLists

      NText {
        anchors.centerIn: parent
        text: "Loading task lists..."
        color: Color.mOnSurfaceVariant
      }
    }

    // Sync Settings
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      visible: pluginApi?.pluginSettings?.googleAccessToken

      NText {
        text: "Sync Settings"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
        Layout.topMargin: Style.marginM
      }

      NToggle {
        Layout.fillWidth: true
        label: "Enable Sync"
        description: "Automatically sync tasks with Google Tasks"
        checked: pluginApi?.pluginSettings?.syncEnabled || false
        onToggled: function (checked) {
          if (pluginApi) {
            pluginApi.pluginSettings.syncEnabled = checked;
            pluginApi.saveSettings();
            if (checked) {
              // Start sync timer
              var mainInstance = pluginApi?.mainInstance;
              if (mainInstance && mainInstance.syncTimer) {
                mainInstance.syncTimer.start();
              }
              // Trigger immediate sync
              if (mainInstance && mainInstance.syncWithGoogleTasks) {
                mainInstance.syncWithGoogleTasks();
              }
            } else {
              // Stop sync timer
              var mainInstance = pluginApi?.mainInstance;
              if (mainInstance && mainInstance.syncTimer) {
                mainInstance.syncTimer.stop();
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: "Sync Interval (minutes):"
          Layout.preferredWidth: 200
        }

        SpinBox {
          id: syncIntervalSpinBox
          from: 1
          to: 60
          value: (pluginApi?.pluginSettings?.syncInterval || 300000) / 60000
          onValueChanged: {
            if (pluginApi) {
              pluginApi.pluginSettings.syncInterval = value * 60000;
              pluginApi.saveSettings();
              // Update timer if running
              var mainInstance = pluginApi?.mainInstance;
              if (mainInstance && mainInstance.syncTimer) {
                mainInstance.syncTimer.interval = value * 60000;
              }
            }
          }
        }
      }

      NButton {
        Layout.fillWidth: true
        text: "Sync Now"
        enabled: pluginApi?.pluginSettings?.syncEnabled
        onClicked: {
          var mainInstance = pluginApi?.mainInstance;
          if (mainInstance && mainInstance.syncWithGoogleTasks) {
            mainInstance.syncWithGoogleTasks();
            ToastService.showNotice("Sync started");
          } else {
            ToastService.showError("Sync not available");
          }
        }
      }

      NText {
        Layout.fillWidth: true
        visible: pluginApi?.pluginSettings?.lastSyncAt
        text: "Last sync: " + (pluginApi?.pluginSettings?.lastSyncAt ? new Date(pluginApi.pluginSettings.lastSyncAt).toLocaleString() : "Never")
        color: Color.mOnSurfaceVariant
        font.pointSize: Style.fontSizeS
      }
    }
  }

  // Original Todo Settings
  NToggle {
    Layout.fillWidth: true
    label: "Show Completed"
    description: "Display completed todos in the list"
    checked: root.valueShowCompleted
    onToggled: function (checked) {
      root.valueShowCompleted = checked;
      saveSettings();
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show Background"
    description: "Show background color in the panel"
    checked: root.valueShowBackground
    onToggled: function (checked) {
      root.valueShowBackground = checked;
      saveSettings();
    }
  }

  // Section for managing pages
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "Manage Pages"
      font.pointSize: Style.fontSizeL
      font.weight: Font.Bold
      Layout.topMargin: Style.marginL
    }

    // Input for adding new pages
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NTextInput {
        id: newPageInput
        placeholderText: "Enter new page name"
        Layout.fillWidth: true
        Keys.onReturnPressed: addPage()
      }

      NButton {
        text: "Add Page"
        onClicked: addPage()
      }
    }

    // List of existing pages with proper scrolling
    Item {
      Layout.fillWidth: true
      height: 200

      Flickable {
        id: pagesListView
        anchors.fill: parent
        contentHeight: contentColumn.height
        clip: true
        boundsBehavior: Flickable.DragOverBounds

        ScrollBar.vertical: ScrollBar {
          parent: pagesListView
          anchors.top: pagesListView.top
          anchors.right: pagesListView.right
          anchors.bottom: pagesListView.bottom
          policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
          id: contentColumn
          width: parent.width
          spacing: Style.marginS

          Repeater {
            model: pluginApi?.pluginSettings?.pages || []

            delegate: Item {
              width: parent.width
              height: Style.baseWidgetSize

              property bool editing: false
              property string originalName: modelData.name || ""

              function saveRename() {
                var newName = renameInput.text.trim();
                if (newName === "") {
                  editing = false;
                  return;
                }

                if (newName === originalName) {
                  editing = false;
                  return;
                }

                if (!isPageNameUnique(newName, index)) {
                  ToastService.showError("Page name already exists");
                  return;
                }

                var pages = pluginApi.pluginSettings.pages || [];
                pages[index].name = newName;
                pluginApi.pluginSettings.pages = pages;
                pluginApi.saveSettings();

                originalName = newName;
                editing = false;
              }

              function cancelRename() {
                if (renameInput) {
                  renameInput.text = originalName;
                }
                editing = false;
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginS
                spacing: Style.marginS

                Item {
                  Layout.fillHeight: true
                  Layout.fillWidth: true
                  visible: !editing

                  RowLayout {
                    anchors.fill: parent
                    spacing: Style.marginS

                    NText {
                      text: modelData.name
                      Layout.fillWidth: true
                      verticalAlignment: Text.AlignVCenter
                    }

                    NIconButton {
                      icon: "pencil"
                      tooltipText: "Rename"
                      onClicked: {
                        originalName = modelData.name;
                        editing = true;
                      }
                    }

                    NIconButton {
                      icon: "trash"
                      tooltipText: "Delete"
                      colorFg: Color.mError
                      enabled: (pluginApi?.pluginSettings?.pages?.length || 0) > 1
                      onClicked: {
                        if ((pluginApi?.pluginSettings?.pages?.length || 0) <= 1) {
                          ToastService.showError("Cannot delete the last page");
                          return;
                        }
                        root.showDeleteConfirmation(index, modelData.name);
                      }
                    }
                  }
                }

                RowLayout {
                  Layout.fillHeight: true
                  Layout.fillWidth: true
                  spacing: Style.marginS
                  visible: editing

                  NTextInput {
                    id: renameInput
                    text: originalName
                    Layout.fillWidth: true
                    Layout.preferredWidth: 150
                    focus: editing

                    Keys.onReturnPressed: saveRename()
                    Keys.onEscapePressed: cancelRename()

                    onVisibleChanged: {
                      if (visible && editing) {
                        text = originalName;
                        forceActiveFocus();
                      }
                    }
                  }

                  NButton {
                    text: "✓"
                    fontSize: Style.fontSizeS
                    backgroundColor: Color.mPrimary
                    textColor: Color.mOnPrimary
                    onClicked: saveRename()
                  }

                  NButton {
                    text: "✕"
                    fontSize: Style.fontSizeS
                    backgroundColor: Color.mError
                    textColor: Color.mOnError
                    onClicked: cancelRename()
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Helper functions
  function getNextPageId() {
    var pages = pluginApi?.pluginSettings?.pages || [];
    if (pages.length === 0) {
      return 0;
    }

    var maxId = -1;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].id > maxId) {
        maxId = pages[i].id;
      }
    }
    return maxId + 1;
  }

  function isPageNameUnique(name, excludeIndex) {
    var pages = pluginApi?.pluginSettings?.pages || [];
    var lowerName = name.toLowerCase().trim();
    for (var i = 0; i < pages.length; i++) {
      if (i !== excludeIndex && pages[i].name.toLowerCase().trim() === lowerName) {
        return false;
      }
    }
    return true;
  }

  function addPage() {
    var name = newPageInput.text.trim();

    if (name === "") {
      ToastService.showError("Page name cannot be empty");
      return;
    }

    if (!isPageNameUnique(name, -1)) {
      ToastService.showError("Page name already exists");
      return;
    }

    var newPage = {
      id: getNextPageId(),
      name: name
    };

    var pages = pluginApi.pluginSettings?.pages || [];
    pages.push(newPage);
    pluginApi.pluginSettings.pages = pages;
    pluginApi.saveSettings();

    newPageInput.text = "";
    newPageInput.forceActiveFocus();
  }

  function connectToGoogle() {
    if (!pluginApi) {
      ToastService.showError("Plugin API not available");
      return;
    }

    var code = authCodeInput.text.trim();
    if (!code) {
      ToastService.showError("Please enter an authorization code");
      return;
    }

    var clientId = pluginApi.pluginSettings.googleClientId || "";
    var clientSecret = pluginApi.pluginSettings.googleClientSecret || "";

    if (!clientId || !clientSecret) {
      ToastService.showError("Please enter Client ID and Client Secret first");
      return;
    }

    isConnecting = true;
    ToastService.showNotice("Connecting to Google Tasks...");

    GoogleTasksAPI.authenticateWithCode(code, clientId, clientSecret, function(error, tokens) {
      isConnecting = false;
      if (error) {
        ToastService.showError("Failed to connect: " + error);
        Logger.e("TodoGoogle", "Authentication failed: " + error);
      } else {
        pluginApi.pluginSettings.googleAccessToken = tokens.accessToken;
        pluginApi.pluginSettings.googleRefreshToken = tokens.refreshToken;
        pluginApi.pluginSettings.syncStatus = "synced";
        pluginApi.pluginSettings.syncError = null;
        pluginApi.saveSettings();
        
        authCodeInput.text = "";
        ToastService.showNotice("Successfully connected to Google Tasks!");
        
        // Load task lists
        loadTaskListsIfConnected();
      }
    });
  }

  function loadTaskListsIfConnected() {
    if (!pluginApi?.pluginSettings?.googleAccessToken) {
      return;
    }

    isLoadingTaskLists = true;
    var accessToken = pluginApi.pluginSettings.googleAccessToken;

    GoogleTasksAPI.getTaskLists(accessToken, function(error, response) {
      isLoadingTaskLists = false;
      if (error) {
        ToastService.showError("Failed to load task lists: " + error);
        Logger.e("TodoGoogle", "Failed to load task lists: " + error);
      } else {
        availableTaskLists = response.items || [];
        if (availableTaskLists.length === 0) {
          ToastService.showNotice("No task lists found. Create one in Google Tasks first.");
        } else {
          // Auto-select first list if none selected
          if (!pluginApi.pluginSettings.googleTaskListId && availableTaskLists.length > 0) {
            pluginApi.pluginSettings.googleTaskListId = availableTaskLists[0].id;
            pluginApi.saveSettings();
          }
        }
      }
    });
  }

  // Confirmation dialog for page deletion
  Popup {
    id: confirmDialog
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: 300
    height: 150

    background: Rectangle {
      color: Color.mSurface
      border.color: Color.mOutline
      border.width: 1
      radius: Style.radiusL
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        id: confirmText
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: "Are you sure you want to delete this page?"
        verticalAlignment: Text.AlignVCenter
      }

      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Style.marginS

        NButton {
          text: "Cancel"
          onClicked: confirmDialog.close()
        }

        NButton {
          text: "Delete"
          textColor: Color.mOnError
          backgroundColor: Color.mError
          onClicked: {
            performPageDeletion(confirmDialog.pageIndex);
            confirmDialog.close();
          }
        }
      }
    }

    property int pageIndex: -1
  }

  function showDeleteConfirmation(pageIdx, pageName) {
    confirmDialog.pageIndex = pageIdx;
    confirmText.text = "Are you sure you want to delete page '" + pageName + "'?\n\nAll todos in this page will be transferred to the first page.";
    confirmDialog.open();
  }

  function performPageDeletion(pageIdx) {
    if (pageIdx < 0)
      return;

    var pages = pluginApi.pluginSettings.pages || [];
    if (pages.length <= 1) {
      ToastService.showError("Cannot delete the last page");
      return;
    }

    var pageToDeleteId = pages[pageIdx].id;
    var todos = pluginApi.pluginSettings.todos || [];
    var firstPageId = pages[0].id;

    for (var i = 0; i < todos.length; i++) {
      if (todos[i].pageId === pageToDeleteId) {
        todos[i].pageId = firstPageId;
      }
    }

    pages.splice(pageIdx, 1);

    if (pageToDeleteId === pluginApi.pluginSettings.current_page_id) {
      if (pages.length > 0) {
        pluginApi.pluginSettings.current_page_id = pages[0].id;
      } else {
        var defaultPage = {
          id: 0,
          name: "General"
        };
        pages.push(defaultPage);
        pluginApi.pluginSettings.current_page_id = 0;
      }
    }

    for (var i = 0; i < pages.length; i++) {
      pages[i].id = i;
    }

    pluginApi.pluginSettings.pages = pages;
    pluginApi.pluginSettings.todos = todos;
    pluginApi.saveSettings();
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("TodoGoogle", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.showCompleted = root.valueShowCompleted;
    pluginApi.pluginSettings.showBackground = root.valueShowBackground;
    pluginApi.saveSettings();

    Logger.i("TodoGoogle", "Settings saved successfully");
    return;
  }
}
