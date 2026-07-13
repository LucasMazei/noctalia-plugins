/**
 * Google Tasks API integration module
 * Handles authentication, token management, and all API operations
 * 
 * Note: The .pragma library directive is QML JavaScript syntax.
 * TypeScript linter errors on this line are expected and can be ignored.
 */

.pragma library

var GOOGLE_OAUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth";
var GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
var GOOGLE_TASKS_API_BASE = "https://tasks.googleapis.com/tasks/v1";
var GOOGLE_SCOPE = "https://www.googleapis.com/auth/tasks";
var REDIRECT_URI = "http://localhost:8080";

/**
 * Generate OAuth authorization URL
 * @param {string} clientId - Google OAuth client ID
 * @returns {string} Authorization URL
 */
function generateAuthUrl(clientId) {
    if (!clientId) {
        return "";
    }

    var params = {
        "client_id": clientId,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": GOOGLE_SCOPE,
        "access_type": "offline",
        "prompt": "consent"
    };

    var queryString = Object.keys(params).map(function (key) {
        return encodeURIComponent(key) + "=" + encodeURIComponent(params[key]);
    }).join("&");

    return GOOGLE_OAUTH_URL + "?" + queryString;
}

/**
 * Exchange authorization code for access and refresh tokens
 * @param {string} code - Authorization code from OAuth flow
 * @param {string} clientId - Google OAuth client ID
 * @param {string} clientSecret - Google OAuth client secret
 * @param {function} callback - Callback function(error, tokens)
 */
function authenticateWithCode(code, clientId, clientSecret, callback) {
    if (!code || !clientId || !clientSecret) {
        callback("Missing required parameters", null);
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText.toString());
                    if (response.access_token) {
                        callback(null, {
                            accessToken: response.access_token,
                            refreshToken: response.refresh_token || "", // May be empty if user already granted consent
                            expiresIn: response.expires_in || 3600,
                            tokenType: response.token_type || "Bearer"
                        });
                    } else {
                        callback("Invalid token response: " + xhr.responseText, null);
                    }
                } catch (e) {
                    callback("Failed to parse token response: " + e.toString(), null);
                }
            } else {
                callback("Token exchange failed: " + xhr.status + " - " + xhr.responseText, null);
            }
        }
    };

    var data = {
        "code": code,
        "client_id": clientId,
        "client_secret": clientSecret,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code"
    };

    var formData = Object.keys(data).map(function (key) {
        return encodeURIComponent(key) + "=" + encodeURIComponent(data[key]);
    }).join("&");

    xhr.open("POST", GOOGLE_TOKEN_URL);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    xhr.send(formData);
}

/**
 * Refresh access token using refresh token
 * @param {string} refreshToken - Refresh token
 * @param {string} clientId - Google OAuth client ID
 * @param {string} clientSecret - Google OAuth client secret
 * @param {function} callback - Callback function(error, accessToken)
 */
function refreshAccessToken(refreshToken, clientId, clientSecret, callback) {
    if (!refreshToken || !clientId || !clientSecret) {
        callback("Missing required parameters", null);
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText.toString());
                    if (response.access_token) {
                        callback(null, {
                            accessToken: response.access_token,
                            expiresIn: response.expires_in || 3600,
                            tokenType: response.token_type || "Bearer"
                        });
                    } else {
                        callback("Invalid refresh response: " + xhr.responseText, null);
                    }
                } catch (e) {
                    callback("Failed to parse refresh response: " + e.toString(), null);
                }
            } else {
                callback("Token refresh failed: " + xhr.status + " - " + xhr.responseText, null);
            }
        }
    };

    var data = {
        "refresh_token": refreshToken,
        "client_id": clientId,
        "client_secret": clientSecret,
        "grant_type": "refresh_token"
    };

    var formData = Object.keys(data).map(function (key) {
        return encodeURIComponent(key) + "=" + encodeURIComponent(data[key]);
    }).join("&");

    xhr.open("POST", GOOGLE_TOKEN_URL);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    xhr.send(formData);
}

/**
 * Make authenticated API request
 * @param {string} method - HTTP method (GET, POST, PUT, PATCH, DELETE)
 * @param {string} url - API endpoint URL
 * @param {string} accessToken - Access token
 * @param {object} data - Request body data (optional)
 * @param {function} callback - Callback function(error, response)
 */
function makeApiRequest(method, url, accessToken, data, callback) {
    if (!accessToken) {
        callback("No access token provided", null);
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    var response = xhr.responseText ? JSON.parse(xhr.responseText.toString()) : {};
                    callback(null, response);
                } catch (e) {
                    callback("Failed to parse response: " + e.toString(), null);
                }
            } else if (xhr.status === 401) {
                callback("Unauthorized - token may be expired", null);
            } else {
                callback("API request failed: " + xhr.status + " - " + xhr.responseText, null);
            }
        }
    };

    xhr.open(method, url);
    xhr.setRequestHeader("Authorization", "Bearer " + accessToken);
    xhr.setRequestHeader("Content-Type", "application/json");

    if (data && (method === "POST" || method === "PUT" || method === "PATCH")) {
        xhr.send(JSON.stringify(data));
    } else {
        xhr.send();
    }
}

/**
 * Get all task lists
 * @param {string} accessToken - Access token
 * @param {function} callback - Callback function(error, taskLists)
 */
function getTaskLists(accessToken, callback) {
    var url = GOOGLE_TASKS_API_BASE + "/users/@me/lists";
    makeApiRequest("GET", url, accessToken, null, callback);
}

/**
 * Get tasks from a task list
 * @param {string} taskListId - Task list ID
 * @param {string} accessToken - Access token
 * @param {function} callback - Callback function(error, tasks)
 */
function getTasks(taskListId, accessToken, callback) {
    if (!taskListId) {
        callback("Task list ID is required", null);
        return;
    }

    var url = GOOGLE_TASKS_API_BASE + "/lists/" + encodeURIComponent(taskListId) + "/tasks?showCompleted=true&showHidden=true";
    makeApiRequest("GET", url, accessToken, null, callback);
}

/**
 * Create a new task
 * @param {string} taskListId - Task list ID
 * @param {object} task - Task object with title, notes, etc.
 * @param {string} accessToken - Access token
 * @param {function} callback - Callback function(error, createdTask)
 */
function createTask(taskListId, task, accessToken, callback) {
    if (!taskListId) {
        callback("Task list ID is required", null);
        return;
    }

    var taskData = {
        title: task.title || task.text || "",
        notes: task.notes || "",
        status: task.completed ? "completed" : "needsAction"
    };

    if (task.due) {
        taskData.due = task.due;
    }

    var url = GOOGLE_TASKS_API_BASE + "/lists/" + encodeURIComponent(taskListId) + "/tasks";
    makeApiRequest("POST", url, accessToken, taskData, callback);
}

/**
 * Update an existing task
 * @param {string} taskListId - Task list ID
 * @param {string} taskId - Task ID
 * @param {object} task - Task object with updated fields
 * @param {string} accessToken - Access token
 * @param {function} callback - Callback function(error, updatedTask)
 */
function updateTask(taskListId, taskId, task, accessToken, callback) {
    if (!taskListId || !taskId) {
        callback("Task list ID and task ID are required", null);
        return;
    }

    var taskData = {};
    if (task.title !== undefined || task.text !== undefined) {
        taskData.title = task.title || task.text || "";
    }
    if (task.notes !== undefined) {
        taskData.notes = task.notes;
    }
    if (task.completed !== undefined) {
        taskData.status = task.completed ? "completed" : "needsAction";
    }
    if (task.due !== undefined) {
        taskData.due = task.due;
    }

    var url = GOOGLE_TASKS_API_BASE + "/lists/" + encodeURIComponent(taskListId) + "/tasks/" + encodeURIComponent(taskId);
    makeApiRequest("PATCH", url, accessToken, taskData, callback);
}

/**
 * Delete a task
 * @param {string} taskListId - Task list ID
 * @param {string} taskId - Task ID
 * @param {string} accessToken - Access token
 * @param {function} callback - Callback function(error)
 */
function deleteTask(taskListId, taskId, accessToken, callback) {
    if (!taskListId || !taskId) {
        callback("Task list ID and task ID are required", null);
        return;
    }

    var url = GOOGLE_TASKS_API_BASE + "/lists/" + encodeURIComponent(taskListId) + "/tasks/" + encodeURIComponent(taskId);
    makeApiRequest("DELETE", url, accessToken, null, callback);
}

/**
 * Mark a task as completed
 * @param {string} taskListId - Task list ID
 * @param {string} taskId - Task ID
 * @param {string} accessToken - Access token
 * @param {function} callback - Callback function(error, updatedTask)
 */
function completeTask(taskListId, taskId, accessToken, callback) {
    updateTask(taskListId, taskId, { completed: true }, accessToken, callback);
}
