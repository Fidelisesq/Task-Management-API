// Configuration - UPDATE THIS WITH YOUR ALB DNS NAME
const API_BASE_URL = 'https://api.fozdigitalz.com';

// State
let currentUser = null;
let currentFilter = 'all';
let editingTaskId = null;
let allTasks = [];

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    checkAuth();
    setupEventListeners();
});

// Check if user is authenticated
function checkAuth() {
    const token = localStorage.getItem('token');
    const username = localStorage.getItem('username');
    
    if (token && username) {
        currentUser = { token, username };
        showDashboard();
        loadTasks();
    } else {
        showAuthPage();
    }
}

// Setup event listeners
function setupEventListeners() {
    // Login form
    document.getElementById('login-form').addEventListener('submit', handleLogin);
    
    // Register form
    document.getElementById('register-form').addEventListener('submit', handleRegister);
    
    // Task form
    document.getElementById('task-form').addEventListener('submit', handleTaskSubmit);
}

// Show/Hide pages
function showAuthPage() {
    document.getElementById('auth-page').classList.add('active');
    document.getElementById('dashboard-page').classList.remove('active');
}

function showDashboard() {
    document.getElementById('auth-page').classList.remove('active');
    document.getElementById('dashboard-page').classList.add('active');
    document.getElementById('username-display').textContent = currentUser.username;
}

// Auth tab switching
function showLogin() {
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-btn')[0].classList.add('active');
    document.getElementById('login-form').classList.add('active');
    document.getElementById('register-form').classList.remove('active');
    clearError('login-error');
}

function showRegister() {
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-btn')[1].classList.add('active');
    document.getElementById('login-form').classList.remove('active');
    document.getElementById('register-form').classList.add('active');
    clearError('register-error');
}

// Handle login
async function handleLogin(e) {
    e.preventDefault();
    clearError('login-error');
    
    const username = document.getElementById('login-username').value;
    const password = document.getElementById('login-password').value;
    
    try {
        const response = await fetch(`${API_BASE_URL}/auth/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            localStorage.setItem('token', data.token);
            localStorage.setItem('username', data.user.username);
            currentUser = { token: data.token, username: data.user.username };
            showDashboard();
            loadTasks();
        } else {
            showError('login-error', data.message || 'Login failed');
        }
    } catch (error) {
        showError('login-error', 'Network error. Please check your connection.');
        console.error('Login error:', error);
    }
}

// Handle register
async function handleRegister(e) {
    e.preventDefault();
    clearError('register-error');
    
    const username = document.getElementById('register-username').value;
    const email = document.getElementById('register-email').value;
    const password = document.getElementById('register-password').value;
    
    try {
        const response = await fetch(`${API_BASE_URL}/auth/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, email, password })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            // Auto-login after registration
            document.getElementById('login-username').value = username;
            document.getElementById('login-password').value = password;
            showLogin();
            showError('login-error', 'Registration successful! Please login.');
            document.getElementById('login-error').style.color = '#10b981';
        } else {
            showError('register-error', data.message || 'Registration failed');
        }
    } catch (error) {
        showError('register-error', 'Network error. Please check your connection.');
        console.error('Register error:', error);
    }
}

// Logout
function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    currentUser = null;
    allTasks = [];
    showAuthPage();
}

// Load tasks
async function loadTasks() {
    try {
        const response = await fetch(`${API_BASE_URL}/tasks`, {
            headers: {
                'Authorization': `Bearer ${currentUser.token}`
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            allTasks = data.tasks;
            renderTasks();
        } else if (response.status === 401) {
            logout();
        } else {
            console.error('Failed to load tasks');
        }
    } catch (error) {
        console.error('Load tasks error:', error);
    }
}

// Render tasks
function renderTasks() {
    const container = document.getElementById('tasks-container');
    const emptyState = document.getElementById('empty-state');
    
    // Filter tasks
    const filteredTasks = currentFilter === 'all' 
        ? allTasks 
        : allTasks.filter(task => task.status === currentFilter);
    
    if (filteredTasks.length === 0) {
        container.innerHTML = '';
        emptyState.classList.add('active');
        return;
    }
    
    emptyState.classList.remove('active');
    
    container.innerHTML = filteredTasks.map(task => `
        <div class="task-card" data-status="${task.status}">
            <div class="task-header">
                <h3 class="task-title">${escapeHtml(task.title)}</h3>
                <span class="task-priority ${task.priority}">${task.priority}</span>
            </div>
            ${task.description ? `<p class="task-description">${escapeHtml(task.description)}</p>` : ''}
            <div class="task-meta">
                <span class="task-status ${task.status}">${formatStatus(task.status)}</span>
                ${task.due_date ? `<span>📅 ${formatDate(task.due_date)}</span>` : ''}
            </div>
            <div class="task-actions">
                <button onclick="editTask(${task.id})" class="btn btn-edit">Edit</button>
                <button onclick="deleteTask(${task.id})" class="btn btn-danger">Delete</button>
            </div>
        </div>
    `).join('');
}

// Filter tasks
function filterTasks(filter, element) {
    currentFilter = filter;
    
    // Update active filter button
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    element.classList.add('active');
    
    renderTasks();
}

// Show add task modal
function showAddTaskModal() {
    editingTaskId = null;
    document.getElementById('modal-title').textContent = 'Add Task';
    document.getElementById('task-form').reset();
    document.getElementById('task-modal').classList.add('active');
    clearError('task-error');
}

// Close task modal
function closeTaskModal() {
    document.getElementById('task-modal').classList.remove('active');
    editingTaskId = null;
}

// Edit task
function editTask(taskId) {
    const task = allTasks.find(t => t.id === taskId);
    if (!task) return;
    
    editingTaskId = taskId;
    document.getElementById('modal-title').textContent = 'Edit Task';
    document.getElementById('task-title').value = task.title;
    document.getElementById('task-description').value = task.description || '';
    document.getElementById('task-priority').value = task.priority;
    document.getElementById('task-status').value = task.status;
    
    if (task.due_date) {
        const date = new Date(task.due_date);
        document.getElementById('task-due-date').value = date.toISOString().slice(0, 16);
    }
    
    document.getElementById('task-modal').classList.add('active');
    clearError('task-error');
}

// Handle task submit (create or update)
async function handleTaskSubmit(e) {
    e.preventDefault();
    clearError('task-error');
    
    const title = document.getElementById('task-title').value;
    const description = document.getElementById('task-description').value;
    const priority = document.getElementById('task-priority').value;
    const status = document.getElementById('task-status').value;
    const dueDate = document.getElementById('task-due-date').value;
    
    const taskData = {
        title,
        description,
        priority,
        status,
        due_date: dueDate || null
    };
    
    try {
        const url = editingTaskId 
            ? `${API_BASE_URL}/tasks/${editingTaskId}`
            : `${API_BASE_URL}/tasks`;
        
        const method = editingTaskId ? 'PUT' : 'POST';
        
        const response = await fetch(url, {
            method,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${currentUser.token}`
            },
            body: JSON.stringify(taskData)
        });
        
        if (response.ok) {
            closeTaskModal();
            loadTasks();
        } else {
            const data = await response.json();
            showError('task-error', data.message || 'Failed to save task');
        }
    } catch (error) {
        showError('task-error', 'Network error. Please try again.');
        console.error('Task submit error:', error);
    }
}

// Delete task
async function deleteTask(taskId) {
    if (!confirm('Are you sure you want to delete this task?')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/tasks/${taskId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${currentUser.token}`
            }
        });
        
        if (response.ok) {
            loadTasks();
        } else {
            alert('Failed to delete task');
        }
    } catch (error) {
        alert('Network error. Please try again.');
        console.error('Delete task error:', error);
    }
}

// Utility functions
function showError(elementId, message) {
    const errorElement = document.getElementById(elementId);
    errorElement.textContent = message;
    errorElement.classList.add('active');
}

function clearError(elementId) {
    const errorElement = document.getElementById(elementId);
    errorElement.textContent = '';
    errorElement.classList.remove('active');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatStatus(status) {
    return status.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
        month: 'short', 
        day: 'numeric',
        year: 'numeric'
    });
}
