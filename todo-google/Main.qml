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

  // Two-way sync with Google Tasks — ALL lists, merged into one view
  function syncWithGoogleTasks() {
    if (isSyncing) {
      Logger.i("TodoGoogle", "Sync already in progress, skipping");
      return;
    }

    if (!pluginApi?.pluginSettings?.syncEnabled) {
      Logger.i("TodoGoogle", "Sync is disabled");
      return;
    }

    isSyncing = true;
    pluginApi.pluginSettings.syncStatus = "syncing";
    pluginApi.pluginSettings.syncError = null;
    pluginApi.saveSettings();

    ensureValidToken(function(tokenError, accessToken) {
      if (tokenError) {
        refreshTokenIfNeeded(function(refreshError, newToken) {
          if (refreshError) {
            failSync("Token refresh failed: " + refreshError);
            return;
          }
          fetchAllLists(newToken);
        });
      } else {
        fetchAllLists(accessToken);
      }
    });
  }

  function failSync(err) {
    isSyncing = false;
    pluginApi.pluginSettings.syncStatus = "error";
    pluginApi.pluginSettings.syncError = err;
    pluginApi.saveSettings();
    Logger.e("TodoGoogle", "Sync failed: " + err);
  }

  // Fetch every task list, then all tasks in each, then merge once
  function fetchAllLists(accessToken) {
    GoogleTasksAPI.getTaskLists(accessToken, function(error, response) {
      if (error) {
        if (error.indexOf("Unauthorized") >= 0 || error.indexOf("401") >= 0) {
          refreshTokenIfNeeded(function(refreshError, newToken) {
            if (refreshError) {
              failSync("Authentication failed: " + refreshError);
              return;
            }
            fetchAllLists(newToken);
          });
          return;
        }
        failSync(error);
        return;
      }

      var lists = (response && response.items) ? response.items : [];
      if (lists.length === 0) {
        failSync("No task lists found");
        return;
      }

      // Default list for brand-new local todos = first list, unless one is already set
      if (!pluginApi.pluginSettings.googleTaskListId) {
        pluginApi.pluginSettings.googleTaskListId = lists[0].id;
      }

      var allGoogleTasks = [];
      var listTitleById = {};
      var fetchedListIds = {};
      var idx = 0;

      function fetchNextList() {
        if (idx >= lists.length) {
          mergeAllTasks(allGoogleTasks, listTitleById, fetchedListIds, accessToken);
          return;
        }
        var list = lists[idx];
        listTitleById[list.id] = list.title;
        GoogleTasksAPI.getTasks(list.id, accessToken, function(err, resp) {
          if (err) {
            Logger.e("TodoGoogle", "Failed to fetch list '" + list.title + "': " + err);
          } else {
            fetchedListIds[list.id] = true;
            var items = (resp && resp.items) ? resp.items : [];
            for (var i = 0; i < items.length; i++) {
              items[i].__listId = list.id;
              items[i].__listTitle = list.title;
              allGoogleTasks.push(items[i]);
            }
          }
          idx++;
          fetchNextList();
        });
      }
      fetchNextList();
    });
  }

  // Global reconcile keyed by (listId + ":" + googleTaskId)
  function mergeAllTasks(googleTasks, listTitleById, fetchedListIds, accessToken) {
    var now = new Date().toISOString();
    var updatedTodos = [];
    var tasksToCreate = [];              // local todos to create in Google
    var tasksToUpdate = [];              // { todo, listId, googleTaskId }

    var localTodos = pluginApi.pluginSettings.todos || [];
    var localByKey = {};
    var localWithoutGoogle = [];
    for (var j = 0; j < localTodos.length; j++) {
      var lt = localTodos[j];
      if (lt.googleTaskId && lt.googleTaskListId) {
        localByKey[lt.googleTaskListId + ":" + lt.googleTaskId] = lt;
      } else {
        localWithoutGoogle.push(lt);
      }
    }

    var seenKeys = {};
    for (var k = 0; k < googleTasks.length; k++) {
      var g = googleTasks[k];
      var key = g.__listId + ":" + g.id;
      seenKeys[key] = true;
      var local = localByKey[key];

      if (local) {
        var gUpdated = new Date(g.updated || 0).getTime();
        var lUpdated = local.lastSyncedAt ? new Date(local.lastSyncedAt).getTime() : 0;

        if (gUpdated > lUpdated) {
          // Google newer -> update local
          local.text = g.title || "";
          local.completed = g.status === "completed";
          local.due = g.due || "";
          local.listTitle = g.__listTitle;
          local.googleTaskListId = g.__listId;
          local.lastSyncedAt = now;
        } else if (lUpdated > gUpdated) {
          // Local newer -> push to Google
          tasksToUpdate.push({ todo: local, listId: g.__listId, googleTaskId: g.id });
          local.listTitle = g.__listTitle;
          local.lastSyncedAt = now;
        } else {
          local.listTitle = g.__listTitle;
          local.due = g.due || local.due || "";
        }
        updatedTodos.push(local);
      } else {
        // New remote task -> create local
        updatedTodos.push({
          id: Date.now() + k,
          text: g.title || "",
          completed: g.status === "completed",
          createdAt: g.updated || now,
          due: g.due || "",
          pageId: 0,
          googleTaskId: g.id,
          googleTaskListId: g.__listId,
          listTitle: g.__listTitle,
          lastSyncedAt: now
        });
      }
    }

    // Local todos that were synced before but are gone remotely.
    // Drop only if their list was successfully fetched (real remote delete);
    // keep them if the list errored this round (avoid data loss on transient failure).
    for (var keyL in localByKey) {
      if (!seenKeys[keyL]) {
        var orphan = localByKey[keyL];
        if (!fetchedListIds[orphan.googleTaskListId]) {
          updatedTodos.push(orphan);
        }
      }
    }

    // Local-only todos (no Google id yet) -> create in Google under their list or the default
    var defaultListId = pluginApi.pluginSettings.googleTaskListId;
    for (var m = 0; m < localWithoutGoogle.length; m++) {
      var lw = localWithoutGoogle[m];
      if (!lw.googleTaskListId) lw.googleTaskListId = defaultListId;
      if (!lw.listTitle) lw.listTitle = listTitleById[lw.googleTaskListId] || "";
      tasksToCreate.push(lw);
      updatedTodos.push(lw);
    }

    pluginApi.pluginSettings.todos = updatedTodos;
    recount(updatedTodos);

    var ci = 0;
    function createNext() {
      if (ci >= tasksToCreate.length) { updateNext(); return; }
      var todo = tasksToCreate[ci];
      GoogleTasksAPI.createTask(todo.googleTaskListId, {
        title: todo.text,
        completed: todo.completed,
        due: todo.due
      }, accessToken, function(err, created) {
        if (err) {
          Logger.e("TodoGoogle", "Failed to create task in Google: " + err);
        } else {
          for (var q = 0; q < updatedTodos.length; q++) {
            if (updatedTodos[q].id === todo.id) {
              updatedTodos[q].googleTaskId = created.id;
              updatedTodos[q].lastSyncedAt = now;
              break;
            }
          }
        }
        ci++;
        createNext();
      });
    }

    var ui = 0;
    function updateNext() {
      if (ui >= tasksToUpdate.length) { finish(); return; }
      var it = tasksToUpdate[ui];
      GoogleTasksAPI.updateTask(it.listId, it.googleTaskId, {
        title: it.todo.text,
        completed: it.todo.completed,
        due: it.todo.due
      }, accessToken, function(err) {
        if (err) Logger.e("TodoGoogle", "Failed to update task in Google: " + err);
        ui++;
        updateNext();
      });
    }

    function finish() {
      pluginApi.pluginSettings.todos = updatedTodos;
      pluginApi.pluginSettings.lastSyncAt = now;
      pluginApi.pluginSettings.syncStatus = "synced";
      pluginApi.pluginSettings.syncError = null;
      pluginApi.saveSettings();
      isSyncing = false;
      Logger.i("TodoGoogle", "Sync completed: " + updatedTodos.length + " todos across all lists");
    }

    if (tasksToCreate.length > 0) createNext();
    else if (tasksToUpdate.length > 0) updateNext();
    else finish();
  }

  function recount(todos) {
    var c = 0;
    for (var p = 0; p < todos.length; p++) {
      if (todos[p].completed) c++;
    }
    pluginApi.pluginSettings.count = todos.length;
    pluginApi.pluginSettings.completedCount = c;
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

        var defaultListId = pluginApi.pluginSettings.googleTaskListId || "";
        var newTodo = {
          id: Date.now(),
          text: text,
          completed: false,
          createdAt: new Date().toISOString(),
          due: "",
          pageId: pageId,
          googleTaskId: "",
          googleTaskListId: defaultListId,
          listTitle: "",
          lastSyncedAt: null,
          needsSync: true
        };

        todos.push(newTodo);

        pluginApi.pluginSettings.todos = todos;
        pluginApi.pluginSettings.count = todos.length;
        pluginApi.saveSettings();

        ToastService.showNotice("Added new todo: " + text);
        
        // Sync to Google Tasks if enabled
        if (pluginApi.pluginSettings.syncEnabled && pluginApi.pluginSettings.googleAccessToken && newTodo.googleTaskListId) {
          ensureValidToken(function(error, accessToken) {
            if (!error) {
              syncTodoToGoogle(newTodo, accessToken, newTodo.googleTaskListId);
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
          if (pluginApi.pluginSettings.syncEnabled && pluginApi.pluginSettings.googleAccessToken && todo) {
            ensureValidToken(function(error, accessToken) {
              if (!error) {
                syncTodoToGoogle(todo, accessToken, todo.googleTaskListId || pluginApi.pluginSettings.googleTaskListId);
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
          if (todoToRemove && todoToRemove.googleTaskId && pluginApi.pluginSettings.syncEnabled && pluginApi.pluginSettings.googleAccessToken && (todoToRemove.googleTaskListId || pluginApi.pluginSettings.googleTaskListId)) {
            ensureValidToken(function(error, accessToken) {
              if (!error) {
                GoogleTasksAPI.deleteTask(todoToRemove.googleTaskListId || pluginApi.pluginSettings.googleTaskListId, todoToRemove.googleTaskId, accessToken, function(deleteError) {
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
