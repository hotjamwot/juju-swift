// Replace the top-level async IIFE with DOMContentLoaded event listener

document.addEventListener('DOMContentLoaded', async () => {
    try {
        // Import modules
        const { updateCharts, destroyCharts } = await import('./src/renderer/dashboard/charts.js'); // <-- Import updateCharts
        const { setupTabs, updateSessionsTable } = await import('./src/renderer/dashboard/ui.js');
        const eventSystem = await import('./src/renderer/dashboard/event-system.js').then(m => m.default);

        // --- Global Variables ---
        let allSessions = [];
        let allProjects = [];
        let currentChartFilter = '1y';
        let currentChartRangeTitle = 'This Year';
        const pageSize = 20;
        let currentPage = 1;
        let currentProjectFilter = 'All';

        // --- DOM Elements ---
        // Chart Filters
        const dateFilterButtons = document.querySelectorAll('.btn-filter'); // Use updated class
        const dateFromInput = document.getElementById('date-from');
        const dateToInput = document.getElementById('date-to');
        const applyCustomDateButton = document.getElementById('apply-custom-date');
        // Session Table Controls
        const projectFilterSelect = document.getElementById('project-filter-select');
        const prevPageBtn = document.getElementById('prev-page-btn');
        const nextPageBtn = document.getElementById('next-page-btn');
        const pageInfoSpan = document.getElementById('page-info');

        // --- WKWebView Data Bridge Receivers ---
        window.onSessionsLoaded = function(sessions) {
            console.log('[Dashboard] onSessionsLoaded called', sessions);
            if (typeof sessions === 'string') {
                try { sessions = JSON.parse(sessions); } catch (e) { console.error('Failed to parse sessions JSON', e); sessions = []; }
            }
            window.allSessions = sessions;
            allSessions = sessions;
            refreshDashboardData();
        };
        window.onProjectsLoaded = function(projects) {
            if (typeof projects === 'string') {
                try { projects = JSON.parse(projects); } catch (e) { console.error('Failed to parse projects JSON', e); projects = []; }
            }
            allProjects = projects;
            if (typeof refreshProjectsList === 'function') {
                refreshProjectsList();
            }
        };

        // --- Chart Date Filtering Logic ---

        /**
         * Calculates the start and end dates for a given range identifier.
         * @param {string} range - '7d', '1m', '3m', '1y', 'all', 'custom'
         * @param {string} [customStart] - YYYY-MM-DD format for custom range
         * @param {string} [customEnd] - YYYY-MM-DD format for custom range
         * @returns {{startDate: Date | null, endDate: Date | null, rangeTitle: string}}
         */
        function getDatesForRange(range, customStart = null, customEnd = null) {
            const today = new Date();
            today.setHours(0, 0, 0, 0); // Normalize to start of day
            let startDate = new Date(today);
            let endDate = new Date(today);
            endDate.setHours(23, 59, 59, 999); // Normalize to end of day
            let rangeTitle = '';

            switch (range) {
                case '7d':
                    startDate.setDate(today.getDate() - 6); // Today + 6 previous days
                    rangeTitle = 'Last 7 Days';
                    break;
                case '1m':
                    startDate = new Date(today.getFullYear(), today.getMonth() - 1, today.getDate());
                    rangeTitle = 'Last Month';
                    break;
                case '3m':
                    startDate = new Date(today.getFullYear(), today.getMonth() - 3, today.getDate());
                    rangeTitle = 'Last Quarter';
                    break;
                case '1y':
                    startDate = new Date(today.getFullYear(), 0, 1); // Start of current year
                    rangeTitle = 'This Year';
                    break;
                case 'all':
                    startDate = null; // Indicate no start date limit
                    endDate = null;   // Indicate no end date limit
                    rangeTitle = 'All Time';
                    break;
                case 'custom':
                    try {
                        startDate = customStart ? new Date(customStart + 'T00:00:00') : null;
                        endDate = customEnd ? new Date(customEnd + 'T23:59:59.999') : null;
                        if (startDate && endDate && startDate > endDate) {
                             alert("Start date cannot be after end date.");
                             return { startDate: null, endDate: null, rangeTitle: 'Invalid Range' }; // Indicate error
                        }
                        rangeTitle = `Custom (${customStart || '...'} - ${customEnd || '...'})`;
                    } catch (e) {
                        console.error("Error parsing custom dates:", e);
                        alert("Invalid custom date format.");
                        return { startDate: null, endDate: null, rangeTitle: 'Invalid Range' }; // Indicate error
                    }
                    break;
                default: // Default to 'This Year' if range is unknown
                    startDate = new Date(today.getFullYear(), 0, 1);
                    rangeTitle = 'This Year';
            }
             // Ensure startDate is Date object or null
             if (startDate && !(startDate instanceof Date && !isNaN(startDate))) startDate = null;
             // Ensure endDate is Date object or null
             if (endDate && !(endDate instanceof Date && !isNaN(endDate))) endDate = null;

            return { startDate, endDate, rangeTitle };
        }

        /**
         * Filters the global allSessions array based on start and end dates.
         * @param {Date | null} startDate - Start date (inclusive), null for no limit.
         * @param {Date | null} endDate - End date (inclusive), null for no limit.
         * @returns {Array<Object>} Filtered sessions.
         */
        function filterSessionsByDate(startDate, endDate) {
            if (!allSessions) return [];
            if (startDate === null && endDate === null) {
                return [...allSessions]; // Return all if range is 'all'
            }

            return allSessions.filter(session => {
                try {
                    const sessionDate = new Date(session.date + 'T00:00:00'); // Use session date only
                    if (isNaN(sessionDate.getTime())) return false; // Skip invalid session dates

                    const afterStart = startDate === null || sessionDate >= startDate;
                    const beforeEnd = endDate === null || sessionDate <= endDate;
                    return afterStart && beforeEnd;
                } catch (e) {
                    console.warn("Error parsing session date during filter:", session.date, e);
                    return false;
                }
            });
        }

        /**
         * Handles clicks on date filter buttons or custom apply.
         * Updates charts based on the selected range.
         * @param {string} range - '7d', '1m', '3m', '1y', 'all', 'custom'
         */
        async function handleDateFilterChange(range) {
            console.log(`[Dashboard] Date filter changed to: ${range}`);
            let customStart = null;
            let customEnd = null;

            if (range === 'custom') {
                customStart = dateFromInput.value;
                customEnd = dateToInput.value;
                if (!customStart || !customEnd) {
                    eventSystem.showNotification('warning', 'Invalid Range', 'Please select both "From" and "To" dates for custom range.');
                    return; // Don't proceed if custom dates are missing
                }
            }

            const { startDate, endDate, rangeTitle } = getDatesForRange(range, customStart, customEnd);

            if (rangeTitle === 'Invalid Range') return; // Stop if date calculation failed

            const filteredSessionsForChart = filterSessionsByDate(startDate, endDate);
            console.log(`[Dashboard] Filtered sessions count for chart "${rangeTitle}": ${filteredSessionsForChart.length}`);

            currentChartFilter = range; // Store the current CHART filter type
            currentChartRangeTitle = rangeTitle; // Store the CHART title

            // Update CHART filter button active states
            dateFilterButtons.forEach(btn => {
                if (btn.dataset.range === range) {
                    btn.classList.add('active');
                } else {
                    btn.classList.remove('active');
                }
            });
            // If custom CHART range applied, remove active state from predefined buttons
            if (range === 'custom') {
                 dateFilterButtons.forEach(btn => {
                     // Only remove active if it's not a session control button
                     if (btn.closest('.date-filter-buttons')) {
                         btn.classList.remove('active');
                     }
                 });
            }

            // Update charts with the filtered data
            try {
                await updateCharts(filteredSessionsForChart, allSessions, rangeTitle); // Pass filtered and all sessions
            } catch (error) {
                console.error(`[Dashboard] Error updating charts for range ${range}:`, error);
                eventSystem.showNotification('error', 'Chart Error', 'Failed to update charts');
            }
        }

        // --- Data Refresh ---
        async function refreshDashboardData() {
            // Use allSessions, which is set by the bridge.
            if (!allSessions) {
                console.log('[Dashboard] No sessions data available, skipping refresh');
                return;
            }

            const { startDate, endDate } = getDatesForRange(currentChartFilter);
            const filteredSessionsForChart = filterSessionsByDate(startDate, endDate);

            try {
                await updateCharts(filteredSessionsForChart, allSessions, currentChartRangeTitle);
            } catch (error) {
                console.error('[Dashboard] Error updating charts:', error);
                eventSystem.showNotification('error', 'Chart Error', 'Failed to update charts');
            }

            refreshSessionDisplay();
        }

        // --- Session Table Management ---
        function populateProjectFilter() {
            if (!projectFilterSelect) return;
            
            const currentValue = projectFilterSelect.value;
            projectFilterSelect.innerHTML = '<option value="All">All Projects</option>';
            
            if (allProjects && allProjects.length > 0) {
                allProjects.forEach(project => {
                    const option = document.createElement('option');
                    option.value = project.name;
                    option.textContent = project.name;
                    if (project.name === currentValue) {
                        option.selected = true;
                    }
                    projectFilterSelect.appendChild(option);
                });
            }
        }

        function calculateVisibleSessions() {
            if (!allSessions) return { visibleSessions: [], totalPages: 1 };

            let filteredSessions = [...allSessions];

            // Apply project filter
            if (currentProjectFilter && currentProjectFilter !== 'All') {
                filteredSessions = filteredSessions.filter(session => 
                    session.project === currentProjectFilter
                );
            }

            // Sort by date (newest first)
            filteredSessions.sort((a, b) => {
                const dateA = new Date(a.date + 'T00:00:00');
                const dateB = new Date(b.date + 'T00:00:00');
                return dateB - dateA;
            });

            const totalPages = Math.ceil(filteredSessions.length / pageSize);
            const startIndex = (currentPage - 1) * pageSize;
            const endIndex = startIndex + pageSize;
            const visibleSessions = filteredSessions.slice(startIndex, endIndex);

            return { visibleSessions, totalPages };
        }

        function refreshSessionDisplay() {
            const { visibleSessions, totalPages } = calculateVisibleSessions();
            updateSessionsTable(visibleSessions, refreshDashboardData); // Pass only the visible sessions

            // Update pagination controls
            if (pageInfoSpan) {
                pageInfoSpan.textContent = `Page ${currentPage} of ${totalPages}`;
            }
            if (prevPageBtn) {
                prevPageBtn.disabled = currentPage <= 1;
            }
            if (nextPageBtn) {
                nextPageBtn.disabled = currentPage >= totalPages;
            }
            console.log(`[Dashboard] Session display refreshed. Page: ${currentPage}/${totalPages}, Filter: ${currentProjectFilter}`);
        }

        // --- Project Management ---
        async function initProjectManagement() {
            console.log('[DEBUG] initProjectManagement called');
            const projectsList = document.getElementById('projects-list');
            const addProjectForm = document.getElementById('add-project-form');

            if (!projectsList || !addProjectForm) {
                console.error('Project management elements not found');
                return;
            }

            // Load and display projects
            await refreshProjectsList();

            // Add project form handler
            addProjectForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                const nameInput = document.getElementById('new-project-name');
                const colorInput = document.getElementById('new-project-color');
                
                if (!nameInput || !colorInput) return;
                
                try {
                    const result = await window.jujuApi.addProject({
                        name: nameInput.value.trim(),
                        color: colorInput.value
                    });

                    if (result && result.success) {
                        nameInput.value = '';
                        colorInput.value = '#4E79A7';
                        await refreshProjectsList();
                        await refreshDashboardData();
                        eventSystem.showNotification('success', 'Project Added', `Project "${nameInput.value.trim()}" created successfully`);
                    }
                } catch (error) {
                    console.error('Error adding project:', error);
                    eventSystem.showNotification('error', 'Add Failed', `Failed to add project: ${error.message}`);
                }
            });
        }

        async function refreshProjectsList() {
            const projectsList = document.getElementById('projects-list');
            if (!projectsList) {
                console.error('Projects list element not found');
                return;
            }
            try {
                projectsList.innerHTML = '';
                allProjects.forEach(project => {
                    const projectElement = document.createElement('div');
                    projectElement.className = 'project-item';
                    projectElement.innerHTML = `
                        <div class="project-info">
                            <span class="project-name">${project.name}</span>
                            <div class="project-color">
                                <input type="color" value="${project.color || '#4E79A7'}" 
                                       data-project-id="${project.id}">
                            </div>
                        </div>
                        <div class="project-actions">
                            <button class="btn btn-delete" data-id="${project.id}" data-name="${project.name}" title="Delete Project" aria-label="Delete Project">&times;</button>
                        </div>
                    `;
                    // Add color change handler
                    const colorInput = projectElement.querySelector('input[type="color"]');
                    if (colorInput) {
                        colorInput.addEventListener('change', async (e) => {
                            try {
                                await window.jujuApi.updateProjectColor(project.id, e.target.value);
                                window.jujuApi.loadProjects(); // Reload projects after color change
                                window.jujuApi.loadSessions(); // Reload sessions in case color affects charts
                                eventSystem.showNotification('success', 'Color Updated', `Project "${project.name}" color updated`);
                            } catch (error) {
                                console.error('Error updating project color:', error);
                                eventSystem.showNotification('error', 'Update Failed', `Failed to update color: ${error.message}`);
                            }
                        });
                    }
                    projectsList.appendChild(projectElement);
                });
            } catch (error) {
                console.error('Error loading projects:', error);
                projectsList.innerHTML = '<div class="error">Failed to load projects</div>';
                eventSystem.showNotification('error', 'Load Failed', 'Failed to load projects');
            }
        }

        // --- Event Listeners ---
        // Chart Date Filters
        dateFilterButtons.forEach(button => {
             // Only add listener if it's part of the date filter group
             if (button.closest('.date-filter-buttons')) {
                button.addEventListener('click', () => handleDateFilterChange(button.dataset.range));
             }
        });
        applyCustomDateButton.addEventListener('click', () => handleDateFilterChange('custom'));

        // Session Table Filters & Pagination
        projectFilterSelect?.addEventListener('change', (e) => {
            currentProjectFilter = e.target.value;
            currentPage = 1; // Reset to page 1 (most recent) when filter changes
            refreshSessionDisplay();
        });

        prevPageBtn?.addEventListener('click', () => {
            if (currentPage > 1) {
                currentPage--;
                refreshSessionDisplay();
            }
        });

        nextPageBtn?.addEventListener('click', () => {
            // Calculate total pages dynamically in case it changed
            const { totalPages } = calculateVisibleSessions();
            if (currentPage < totalPages) {
                currentPage++;
                refreshSessionDisplay();
            }
        });

        // Enhanced project deletion using event system
        document.getElementById('projects-list').addEventListener('click', async function(e) {
            if (e.target.classList.contains('btn-delete')) {
                e.preventDefault();
                e.stopPropagation();
                
                const btn = e.target;
                const projectId = btn.dataset.id;
                const projectName = btn.dataset.name || `Project ${projectId}`;
                
                if (!projectId) {
                    eventSystem.showNotification('error', 'Error', 'Project ID not found');
                    return;
                }
                
                console.log('[Dashboard] Project delete button clicked', projectId, projectName);
                
                try {
                    // Use the event system's enhanced deletion with fallback
                    const result = await eventSystem.deleteProjectWithFallback(projectId, projectName);
                    
                    if (result.success) {
                        // Refresh the projects list and dashboard data
                        await refreshProjectsList();
                        await refreshDashboardData();
                    } else if (!result.cancelled) {
                        // Error was already handled by the event system
                        console.error('[Dashboard] Project deletion failed:', result.error);
                    }
                } catch (error) {
                    console.error('[Dashboard] Unexpected error during project deletion:', error);
                    eventSystem.showNotification('error', 'Delete Failed', 'An unexpected error occurred while deleting the project');
                }
            }
        });

        // --- Initialization ---
        setupTabs();
        console.log('Calling window.jujuApi.loadProjects and loadSessions');
        window.jujuApi.loadProjects();
        window.jujuApi.loadSessions();
        await initProjectManagement();
        await refreshDashboardData();

        // Initial display is handled by refreshDashboardData calling refreshSessionDisplay,
        // which uses the default currentPage = 1. No extra setting needed here.

        // Set up event listeners for dashboard updates
        eventSystem.on('sessionDeleted', () => {
            console.log('[Dashboard] Session deleted event received, refreshing data');
            refreshDashboardData();
        });

        eventSystem.on('projectDeleted', () => {
            console.log('[Dashboard] Project deleted event received, refreshing data');
            refreshProjectsList();
            refreshDashboardData();
        });

    } catch (error) {
        console.error('[Dashboard] Error initializing dashboard:', error);
        // Display a user-friendly error message using the event system
        if (eventSystem) {
            eventSystem.showNotification('error', 'Initialization Failed', 'Failed to initialize dashboard. Please check console for details.');
        }
        // Fallback error display
        const chartsDiv = document.getElementById('charts');
        if (chartsDiv) {
            chartsDiv.innerHTML = `<div class="error-message">Failed to initialize dashboard. Please check console for details. Error: ${error.message}</div>`;
        }
    }
});
