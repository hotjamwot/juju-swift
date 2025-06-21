/**
 * Event System for Juju Dashboard
 * Provides centralized event handling, notifications, and modal management
 */

class EventSystem {
    constructor() {
        this.events = {};
        this.notificationContainer = null;
        this.modal = null;
        this.init();
    }

    init() {
        this.notificationContainer = document.getElementById('notification-container');
        this.modal = document.getElementById('confirmation-modal');
        this.setupModalListeners();
    }

    // Event System
    on(event, callback) {
        if (!this.events[event]) {
            this.events[event] = [];
        }
        this.events[event].push(callback);
    }

    off(event, callback) {
        if (!this.events[event]) return;
        const index = this.events[event].indexOf(callback);
        if (index > -1) {
            this.events[event].splice(index, 1);
        }
    }

    emit(event, data) {
        if (!this.events[event]) return;
        this.events[event].forEach(callback => {
            try {
                callback(data);
            } catch (error) {
                console.error(`Error in event handler for ${event}:`, error);
            }
        });
    }

    // Notification System
    showNotification(type, title, message, duration = 5000) {
        if (!this.notificationContainer) return;

        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        
        const icon = this.getNotificationIcon(type);
        
        notification.innerHTML = `
            <div class="notification-icon">${icon}</div>
            <div class="notification-content">
                <div class="notification-title">${title}</div>
                <div class="notification-message">${message}</div>
            </div>
            <button class="notification-close" onclick="this.parentElement.remove()">&times;</button>
        `;

        this.notificationContainer.appendChild(notification);

        // Trigger animation
        setTimeout(() => notification.classList.add('show'), 10);

        // Auto-remove after duration
        if (duration > 0) {
            setTimeout(() => {
                notification.classList.remove('show');
                setTimeout(() => notification.remove(), 300);
            }, duration);
        }

        return notification;
    }

    getNotificationIcon(type) {
        const icons = {
            success: '✓',
            error: '✕',
            warning: '⚠',
            info: 'ℹ'
        };
        return icons[type] || 'ℹ';
    }

    // Modal System
    showConfirmation(title, message, onConfirm, onCancel) {
        if (!this.modal) return Promise.reject('Modal not found');

        return new Promise((resolve, reject) => {
            const titleEl = document.getElementById('modal-title');
            const messageEl = document.getElementById('modal-message');
            const confirmBtn = document.getElementById('modal-confirm');
            const cancelBtn = document.getElementById('modal-cancel');
            const closeBtn = document.getElementById('modal-close');

            if (titleEl) titleEl.textContent = title;
            if (messageEl) messageEl.textContent = message;

            const handleConfirm = () => {
                this.hideModal();
                cleanup();
                if (onConfirm) onConfirm();
                resolve(true);
            };

            const handleCancel = () => {
                this.hideModal();
                cleanup();
                if (onCancel) onCancel();
                resolve(false);
            };

            const cleanup = () => {
                confirmBtn.removeEventListener('click', handleConfirm);
                cancelBtn.removeEventListener('click', handleCancel);
                closeBtn.removeEventListener('click', handleCancel);
                this.modal.removeEventListener('click', handleOverlayClick);
            };

            const handleOverlayClick = (e) => {
                if (e.target === this.modal) {
                    handleCancel();
                }
            };

            confirmBtn.addEventListener('click', handleConfirm);
            cancelBtn.addEventListener('click', handleCancel);
            closeBtn.addEventListener('click', handleCancel);
            this.modal.addEventListener('click', handleOverlayClick);

            this.showModal();
        });
    }

    showModal() {
        if (this.modal) {
            this.modal.classList.add('show');
            document.body.style.overflow = 'hidden';
        }
    }

    hideModal() {
        if (this.modal) {
            this.modal.classList.remove('show');
            document.body.style.overflow = '';
        }
    }

    setupModalListeners() {
        if (!this.modal) return;

        // Close modal on escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.modal.classList.contains('show')) {
                this.hideModal();
            }
        });
    }

    // Enhanced Deletion Utilities
    async deleteWithConfirmation(type, id, name, deleteFunction) {
        const title = `Delete ${type}`;
        const message = `Are you sure you want to delete "${name}"? This action cannot be undone.`;
        
        const confirmed = await this.showConfirmation(title, message);
        
        if (!confirmed) {
            return { success: false, cancelled: true };
        }

        try {
            // Show loading state
            this.showNotification('info', 'Deleting...', `Deleting ${type.toLowerCase()} "${name}"...`, 0);
            
            const result = await deleteFunction(id);
            
            if (result && result.success) {
                this.showNotification('success', 'Deleted', `${type} "${name}" has been deleted successfully.`);
                this.emit(`${type.toLowerCase()}Deleted`, { id, name });
                return { success: true };
            } else {
                const errorMsg = result && result.error ? result.error : 'Unknown error occurred';
                this.showNotification('error', 'Delete Failed', `Failed to delete ${type.toLowerCase()}: ${errorMsg}`);
                return { success: false, error: errorMsg };
            }
        } catch (error) {
            console.error(`Error deleting ${type.toLowerCase()}:`, error);
            this.showNotification('error', 'Delete Failed', `An error occurred while deleting the ${type.toLowerCase()}.`);
            return { success: false, error: error.message };
        }
    }

    // Fallback deletion methods
    async deleteSessionWithFallback(sessionId, sessionInfo) {
        const deleteMethods = [
            // Method 1: Direct API call
            async (id) => {
                if (window.jujuApi && typeof window.jujuApi.deleteSession === 'function') {
                    return await window.jujuApi.deleteSession(id);
                }
                throw new Error('Delete API not available');
            },
            // Method 2: Manual CSV manipulation (fallback)
            async (id) => {
                return await this.manualDeleteSession(id);
            }
        ];

        for (let i = 0; i < deleteMethods.length; i++) {
            try {
                const result = await this.deleteWithConfirmation(
                    'Session', 
                    sessionId, 
                    sessionInfo, 
                    deleteMethods[i]
                );
                
                if (result.success) {
                    return result;
                }
                
                if (result.cancelled) {
                    return result;
                }
                
                console.warn(`Delete method ${i + 1} failed, trying next method...`);
            } catch (error) {
                console.error(`Delete method ${i + 1} error:`, error);
                if (i === deleteMethods.length - 1) {
                    throw error;
                }
            }
        }
    }

    async deleteProjectWithFallback(projectId, projectName) {
        const deleteMethods = [
            // Method 1: Direct API call
            async (id) => {
                if (window.jujuApi && typeof window.jujuApi.deleteProject === 'function') {
                    return await window.jujuApi.deleteProject(id);
                }
                throw new Error('Delete API not available');
            },
            // Method 2: Manual JSON manipulation (fallback)
            async (id) => {
                return await this.manualDeleteProject(id);
            }
        ];

        for (let i = 0; i < deleteMethods.length; i++) {
            try {
                const result = await this.deleteWithConfirmation(
                    'Project', 
                    projectId, 
                    projectName, 
                    deleteMethods[i]
                );
                
                if (result.success) {
                    return result;
                }
                
                if (result.cancelled) {
                    return result;
                }
                
                console.warn(`Delete method ${i + 1} failed, trying next method...`);
            } catch (error) {
                console.error(`Delete method ${i + 1} error:`, error);
                if (i === deleteMethods.length - 1) {
                    throw error;
                }
            }
        }
    }

    // Manual deletion fallbacks (these would need to be implemented based on your data structure)
    async manualDeleteSession(sessionId) {
        // This would need to be implemented based on your CSV structure
        // For now, we'll throw an error to indicate it's not implemented
        throw new Error('Manual session deletion not implemented');
    }

    async manualDeleteProject(projectId) {
        // This would need to be implemented based on your JSON structure
        // For now, we'll throw an error to indicate it's not implemented
        throw new Error('Manual project deletion not implemented');
    }
}

// Create global instance
const eventSystem = new EventSystem();

// Export for use in other modules
export default eventSystem; 