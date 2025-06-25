import { defaultColors, sharedAxisConfig, sharedLegendConfig, sharedTooltipConfig } from './chart-config.js';

let cachedProjects = null;
let lastProjectLoad = 0;
const CACHE_TIMEOUT = 5000; // 5 seconds

async function loadProjects() {
    const now = Date.now();
    if (!cachedProjects || (now - lastProjectLoad) > CACHE_TIMEOUT) {
        try {
            cachedProjects = await window.jujuApi.loadProjects();
            lastProjectLoad = now;
        } catch (error) {
            console.warn('Error loading projects:', error);
            cachedProjects = [];
        }
    }
    return cachedProjects;
}

async function getProjectColor(projectName, index) {
    const projects = await loadProjects();
    const project = projects.find(p => p.name === projectName);
    if (project && project.color) {
        return project.color;
    }
    return defaultColors[index % defaultColors.length];
}

async function generateColors(projectNames) {
    const colors = [];
    for (let i = 0; i < projectNames.length; i++) {
        colors.push(await getProjectColor(projectNames[i], i));
    }
    return colors;
}

export async function createStackedBarChart(canvasId, labels, datasets, yAxisLabel, monthLabels = null) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.error(`Canvas element with ID ${canvasId} not found.`);
        return null;
    }
    if (typeof Chart === 'undefined') {
        console.error('Chart.js is not loaded. Cannot create chart.');
        return null;
    }

    if (!labels.length || !datasets.length || datasets.every(d => !d.data.length)) {
        const ctx = canvas.getContext('2d');
        ctx.save();
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = '#888888';
        ctx.font = '14px Poppins';
        ctx.fillText('No data available for this period', canvas.width / 2, canvas.height / 2);
        ctx.restore();
        return null;
    }

    const ctx = canvas.getContext('2d');
    const visibleDatasets = datasets.filter(ds => ds.data.some(val => val > 0));
    const projectNames = visibleDatasets.map(ds => ds.label);
    const colors = await generateColors(projectNames);
    
    visibleDatasets.forEach((dataset, index) => {
        dataset.backgroundColor = colors[index];
    });

    return new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: visibleDatasets
        },
        options: {
            indexAxis: 'x',
            responsive: true,
            maintainAspectRatio: false,
            layout: {
                padding: { top: 0, bottom: 0, left: 0, right: 0 }
            },
            scales: {
                x: {
                    stacked: true,
                    ...sharedAxisConfig,
                    ticks: {
                        ...sharedAxisConfig.ticks,
                        callback: function(value, index) {
                            if (!labels || index >= labels.length) return '';
                            const labelValue = labels[index];
                            if (monthLabels && monthLabels[labelValue]) {
                                return monthLabels[labelValue];
                            }
                            if (monthLabels && labelValue && labelValue.includes('-')) {
                                try {
                                    const date = new Date(labelValue + 'T00:00:00');
                                    if (!isNaN(date.getTime()) && date.getDate() !== 1) {
                                        return date.toLocaleDateString('en-US', { month: 'numeric', day: 'numeric' });
                                    }
                                    return '';
                                } catch (e) { return labelValue; }
                            }
                            return labelValue;
                        }
                    }
                },
                y: {
                    stacked: true,
                    ...sharedAxisConfig,
                    title: {
                        display: true,
                        text: yAxisLabel,
                        color: '#E0E0E0'
                    }
                }
            },
            plugins: {
                legend: sharedLegendConfig,
                tooltip: sharedTooltipConfig
            }
        }
    });
}

export async function createPieChart(canvasId, labels, data) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.error(`Canvas element with ID ${canvasId} not found.`);
        return null;
    }
    if (typeof Chart === 'undefined') {
        console.error('Chart.js is not loaded.');
        return null;
    }

    const ctx = canvas.getContext('2d');
    const threshold = 0.01;
    const filteredLabels = [];
    const filteredData = [];
    labels.forEach((label, index) => {
        if (data[index] >= threshold) {
            filteredLabels.push(label);
            filteredData.push(data[index]);
        }
    });

    if (filteredLabels.length === 0) {
        console.log(`[Charts] No significant data for pie chart ${canvasId}.`);
        return null;
    }

    const colors = await generateColors(filteredLabels);

    return new Chart(ctx, {
        type: 'pie',
        data: {
            labels: filteredLabels,
            datasets: [{
                data: filteredData,
                backgroundColor: colors,
                borderColor: '#1E1E1E',
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    ...sharedLegendConfig,
                    position: 'top'
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            const label = context.label || '';
                            const value = context.parsed || 0;
                            const total = context.chart.data.datasets[0].data.reduce((sum, val) => sum + val, 0);
                            const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                            return `${label}: ${value.toFixed(1)} hours (${percentage}%)`;
                        }
                    }
                }
            }
        }
    });
}

export async function createWeeklyStreamChart(canvasId, data, chartTitle = 'Weekly Hours by Project') {
    const ctx = document.getElementById(canvasId).getContext('2d');
    const colors = await generateColors(data.datasets.map(d => d.label));

    const datasets = data.datasets.map((dataset, index) => ({
        ...dataset,
        backgroundColor: colors[index],
        borderColor: colors[index],
        fill: true,
        tension: 0.4,
        borderWidth: 1,
        pointRadius: 0,
        pointHoverRadius: 0
    }));

    return new Chart(ctx, {
        type: 'line',
        data: { 
            labels: data.labels, 
            datasets 
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                intersect: false,
                mode: 'index'
            },
            scales: {
                y: {
                    stacked: true,
                    ...sharedAxisConfig,
                    title: {
                        display: true,
                        text: 'Hours',
                        color: '#E0E0E0'
                    }
                },
                x: sharedAxisConfig
            },
            plugins: {
                title: {
                    display: true,
                    text: chartTitle,
                    color: '#E0E0E0',
                    padding: {
                        bottom: 15
                    }
                },
                legend: {
                    ...sharedLegendConfig,
                    position: 'bottom'
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            let label = context.dataset.label || '';
                            if (label) label += ': ';
                            if (context.parsed.y !== null) {
                                label += context.parsed.y.toFixed(1) + ' hours';
                            }
                            return label;
                        }
                    }
                }
            }
        }
    });
}

export async function createProjectBarChart(canvasId, labels, data) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.error(`Canvas element with ID ${canvasId} not found.`);
        return null;
    }
    if (typeof Chart === 'undefined') {
        console.error('Chart.js is not loaded. Cannot create chart.');
        return null;
    }

    const ctx = canvas.getContext('2d');
    const colors = await generateColors(labels);

    return new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Total Hours',
                data: data,
                backgroundColor: colors,
                borderColor: '#1E1E1E',
                borderWidth: 1,
                borderRadius: 6,
                maxBarThickness: 48
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            layout: {
                padding: { top: 10, bottom: 10, left: 10, right: 10 }
            },
            scales: {
                x: {
                    grid: { display: false },
                    ticks: {
                        color: '#E0E0E0',
                        font: { size: 12 },
                        autoSkip: false
                    }
                },
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(224, 224, 224, 0.1)' },
                    title: {
                        display: true,
                        text: 'Total Hours',
                        color: '#E0E0E0'
                    },
                    ticks: {
                        color: '#E0E0E0',
                        font: { size: 12 }
                    }
                }
            },
            plugins: {
                legend: { display: false },
                title: {
                    display: true,
                    text: 'Total Hours by Project',
                    color: '#E0E0E0',
                    padding: { bottom: 10 }
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return `${context.label}: ${context.parsed.y.toFixed(1)} hours`;
                        }
                    }
                }
            }
        }
    });
}
