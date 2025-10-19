import { formatMinutesToHoursMinutes } from './utils.js'; // Import necessary utils
import eventSystem from './event-system.js'; // Import the event system

// Store reference to table body - assume it exists in the DOM when functions are called
const recentSessionsBody = document.getElementById('recent-sessions-body');

// --- Tab Functionality ---
function setupTabs() {
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            // Deactivate all tabs and content
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            // Activate clicked tab and corresponding content
            tab.classList.add('active');
            const contentId = tab.dataset.tab;
            const contentElement = document.getElementById(contentId);
            if (contentElement) {
                contentElement.classList.add('active');
            }
        });
    });
}

// --- Sessions Table ---
/**
 * Updates the sessions table body with the provided session data.
 * Assumes the provided sessions are already filtered, sorted, and paginated.
 * @param {Array<Object>} visibleSessions - The array of session objects to display.
 * @param {Function} refreshDashboardDataCallback - Callback function to refresh all dashboard data on edit.
 */
function updateSessionsTable(visibleSessions, refreshDashboardDataCallback) {
    if (!recentSessionsBody) {
        return;
    }

    // Clear previous content
    recentSessionsBody.innerHTML = '';

    // Check if there are sessions to display for the current page/filter
    if (!visibleSessions || visibleSessions.length === 0) {
        recentSessionsBody.innerHTML = `
            <tr><td colspan="7" class="no-data">No sessions match the current filter or page.</td></tr>`;
        // Do not add edit listeners if there's no data
        return;
    }

    // Add each session row to the table
    visibleSessions.forEach(session => {
        const row = document.createElement('tr');
        row.setAttribute('data-session-key', `${session.id}-${session.date}-${session.start_time}`);

        let formattedDate = "Invalid Date";
        try {
            const dateObj = new Date(session.date + 'T00:00:00');
             if (!isNaN(dateObj.getTime())) {
                 // Format date locally instead of using UTC-based toISOString()
                 const year = dateObj.getFullYear();
                 const month = (dateObj.getMonth() + 1).toString().padStart(2, '0'); // +1 because months are 0-indexed
                 const day = dateObj.getDate().toString().padStart(2, '0');
                 formattedDate = `${year}-${month}-${day}`;
             }
        } catch (e) { /* Keep "Invalid Date" */ }

        const startTime = typeof session.start_time === 'string' ? session.start_time.slice(0, 5) : '??:??';
        const endTime = typeof session.end_time === 'string' ? session.end_time.slice(0, 5) : '??:??';
        const projectName = session.project || 'N/A';
        const notes = session.notes || '';
        const mood = (session.mood !== undefined && session.mood !== null && session.mood !== '') ? String(session.mood) : '';
        const sessionInfo = `${projectName} on ${formattedDate}`;

        row.innerHTML = `
            <td class="editable" data-field="date" data-id="${session.id}">${formattedDate}</td>
            <td class="editable" data-field="project" data-id="${session.id}">${projectName}</td>
            <td data-field="duration_minutes" data-id="${session.id}">${formatMinutesToHoursMinutes(session.duration_minutes)}</td>
            <td class="editable" data-field="start_time" data-id="${session.id}">${startTime}</td>
            <td class="editable" data-field="end_time" data-id="${session.id}">${endTime}</td>
            <td class="editable" data-field="notes" data-id="${session.id}">${notes}</td>
            <td class="editable" data-field="mood" data-id="${session.id}">${mood}</td>
            <td class="actions">
                <button class="btn btn-delete" data-id="${session.id}" data-info="${sessionInfo}" title="Delete Session">×</button>
            </td>
        `;
        recentSessionsBody.appendChild(row);
    });

    // Add both edit and delete listeners
    addEditListeners(refreshDashboardDataCallback);
    addDeleteListeners(refreshDashboardDataCallback);
}

// Add click listeners to editable table cells
function addEditListeners(refreshDashboardDataCallback) {
    document.querySelectorAll('#recent-sessions-body td.editable').forEach(cell => {
        // Bind the callback function to the event handler
        const boundHandleCellClick = handleCellClick.bind(cell, refreshDashboardDataCallback);
        // Remove any old listeners first
        cell.removeEventListener('click', cell._boundHandleCellClick); // Use stored reference if exists
        // Add the new listener
        cell.addEventListener('click', boundHandleCellClick);
        // Store the bound function reference on the element for later removal
        cell._boundHandleCellClick = boundHandleCellClick;
    });
}

// Handles the click on an editable cell
async function handleCellClick(refreshDashboardDataCallback) {
    // 'this' refers to the clicked cell (td)
    if (this.querySelector('input, textarea, select')) return;

    const currentValue = this.textContent;
    const field = this.dataset.field;
    this.setAttribute('data-original-value', currentValue);

    let inputElement;
    
    // Add special handling for project field
    if (field === 'project') {
        inputElement = document.createElement('select');
        inputElement.classList.add('inline-edit-input');
        inputElement.style.width = '100%';
        inputElement.style.height = '100%';
        
        try {
            const projectNames = await window.jujuApi.getProjectNames();
            
            inputElement.innerHTML = '';
            
            const emptyOption = document.createElement('option');
            emptyOption.value = '';
            emptyOption.text = '-- Select Project --';
            inputElement.add(emptyOption);
            
            projectNames.forEach(name => {
                const option = document.createElement('option');
                option.value = name;
                option.text = name;
                if (name === currentValue) {
                    option.selected = true;
                }
                inputElement.add(option);
            });
        } catch (error) {
            eventSystem.showNotification('error', 'Error', 'Failed to load project names');
        }
    } else if (field === 'start_time' || field === 'end_time') {
        inputElement = document.createElement('input');
        inputElement.type = 'time';
        inputElement.value = /^\d{2}:\d{2}$/.test(currentValue) ? currentValue : '00:00';
    } else if (field === 'date') {
        inputElement = document.createElement('input');
        inputElement.type = 'date';
        inputElement.value = /^\d{4}-\d{2}-\d{2}$/.test(currentValue) ? currentValue : new Date().toISOString().slice(0,10);
    } else if (field === 'notes') {
        inputElement = document.createElement('textarea');
        inputElement.value = currentValue;
        inputElement.rows = 2;
    } else if (field === 'mood') {
        inputElement = document.createElement('select');
        inputElement.classList.add('inline-edit-input');
        inputElement.style.width = '100%';
        inputElement.style.height = '2em';
        // Add an empty option for blank/none
        const emptyOption = document.createElement('option');
        emptyOption.value = '';
        emptyOption.text = '--';
        inputElement.appendChild(emptyOption);
        for (let i = 0; i <= 10; i++) {
            const option = document.createElement('option');
            option.value = i;
            option.text = i;
            if (String(i) === currentValue) option.selected = true;
            inputElement.appendChild(option);
        }
        this.innerHTML = '';
        this.appendChild(inputElement);
        inputElement.focus();
    } else {
        inputElement = document.createElement('input');
        inputElement.type = 'text';
        inputElement.value = currentValue;
    }
    inputElement.classList.add('inline-edit-input');
    inputElement.style.width = '100%';
    inputElement.style.boxSizing = 'border-box';
    if (inputElement.tagName === 'TEXTAREA') {
      inputElement.rows = 1;
      inputElement.style.resize = 'none';
      inputElement.style.minHeight = '32px';
      inputElement.style.maxHeight = '80px';
      inputElement.style.lineHeight = '1.4';
    }

    this.innerHTML = '';
    this.appendChild(inputElement);
    inputElement.focus();
    if (inputElement.type === 'text') inputElement.select();

    // Bind the callback to the event handlers for the input element
    const boundHandleCellUpdate = handleCellUpdate.bind(inputElement, refreshDashboardDataCallback);
    const boundHandleInputKeydown = handleInputKeydown.bind(inputElement, refreshDashboardDataCallback);

    inputElement.addEventListener('blur', boundHandleCellUpdate);
    inputElement.addEventListener('keydown', boundHandleInputKeydown);

    // Store bound functions for potential removal on Escape
    inputElement._boundBlurHandler = boundHandleCellUpdate;
    inputElement._boundKeydownHandler = boundHandleInputKeydown;
}

// Handles keydown events on the inline editor
async function handleInputKeydown(refreshDashboardDataCallback, event) { // Receive callback
    // 'this' refers to the input/textarea element
    if (event.key === 'Enter') {
        if (this.tagName === 'TEXTAREA' && event.shiftKey) return;
        event.preventDefault();
        await handleCellUpdate.call(this, refreshDashboardDataCallback);
    } else if (event.key === 'Escape') {
        const cellElement = this.parentElement;
        const originalValue = cellElement.getAttribute('data-original-value');
        // Remove listeners before changing content
        this.removeEventListener('blur', this._boundBlurHandler);
        this.removeEventListener('keydown', this._boundKeydownHandler);
        cellElement.textContent = originalValue;
        cellElement.removeAttribute('data-original-value');
    }
}

// Handles the update logic when an input field blurs or Enter is pressed
async function handleCellUpdate(refreshDashboardDataCallback) {
    const cell = this.parentElement;
    if (!cell || !cell.dataset) {
        this.removeEventListener('blur', this._boundBlurHandler);
        this.removeEventListener('keydown', this._boundKeydownHandler);
        try { this.remove(); } catch(e) {}
        return;
    }

    const newValue = this.value.trim();
    const originalValue = cell.getAttribute('data-original-value');
    const id = cell.dataset.id;
    const field = cell.dataset.field;

    this.removeEventListener('blur', this._boundBlurHandler);
    this.removeEventListener('keydown', this._boundKeydownHandler);

    if (newValue === originalValue) {
        cell.textContent = originalValue;
        cell.removeAttribute('data-original-value');
        return;
    }

    try {
        const result = await window.jujuApi.updateSession(id, field, newValue);
        cell.classList.add('success');
        setTimeout(() => cell.classList.remove('success'), 1000);
        
        eventSystem.showNotification('success', 'Updated', `Session ${field} updated successfully`);
        
        if (window.jujuApi && typeof window.jujuApi.loadSessions === 'function') {
            window.jujuApi.loadSessions();
        } else if (typeof refreshDashboardDataCallback === 'function') {
            refreshDashboardDataCallback();
        }
    } catch (error) {
        cell.classList.add('error');
        setTimeout(() => cell.classList.remove('error'), 1200);
        cell.textContent = originalValue;
        
        eventSystem.showNotification('error', 'Update Failed', `Failed to update session: ${error.message}`);
    } finally {
        cell.removeAttribute('data-original-value');
    }
}

// Enhanced delete functionality using the event system
function addDeleteListeners(refreshDashboardDataCallback) {
    document.querySelectorAll('#recent-sessions-body .btn-delete').forEach(button => {
        // Remove any previous click listeners
        if (button._boundDeleteHandler) {
            button.removeEventListener('click', button._boundDeleteHandler);
        }
        
        // Create a new handler using the event system
        const handler = async (e) => {
            e.preventDefault();
            e.stopPropagation();
            
            const id = e.target.dataset.id;
            const sessionInfo = e.target.dataset.info || `Session ${id}`;
            
            if (!id) {
                eventSystem.showNotification('error', 'Error', 'Session ID not found');
                return;
            }
            
            try {
                // Use the event system's enhanced deletion with fallback
                const result = await eventSystem.deleteSessionWithFallback(id, sessionInfo);
                
                if (result.success) {
                    // Refresh the dashboard data
                    if (typeof refreshDashboardDataCallback === 'function') {
                        refreshDashboardDataCallback();
                    }
                } else if (!result.cancelled) {
                    // Error was already handled by the event system
                    console.error('Session deletion failed:', result.error);
                }
            } catch (error) {
                eventSystem.showNotification('error', 'Delete Failed', 'An unexpected error occurred while deleting the session');
            }
        };
        
        button.addEventListener('click', handler);
        button._boundDeleteHandler = handler;
    });
}

export {
    setupTabs,
    updateSessionsTable
};
