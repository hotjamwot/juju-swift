// Replace the top-level async IIFE with DOMContentLoaded event listener

document.addEventListener('DOMContentLoaded', async () => {
    try {
        // Import modules
        const { updateCharts, destroyCharts } = await import('./src/renderer/dashboard/charts.js');
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
        const dateFilterButtons = document.querySelectorAll('.btn-filter');
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
            if (typeof sessions === 'string') {
                try { sessions = JSON.parse(sessions); } catch (e) { sessions = []; }
            }
            window.allSessions = sessions;
            allSessions = sessions;
            refreshDashboardData();
        };
        window.onProjectsLoaded = function(projects) {
            if (typeof projects === 'string') {
                try { projects = JSON.parse(projects); } catch (e) { projects = []; }
            }
            allProjects = projects;
            populateProjectFilter();
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
            today.setHours(0, 0, 0, 0);
            let startDate = new Date(today);
            let endDate = new Date(today);
            endDate.setHours(23, 59, 59, 999);
            let rangeTitle = '';

            switch (range) {
                case '7d':
                    startDate.setDate(today.getDate() - 6);
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
                    startDate = new Date(today.getFullYear(), 0, 1);
                    rangeTitle = 'This Year';
                    break;
                case 'all':
                    startDate = null;
                    endDate = null;
                    rangeTitle = 'All Time';
                    break;
                case 'custom':
                    try {
                        startDate = customStart ? new Date(customStart + 'T00:00:00') : null;
                        endDate = customEnd ? new Date(customEnd + 'T23:59:59.999') : null;
                        if (startDate && endDate && startDate > endDate) {
                             eventSystem.showNotification('warning', 'Invalid Range', 'Start date cannot be after end date.');
                             return { startDate: null, endDate: null, rangeTitle: 'Invalid Range' };
                        }
                        rangeTitle = `Custom (${customStart || '...'} - ${customEnd || '...'})`;
                    } catch (e) {
                        eventSystem.showNotification('error', 'Invalid Date', 'Invalid custom date format.');
                        return { startDate: null, endDate: null, rangeTitle: 'Invalid Range' };
                    }
                    break;
                default:
                    startDate = new Date(today.getFullYear(), 0, 1);
                    rangeTitle = 'This Year';
            }
             if (startDate && !(startDate instanceof Date && !isNaN(startDate))) startDate = null;
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
                return [...allSessions];
            }

            return allSessions.filter(session => {
                try {
                    const sessionDate = new Date(session.date + 'T00:00:00');
                    if (isNaN(sessionDate.getTime())) return false;

                    const afterStart = startDate === null || sessionDate >= startDate;
                    const beforeEnd = endDate === null || sessionDate <= endDate;
                    return afterStart && beforeEnd;
                } catch (e) {
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
            let customStart = null;
            let customEnd = null;

            if (range === 'custom') {
                customStart = dateFromInput.value;
                customEnd = dateToInput.value;
                if (!customStart || !customEnd) {
                    eventSystem.showNotification('warning', 'Invalid Range', 'Please select both "From" and "To" dates for custom range.');
                    return;
                }
            }

            const { startDate, endDate, rangeTitle } = getDatesForRange(range, customStart, customEnd);

            if (rangeTitle === 'Invalid Range') return;

            const filteredSessionsForChart = filterSessionsByDate(startDate, endDate);

            currentChartFilter = range;
            currentChartRangeTitle = rangeTitle;

            dateFilterButtons.forEach(btn => {
                if (btn.dataset.range === range) {
                    btn.classList.add('active');
                } else {
                    btn.classList.remove('active');
                }
            });

            if (range === 'custom') {
                 dateFilterButtons.forEach(btn => {
                     if (btn.closest('.date-filter-buttons')) {
                         btn.classList.remove('active');
                     }
                 });
            }

            try {
                await updateCharts(filteredSessionsForChart, allSessions, rangeTitle);
            } catch (error) {
                eventSystem.showNotification('error', 'Chart Error', 'Failed to update charts');
            }
        }

        // --- Data Refresh ---
        async function refreshDashboardData() {
            if (!allSessions) {
                return;
            }

            const { startDate, endDate } = getDatesForRange(currentChartFilter);
            const filteredSessionsForChart = filterSessionsByDate(startDate, endDate);

            try {
                await updateCharts(filteredSessionsForChart, allSessions, currentChartRangeTitle);
            } catch (error) {
                eventSystem.showNotification('error', 'Chart Error', 'Failed to update charts');
            }

            populateProjectFilter();
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

            if (currentProjectFilter && currentProjectFilter !== 'All') {
                filteredSessions = filteredSessions.filter(session => 
                    session.project === currentProjectFilter
                );
            }

            filteredSessions.sort((a, b) => {
                try {
                    // Try to sort by full datetime (date + time)
                    const timeA = a.start_time || '00:00';
                    const timeB = b.start_time || '00:00';
                    
                    const dateTimeA = new Date(`${a.date}T${timeA}`);
                    const dateTimeB = new Date(`${b.date}T${timeB}`);
                    
                    // Check if the dates are valid
                    if (isNaN(dateTimeA.getTime()) || isNaN(dateTimeB.getTime())) {
                        // Fallback to date-only sorting
                        const dateA = new Date(a.date + 'T00:00:00');
                        const dateB = new Date(b.date + 'T00:00:00');
                        return dateB - dateA;
                    }
                    
                    // Sort by most recent first (descending order)
                    return dateTimeB.getTime() - dateTimeA.getTime();
                } catch (error) {
                    // If anything goes wrong, fallback to date-only sorting
                    const dateA = new Date(a.date + 'T00:00:00');
                    const dateB = new Date(b.date + 'T00:00:00');
                    return dateB - dateA;
                }
            });

            const totalPages = Math.ceil(filteredSessions.length / pageSize);
            const startIndex = (currentPage - 1) * pageSize;
            const endIndex = startIndex + pageSize;
            const visibleSessions = filteredSessions.slice(startIndex, endIndex);

            return { visibleSessions, totalPages };
        }

        function refreshSessionDisplay() {
            const { visibleSessions, totalPages } = calculateVisibleSessions();
            updateSessionsTable(visibleSessions, refreshDashboardData);

            if (pageInfoSpan) {
                pageInfoSpan.textContent = `Page ${currentPage} of ${totalPages}`;
            }
            if (prevPageBtn) {
                prevPageBtn.disabled = currentPage <= 1;
            }
            if (nextPageBtn) {
                nextPageBtn.disabled = currentPage >= totalPages;
            }
        }

        // --- Project Management ---
        async function initProjectManagement() {
            const projectsList = document.getElementById('projects-list');
            const addProjectForm = document.getElementById('add-project-form');

            if (!projectsList || !addProjectForm) {
                return;
            }

            await refreshProjectsList();

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
                    eventSystem.showNotification('error', 'Add Failed', `Failed to add project: ${error.message}`);
                }
            });
        }

        async function refreshProjectsList() {
            const projectsList = document.getElementById('projects-list');
            if (!projectsList) {
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
                    
                    const colorInput = projectElement.querySelector('input[type="color"]');
                    if (colorInput) {
                        colorInput.addEventListener('change', async (e) => {
                            try {
                                await window.jujuApi.updateProjectColor(project.id, e.target.value);
                                window.jujuApi.loadProjects();
                                window.jujuApi.loadSessions();
                                eventSystem.showNotification('success', 'Color Updated', `Project "${project.name}" color updated`);
                            } catch (error) {
                                eventSystem.showNotification('error', 'Update Failed', `Failed to update color: ${error.message}`);
                            }
                        });
                    }
                    projectsList.appendChild(projectElement);
                });
                populateProjectFilter();
            } catch (error) {
                projectsList.innerHTML = '<div class="error">Failed to load projects</div>';
                eventSystem.showNotification('error', 'Load Failed', 'Failed to load projects');
            }
        }

        // --- Event Listeners ---
        dateFilterButtons.forEach(button => {
             if (button.closest('.date-filter-buttons')) {
                button.addEventListener('click', () => handleDateFilterChange(button.dataset.range));
             }
        });
        applyCustomDateButton.addEventListener('click', () => handleDateFilterChange('custom'));

        projectFilterSelect?.addEventListener('change', (e) => {
            currentProjectFilter = e.target.value;
            currentPage = 1;
            refreshSessionDisplay();
        });

        prevPageBtn?.addEventListener('click', () => {
            if (currentPage > 1) {
                currentPage--;
                refreshSessionDisplay();
            }
        });

        nextPageBtn?.addEventListener('click', () => {
            const { totalPages } = calculateVisibleSessions();
            if (currentPage < totalPages) {
                currentPage++;
                refreshSessionDisplay();
            }
        });

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
                
                try {
                    const result = await eventSystem.deleteProjectWithFallback(projectId, projectName);
                    
                    if (result.success) {
                        await refreshProjectsList();
                        await refreshDashboardData();
                        if (window.jujuApi && typeof window.jujuApi.refreshMenu === 'function') {
                            window.jujuApi.refreshMenu();
                        }
                    } else if (!result.cancelled) {
                        console.error('Project deletion failed:', result.error);
                    }
                } catch (error) {
                    eventSystem.showNotification('error', 'Delete Failed', 'An unexpected error occurred while deleting the project');
                }
            }
        });

        // --- Initialization ---
        setupTabs();
        window.jujuApi.loadProjects();
        window.jujuApi.loadSessions();
        await initProjectManagement();
        await refreshDashboardData();

        eventSystem.on('sessionDeleted', () => {
            refreshDashboardData();
        });

        eventSystem.on('projectDeleted', () => {
            refreshProjectsList();
            refreshDashboardData();
        });

    } catch (error) {
        if (eventSystem) {
            eventSystem.showNotification('error', 'Initialization Failed', 'Failed to initialize dashboard. Please check console for details.');
        }
        const chartsDiv = document.getElementById('charts');
        if (chartsDiv) {
            chartsDiv.innerHTML = `<div class="error-message">Failed to initialize dashboard. Please check console for details. Error: ${error.message}</div>`;
        }
    }
});
