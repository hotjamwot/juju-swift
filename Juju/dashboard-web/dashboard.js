// Replace the top-level async IIFE with DOMContentLoaded event listener

document.addEventListener('DOMContentLoaded', async () => {
    try {
        // Import modules
        const { updateCharts, destroyCharts } = await import('./src/renderer/dashboard/charts.js'); // <-- Import updateCharts
        const { setupTabs, updateSessionsTable } = await import('./src/renderer/dashboard/ui.js');

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
                    alert("Please select both 'From' and 'To' dates for custom range.");
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
            }
        }

        // --- Data Refresh ---
        async function refreshDashboardData() {
            console.log('[Dashboard] Refreshing dashboard data...');
            try {
                // Use allSessions, which is set by the bridge.
                if (projectFilterSelect.options.length <= 1) {
                    populateProjectFilter();
                }
                refreshSessionDisplay();
                let initialStartDate, initialEndDate;
                if (currentChartFilter === 'custom') {
                    ({ startDate: initialStartDate, endDate: initialEndDate } = getDatesForRange(currentChartFilter, dateFromInput.value, dateToInput.value));
                } else {
                    ({ startDate: initialStartDate, endDate: initialEndDate } = getDatesForRange(currentChartFilter));
                }
                const initialFilteredSessionsForChart = filterSessionsByDate(initialStartDate, initialEndDate);
                await updateCharts(initialFilteredSessionsForChart, allSessions, currentChartRangeTitle);
            } catch (error) {
                console.error('[Dashboard] Error refreshing dashboard data:', error);
            }
        }


        // --- Session Table Filtering & Pagination Logic ---

        /**
         * Populates the project filter dropdown with unique project names from allSessions.
         */
        function populateProjectFilter() {
            if (!projectFilterSelect) return;

            const projects = [...new Set(allSessions.map(s => s.project || 'N/A'))].sort();
            // Clear existing options except the "All" default
            projectFilterSelect.innerHTML = '<option value="All">All Projects</option>';

            projects.forEach(project => {
                if (project) { // Ensure project name is not empty/null
                    const option = document.createElement('option');
                    option.value = project;
                    option.textContent = project;
                    projectFilterSelect.appendChild(option);
                }
            });
            projectFilterSelect.value = currentProjectFilter; // Set dropdown to current filter
            console.log('[Dashboard] Project filter populated.');
        }

        /**
         * Calculates the sessions to display based on current filters and pagination.
         * @returns {{ visibleSessions: Array<Object>, currentPage: number, totalPages: number }}
         */
        function calculateVisibleSessions() {
            // 1. Filter by Project
            let filtered = allSessions;
            if (currentProjectFilter !== 'All') {
                filtered = allSessions.filter(session => (session.project || 'N/A') === currentProjectFilter);
            }

            // 2. Sort by Date (most recent first - already done in ui.js, but good to ensure here too)
            // Let's keep the sorting logic primarily in ui.js for consistency when editing,
            // but we need the *full* sorted list here for pagination.
             filtered.sort((a, b) => {
                 const dateA = new Date(`${a.date || ''}T${a.start_time || ''}`).getTime();
                 const dateB = new Date(`${b.date || ''}T${b.start_time || ''}`).getTime();
                 // Handle potential NaN values robustly
                 const valA = isNaN(dateA) ? -Infinity : dateA;
                 const valB = isNaN(dateB) ? -Infinity : dateB;
                 return valB - valA; // Descending order
             });


            // 3. Paginate
            const totalItems = filtered.length;
            const totalPages = Math.max(1, Math.ceil(totalItems / pageSize)); // Ensure at least 1 page

            // Adjust currentPage if it's out of bounds (e.g., after filtering)
            // Default to last page if current page is invalid
            if (currentPage > totalPages) {
                currentPage = totalPages;
            }
            if (currentPage < 1) {
                currentPage = 1;
            }

            const startIndex = (currentPage - 1) * pageSize;
            const endIndex = startIndex + pageSize;
            const visibleSessions = filtered.slice(startIndex, endIndex);

            return { visibleSessions, currentPage, totalPages };
        }

        /**
         * Updates the session table display, pagination controls, and info text.
         */
        function refreshSessionDisplay() {
            const { visibleSessions, currentPage: adjustedCurrentPage, totalPages } = calculateVisibleSessions();

            // Update state (currentPage might have been adjusted)
            currentPage = adjustedCurrentPage;

            // Update the table in the UI
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
                    }
                } catch (error) {
                    console.error('Error adding project:', error);
                    alert('Failed to add project: ' + error.message);
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
                            <button class="btn btn-delete" data-id="${project.id}" title="Delete Project" aria-label="Delete Project">&times;</button>
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
                            } catch (error) {
                                console.error('Error updating project color:', error);
                                alert('Failed to update color: ' + error.message);
                            }
                        });
                    }
                    projectsList.appendChild(projectElement);
                });
            } catch (error) {
                console.error('Error loading projects:', error);
                projectsList.innerHTML = '<div class="error">Failed to load projects</div>';
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

        // Attach event delegation for project delete buttons (must be after DOM is ready)
        document.getElementById('projects-list').addEventListener('click', function(e) {
            if (e.target.classList.contains('btn-delete')) {
                console.log('[Dashboard] Project delete button clicked', e.target.dataset.id);
                const btn = e.target;
                const projectId = btn.dataset.id;
                const project = allProjects.find(p => String(p.id) === String(projectId));
                if (!project) return;
                if (!confirm(`Are you sure you want to delete ${project.name}?`)) return;
                // Visual feedback: disable button and show spinner
                btn.disabled = true;
                const oldHtml = btn.innerHTML;
                btn.innerHTML = '<span class="spinner"></span>';
                console.log('[Dashboard] Entering deleteProject .then() block');
                if (typeof window.jujuApi.deleteProject !== 'function') {
                    alert('window.jujuApi.deleteProject is not a function!');
                    btn.disabled = false;
                    btn.innerHTML = oldHtml;
                    return;
                }
                window['jujuApi']['deleteProject'](projectId)
                    .then(result => {
                        console.log('[Dashboard] window.jujuApi.deleteProject returned', result);
                        if (result && result.success) {
                            refreshProjectsList();
                            refreshDashboardData();
                        } else {
                            const errorMsg = result && result.error ? result.error : 'Unknown error';
                            alert('Failed to delete project: ' + errorMsg);
                            console.error('Error deleting project:', errorMsg);
                            btn.disabled = false;
                            btn.innerHTML = oldHtml;
                        }
                    })
                    .catch(error => {
                        alert('Error calling window.jujuApi.deleteProject: ' + (error && error.message ? error.message : error));
                        console.error('[Dashboard] Error in deleteProject handler:', error);
                        btn.disabled = false;
                        btn.innerHTML = oldHtml;
                    });
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


    } catch (error) {
        console.error('[Dashboard] Error initializing dashboard:', error);
        // Display a user-friendly error message?
        const chartsDiv = document.getElementById('charts');
        if (chartsDiv) {
            chartsDiv.innerHTML = `<div class="error-message">Failed to initialize dashboard. Please check console for details. Error: ${error.message}</div>`;
        }
    }
});
