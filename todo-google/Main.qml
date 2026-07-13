import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import "./common/functions/google_tasks_api.js" as GoogleTasksAPI

Item {
  property var pluginApi: null
  
  property bool isSyncing: false
  property string lastSyncError: ""

  Component.onCompleted: {
    if (pluginApi) {
      if (!pluginApi.pluginSettings.pages) {
        pluginApi.pluginSettings.pages = [
          {
            id: 0,
            name: "General"
          }
        ];
        pluginApi.pluginSettings.current_page_id = 0;
      }

      if (!pluginApi.pluginSettings.todos) {
        pluginApi.pluginSettings.todos = [];
        pluginApi.pluginSettings.count = 0;
        pluginApi.pluginSettings.completedCount = 0;
      }

      if (pluginApi.pluginSettings.isExpanded === undefined) {
        pluginApi.pluginSettings.isExpanded = false;
      }

      // Ensure all existing todos have a pageId and Google Tasks fields
      var todos = pluginApi.pluginSettings.todos;
      for (var i = 0; i < todos.length; i++) {
        if (todos[i].pageId === undefined) {
          todos[i].pageId = 0;
        }
        if (todos[i].googleTaskId === undefined) {
          todos[i].googleTaskId = "";
        }
        if (todos[i].googleTaskListId === undefined) {
          todos[i].googleTaskListId = "";
        }
        if (todos[i].lastSyncedAt === undefined) {
          todos[i].lastSyncedAt = null;
        }
      }

      pluginApi.saveSettings();
      
      // Start sync timer if enabled
      if (pluginApi.pluginSettings.syncEnabled && pluginApi.pluginSettings.googleAccessToken) {
        syncTimer.start();
        // Initial sync on startup
        Qt.callLater(function() {
          syncWithGoogleTasks();
        });
      }
    }
  }

  // Periodic sync timer
  Timer {
    id: syncTimer
    interval: pluginApi?.pluginSettings?.syncInterval || 300000 // 5 minutes default
    running: false
    repeat: true
    onTriggered: {
      if (pluginApi?.pluginSettings?.syncEnabled && pluginApi?.pluginSettings?.googleAccessToken) {
        syncWithGoogleTasks();
      }
    }
  }

  // Helper function to ensure valid access token
  function ensureValidToken(callback) {
    if (!pluginApi?.pluginSettings?.googleAccessToken) {
      callback("No access token available", null);
      return;
    }
    
    // For now, we'll use the token directly. In production, you might want to check expiration
    // and refresh if needed. Token refresh would be handled here.
    callback(null, pluginApi.pluginSettings.googleAccessToken);
  }

  // Refresh access token if needed
  function refreshTokenIfNeeded(callback) {
    var refreshToken = pluginApi?.pluginSettings?.googleRefreshToken;
    var clientId = pluginApi?.pluginSettings?.googleClientId;
    var clientSecret = pluginApi?.pluginSettings?.googleClientSecret;
    
    if (!refreshToken || !clientId || !clientSecret) {
      callback("Missing refresh token or credentials", null);
      return;
    }
    
    GoogleTasksAPI.refreshAccessToken(refreshToken, clientId, clientSecret, function(error, tokens) {
      if (error) {
        callback(error, null);
      } else {
        pluginApi.pluginSettings.googleAccessToken = tokens.accessToken;
        pluginApi.saveSettings();
        callback(null, tokens.accessToken);
      }
    });
  }

  // Two-way sync with Google Tasks
  function syncWithGoogleTasks() {
    if (isSyncing) {
      Logger.i("TodoGoogle", "Sync already in progress, skipping");
      return;
    }
    
    if (!pluginApi?.pluginSettings?.syncEnabled) {
      Logger.i("TodoGoogle", "Sync is disabled");
      return;
    }
    
    var taskListId = pluginApi?.pluginSettings?.googleTaskListId;
    if (!taskListId) {
      Logger.e("TodoGoogle", "No task list ID configured");
      pluginApi.pluginSettings.syncStatus = "error";
      pluginApi.pluginSettings.syncError = "No task list selected";
      pluginApi.saveSettings();
      return;
    }
    
    isSyncing = true;
    pluginApi.pluginSettings.syncStatus = "syncing";
    pluginApi.pluginSettings.syncError = null;
    pluginApi.saveSettings();
    
    ensureValidToken(function(tokenError, accessToken) {
      if (tokenError) {
        // Try to refresh token
        refreshTokenIfNeeded(function(refreshError, newToken) {
          if (refreshError) {
            isSyncing = false;
            pluginApi.pluginSettings.syncStatus = "error";
            pluginApi.pluginSettings.syncError = refreshError;
            pluginApi.saveSettings();
            Logger.e("TodoGoogle", "Token refresh failed: " + refreshError);
            return;
          }
          performSync(newToken, taskListId);
        });
      } else {
        performSync(accessToken, taskListId);
      }
    });
  }

  function performSync(accessToken, taskListId) {
    // Step 1: Fetch tasks from Google Tasks
    GoogleTasksAPI.getTasks(taskListId, accessToken, function(error, response) {
      if (error) {
        // Check if it's an auth error and try refresh
        if (error.indexOf("Unauthorized") >= 0 || error.indexOf("401") >= 0) {
          refreshTokenIfNeeded(function(refreshError, newToken) {
            if (refreshError) {
              isSyncing = false;
              pluginApi.pluginSettings.syncStatus = "error";
              pluginApi.pluginSettings.syncError = "Authentication failed: " + refreshError;
              pluginApi.saveSettings();
              Logger.e("TodoGoogle", "Authentication failed: " + refreshError);
              return;
            }
            // Retry with new token
            performSync(newToken, taskListId);
          });
          return;
        }
        
        isSyncing = false;
        pluginApi.pluginSettings.syncStatus = "error";
        pluginApi.pluginSettings.syncError = error;
        pluginApi.saveSettings();
        Logger.e("TodoGoogle", "Failed to fetch tasks: " + error);
        return;
      }
      
      var googleTasks = response.items || [];
      var localTodos = pluginApi.pluginSettings.todos || [];
      
      // Step 2: Merge Google Tasks with local todos
      mergeTasks(googleTasks, localTodos, accessToken, taskListId);
    });
  }

  function mergeTasks(googleTasks, localTodos, accessToken, taskListId) {
    var now = new Date().toISOString();
    var updatedTodos = [];
    var tasksToCreate = [];
    var tasksToUpdate = [];
    
    // Create a map of Google tasks by ID
    var googleTasksMap = {};
    for (var i = 0; i < googleTasks.length; i++) {
      googleTasksMap[googleTasks[i].id] = googleTasks[i];
    }
    
    // Create a map of local todos by Google Task ID
    var localTodosByGoogleId = {};
    var localTodosWithoutGoogleId = [];
    
    for (var j = 0; j < localTodos.length; j++) {
      var todo = localTodos[j];
      if (todo.googleTaskId) {
        localTodosByGoogleId[todo.googleTaskId] = todo;
      } else {
        localTodosWithoutGoogleId.push(todo);
      }
    }
    
    // Process Google tasks - update local or create new
    for (var k = 0; k < googleTasks.length; k++) {
      var googleTask = googleTasks[k];
      var localTodo = localTodosByGoogleId[googleTask.id];
      
      if (localTodo) {
        // Both exist - merge based on lastSyncedAt (last-write-wins)
        var googleUpdated = new Date(googleTask.updated || googleTask.updated || 0).getTime();
        var localUpdated = localTodo.lastSyncedAt ? new Date(localTodo.lastSyncedAt).getTime() : 0;
        
        if (googleUpdated > localUpdated) {
          // Google is newer - update local
          localTodo.text = googleTask.title || "";
          localTodo.completed = googleTask.status === "completed";
          localTodo.lastSyncedAt = now;
          updatedTodos.push(localTodo);
        } else if (localUpdated > googleUpdated) {
          // Local is newer - update Google
          tasksToUpdate.push({
            todo: localTodo,
            googleTask: googleTask
          });
          localTodo.lastSyncedAt = now;
          updatedTodos.push(localTodo);
        } else {
          // Same timestamp - keep local
          updatedTodos.push(localTodo);
        }
      } else {
        // Google task doesn't exist locally - create new local todo
        var newTodo = {
          id: Date.now() + k, // Ensure unique ID
          text: googleTask.title || "",
          completed: googleTask.status === "completed",
          createdAt: googleTask.updated || now,
          pageId: 0, // Default to first page
          googleTaskId: googleTask.id,
          googleTaskListId: taskListId,
          lastSyncedAt: now
        };
        updatedTodos.push(newTodo);
      }
    }
    
    // Process local todos without Google ID - create in Google
    for (var m = 0; m < localTodosWithoutGoogleId.length; m++) {
      var localTodo = localTodosWithoutGoogleId[m];
      tasksToCreate.push(localTodo);
      updatedTodos.push(localTodo);
    }
    
    // Process local todos that need updates
    for (var n = 0; n < localTodos.length; n++) {
      var todo = localTodos[n];
      if (todo.googleTaskId && !localTodosByGoogleId[todo.googleTaskId]) {
        // This shouldn't happen, but handle it
        updatedTodos.push(todo);
      }
    }
    
    // Update local todos
    pluginApi.pluginSettings.todos = updatedTodos;
    
    // Recalculate counts
    var completedCount = 0;
    for (var p = 0; p < updatedTodos.length; p++) {
      if (updatedTodos[p].completed) {
        completedCount++;
      }
    }
    pluginApi.pluginSettings.count = updatedTodos.length;
    pluginApi.pluginSettings.completedCount = completedCount;
    
    // Create tasks in Google
    var createIndex = 0;
    function createNextTask() {
      if (createIndex >= tasksToCreate.length) {
        updateNextTask();
        return;
      }
      
      var todo = tasksToCreate[createIndex];
      GoogleTasksAPI.createTask(taskListId, {
        title: todo.text,
        completed: todo.completed
      }, accessToken, function(error, createdTask) {
        if (error) {
          Logger.e("TodoGoogle", "Failed to create task in Google: " + error);
          // Continue with next task
        } else {
          // Update local todo with Google task ID
          for (var q = 0; q < updatedTodos.length; q++) {
            if (updatedTodos[q].id === todo.id) {
              updatedTodos[q].googleTaskId = createdTask.id;
              updatedTodos[q].googleTaskListId = taskListId;
              updatedTodos[q].lastSyncedAt = now;
              break;
            }
          }
        }
        createIndex++;
        createNextTask();
      });
    }
    
    // Update tasks in Google
    var updateIndex = 0;
    function updateNextTask() {
      if (updateIndex >= tasksToUpdate.length) {
        finishSync();
        return;
      }
      
      var updateItem = tasksToUpdate[updateIndex];
      GoogleTasksAPI.updateTask(taskListId, updateItem.googleTask.id, {
        title: updateItem.todo.text,
        completed: updateItem.todo.completed
      }, accessToken, function(error, updatedTask) {
        if (error) {
          Logger.e("TodoGoogle", "Failed to update task in Google: " + error);
        }
        updateIndex++;
        updateNextTask();
      });
    }
    
    // Save updated todos after all operations
    function finishSync() {
      pluginApi.pluginSettings.todos = updatedTodos;
      pluginApi.pluginSettings.lastSyncAt = now;
      pluginApi.pluginSettings.syncStatus = "synced";
      pluginApi.pluginSettings.syncError = null;
      pluginApi.saveSettings();
      isSyncing = false;
      Logger.i("TodoGoogle", "Sync completed successfully");
    }
    
    // Start the sync operations
    if (tasksToCreate.length > 0) {
      createNextTask();
    } else if (tasksToUpdate.length > 0) {
      updateNextTask();
    } else {
      finishSync();
    }
  }

  // Sync a single todo to Google Tasks (called when todo is created/updated)
  function syncTodoToGoogle(todo, accessToken, taskListId) {
    if (!todo) return;
    
    if (todo.googleTaskId) {
      // Update existing task
      GoogleTasksAPI.updateTask(taskListId, todo.googleTaskId, {
        title: todo.text,
        completed: todo.completed
      }, accessToken, function(error, updatedTask) {
        if (error) {
          Logger.e("TodoGoogle", "Failed to sync todo update: " + error);
          todo.needsSync = true;
        } else {
          todo.lastSyncedAt = new Date().toISOString();
          todo.needsSync = false;
          pluginApi.saveSettings();
        }
      });
    } else {
      // Create new task
      GoogleTasksAPI.createTask(taskListId, {
        title: todo.text,
        completed: todo.completed
      }, accessToken, function(error, createdTask) {
        if (error) {
          Logger.e("TodoGoogle", "Failed to sync todo creation: " + error);
          todo.needsSync = true;
        } else {
          todo.googleTaskId = createdTask.id;
          todo.googleTaskListId = taskListId;
          todo.lastSyncedAt = new Date().toISOString();
          todo.needsSync = false;
          pluginApi.saveSettings();
        }
      });
    }
  }

  IpcHandler {
    target: "plugin:todo-google"

    function togglePanel() {
      pluginApi.withCurrentScreen(screen => {
        pluginApi.togglePanel(screen);
      });
    }

    function addTodo(text: string, pageId: int) {
      if (pluginApi && text) {
        var pages = pluginApi.pluginSettings.pages || [];
        var isValidPageId = false;

        for (var i = 0; i < pages.length; i++) {
          if (pages[i].id === pageId) {
            isValidPageId = true;
            break;
          }
        }

        if (!isValidPageId) {
          Logger.e("TodoGoogle", "Invalid pageId: " + pageId);
          return;
        }

        var todos = pluginApi.pluginSettings.todos || [];

        var newTodo = {
          id: Date.now(),
          text: text,
          completed: false,
          createdAt: new Date().toISOString(),
          pageId: pageId,
          googleTaskId: "",
          googleTaskListId: "",
          lastSyncedAt: null,
          needsSync: true
        };

        todos.push(newTodo);

        pluginApi.pluginSettings.todos = todos;
        pluginApi.pluginSettings.count = todos.length;
        pluginApi.saveSettings();

        ToastService.showNotice("Added new todo: " + text);
        
        // Sync to Google Tasks if enabled
        if (pluginApi.pluginSettings.syncEnabled && pluginApi.pluginSettings.googleAccessToken && pluginApi.pluginSettings.googleTaskListId) {
          ensureValidToken(function(error, accessToken) {
            if (!error) {
              syncTodoToGoogle(newTodo, accessToken, pluginApi.pluginSettings.googleTaskListId);
            }
          });
        }
      }
    }

    function addTodoDefault(text: string) {
      addTodo(text, 0);
    }

    function toggleTodo(id: int) {
      if (pluginApi && id >= 0) {
        var todos = pluginApi.pluginSettings.todos || [];
        var todoFound = false;
        var todo = null;

        for (var i = 0; i < todos.length; i++) {
          if (todos[i].id === id) {
            todos[i].completed = !todos[i].completed;
            todo = todos[i];
            todo.needsSync = true;
            todoFound = true;
            break;
          }
        }

        if (todoFound) {
          pluginApi.pluginSettings.todos = todos;

          var completedCount = 0;
          for (var j = 0; j < todos.length; j++) {
            if (todos[j].completed) {
              completedCount++;
            }
          }
          pluginApi.pluginSettings.completedCount = completedCount;
          pluginApi.saveSettings();

          ToastService.showNotice("Todo status changed");
          
          // Sync to Google Tasks if enabled
          if (pluginApi.pluginSettings.syncEnabled && pluginApi.pluginSettings.googleAccessToken && pluginApi.pluginSettings.googleTaskListId && todo) {
            ensureValidToken(function(error, accessToken) {
              if (!error) {
                syncTodoToGoogle(todo, accessToken, pluginApi.pluginSettings.googleTaskListId);
              }
            });
          }
        } else {
          ToastService.showError("Todo not found: " + id);
        }
      }
    }

    function clearCompleted() {
      if (pluginApi) {
        var todos = pluginApi.pluginSettings.todos || [];
        var activeTodos = todos.filter(todo => !todo.completed);

        pluginApi.pluginSettings.todos = activeTodos;
        pluginApi.pluginSettings.count = activeTodos.length;
        pluginApi.pluginSettings.completedCount = 0;
        pluginApi.saveSettings();

        var clearedCount = todos.length - activeTodos.length;
        ToastService.showNotice("Cleared " + clearedCount + " completed todos");
        
        // Full sync after clearing
        if (pluginApi.pluginSettings.syncEnabled) {
          syncWithGoogleTasks();
        }
      }
    }

    function removeTodo(id: int) {
      if (pluginApi && id >= 0) {
        var todos = pluginApi.pluginSettings.todos || [];
        var indexToRemove = -1;
        var todoToRemove = null;

        for (var i = 0; i < todos.length; i++) {
          if (todos[i].id === id) {
            indexToRemove = i;
            todoToRemove = todos[i];
            Logger.i("TodoGoogle", "Found todo at index: " + i);
            break;
          }
        }

        if (indexToRemove !== -1) {
          todos.splice(indexToRemove, 1);

          pluginApi.pluginSettings.todos = todos;
          pluginApi.pluginSettings.count = todos.length;

          // Recalculate completed count after removal
          var completedCount = 0;
          for (var j = 0; j < todos.length; j++) {
            if (todos[j].completed) {
              completedCount++;
            }
          }
          pluginApi.pluginSettings.completedCount = completedCount;
          pluginApi.saveSettings();
          ToastService.showNotice("Removed todo");
          
          // Delete from Google Tasks if synced
          if (todoToRemove && todoToRemove.googleTaskId && pluginApi.pluginSettings.syncEnabled && pluginApi.pluginSettings.googleAccessToken && pluginApi.pluginSettings.googleTaskListId) {
            ensureValidToken(function(error, accessToken) {
              if (!error) {
                GoogleTasksAPI.deleteTask(pluginApi.pluginSettings.googleTaskListId, todoToRemove.googleTaskId, accessToken, function(deleteError) {
                  if (deleteError) {
                    Logger.e("TodoGoogle", "Failed to delete task from Google: " + deleteError);
                  }
                });
              }
            });
          }
        } else {
          Logger.e("TodoGoogle", "Todo with ID " + id + " not found");
          ToastService.showError("Todo not found: " + id);
        }
      } else {
        Logger.e("TodoGoogle", "Invalid pluginApi or ID for removeTodo");
      }
    }

    function syncNow() {
      if (pluginApi?.pluginSettings?.syncEnabled) {
        syncWithGoogleTasks();
      } else {
        ToastService.showError("Sync is not enabled");
      }
    }

    function connectGoogle() {
      // This will be handled in Settings.qml
      Logger.i("TodoGoogle", "Connect Google called - handled in Settings");
    }

    function disconnectGoogle() {
      if (pluginApi) {
        pluginApi.pluginSettings.googleAccessToken = "";
        pluginApi.pluginSettings.googleRefreshToken = "";
        pluginApi.pluginSettings.googleTaskListId = "";
        pluginApi.pluginSettings.syncEnabled = false;
        pluginApi.pluginSettings.syncStatus = "disconnected";
        pluginApi.pluginSettings.syncError = null;
        pluginApi.saveSettings();
        syncTimer.stop();
        ToastService.showNotice("Disconnected from Google Tasks");
      }
    }
  }
}
