import {
    createStackedBarChart,
    createMultiBarComparisonChart, // Updated import
    createPieChart,
    createWeeklyStreamChart,
    createProjectBarChart
} from './chart-creators.js';
import {
    prepareYearlyDailyProjectData,
    prepareWeeklyProjectData,
    preparePieData
} from './chart-data-preparers.js';

// Chart instances
let yearlyChartInstance = null;
let weeklyChartInstance = null;
let pieChartInstance = null;
let dayComparisonBarChartInstance = null;
let weekComparisonBarChartInstance = null;
let monthComparisonBarChartInstance = null;
let projectBarChartInstance = null;

// --- Removed formatComparisonText helper function ---

// Chart management functions
function checkChartJs() {
    if (typeof Chart === 'undefined') {
        throw new Error('Chart.js is not loaded. Cannot create charts.');
    }
}

export function destroyCharts() {
    if (yearlyChartInstance) yearlyChartInstance.destroy();
    if (weeklyChartInstance) weeklyChartInstance.destroy();
    if (pieChartInstance) pieChartInstance.destroy();
    if (dayComparisonBarChartInstance) dayComparisonBarChartInstance.destroy();
    if (weekComparisonBarChartInstance) weekComparisonBarChartInstance.destroy();
    if (monthComparisonBarChartInstance) monthComparisonBarChartInstance.destroy();
    if (projectBarChartInstance) projectBarChartInstance.destroy();

    yearlyChartInstance = weeklyChartInstance = pieChartInstance = null;
    dayComparisonBarChartInstance = weekComparisonBarChartInstance = monthComparisonBarChartInstance = null;
    projectBarChartInstance = null;
    console.log('[Charts] Destroyed existing chart instances.');
}

export async function updateCharts(filteredSessions, allSessions, rangeTitle) {
    try {
        checkChartJs();
        // Update the title display
        const titleElement = document.getElementById('chart-range-title');
        if (titleElement) {
            titleElement.textContent = `Showing data for: ${rangeTitle}`;
        }
        // Always destroy existing charts before creating new ones
        destroyCharts();
        console.log('[Charts] Called destroyCharts before creating new charts.');

        // Only proceed with main charts if we have session data
        if (!filteredSessions || filteredSessions.length === 0) {
            console.log('[Charts] No filtered session data for main charts.');
            return { yearlyChart: null, weeklyChart: null, pieChart: null };
        }

        // Create main charts
        console.log(`[Charts] Updating main charts for "${rangeTitle}" with ${filteredSessions.length} sessions.`);

        try {
            // Yearly/Daily Chart
            const dailyProjectData = prepareYearlyDailyProjectData(filteredSessions);
            yearlyChartInstance = await createStackedBarChart(
                'yearly-chart',
                dailyProjectData.labels,
                dailyProjectData.datasets,
                'Hours',
                dailyProjectData.monthLabels
            );

            // Weekly Chart
            const weeklyProjectData = prepareWeeklyProjectData(filteredSessions);
            weeklyChartInstance = await createWeeklyStreamChart('weekly-chart', weeklyProjectData, 'Weekly Hours by Project');

            // Pie Chart
            const pieData = preparePieData(filteredSessions);
            pieChartInstance = await createPieChart('pie-chart', pieData.labels, pieData.data);
            // Project Bar Chart (below pie chart)
            projectBarChartInstance = await createProjectBarChart('project-bar-chart', pieData.labels, pieData.data);

            return {
                yearlyChart: yearlyChartInstance,
                weeklyChart: weeklyChartInstance,
                pieChart: pieChartInstance
            };
        } catch (chartError) {
            console.error("[Charts] Error creating charts:", chartError);
            return { yearlyChart: null, weeklyChart: null, pieChart: null };
        }
    } catch (error) {
        console.error("[Charts] Error updating charts:", error);
        return { yearlyChart: null, weeklyChart: null, pieChart: null };
    }
}
