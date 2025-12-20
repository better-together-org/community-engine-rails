import { Controller } from "@hotwired/stimulus"
import "chart.js"

const sharedChartOptions = {
  scales: {
    x: {
      ticks: {
        font: {
          size: 12
        },
        maxRotation: 60,  // Maximum label rotation to avoid overlap
        minRotation: 0,   // Minimum rotation (horizontal)
        autoSkip: true    // Skip labels if they are too crowded
      }
    },
    y: {
      beginAtZero: true,
      ticks: {
        font: {
          size: 12
        }
      }
    }
  },
  plugins: {
    legend: {
      labels: {
        font: {
          size: 14
        }
      }
    },
    tooltip: {
      bodyFont: {
        size: 12
      }
    }
  },
  responsive: true
};

const platformColors = {
  facebook: 'rgba(59, 89, 152, 0.5)',  // Facebook Blue
  bluesky: 'rgba(17, 133, 254, 0.5)',  // Bluesky Blue
  linkedin: 'rgba(0, 123, 182, 0.5)',  // LinkedIn Teal
  pinterest: 'rgba(189, 8, 28, 0.5)',  // Pinterest Red
  reddit: 'rgba(255, 69, 0, 0.5)',     // Reddit Orange
  whatsapp: 'rgba(37, 211, 102, 0.5)', // WhatsApp Green
};

const platformBorderColors = {
  facebook: 'rgba(59, 89, 152, 1)',
  bluesky: 'rgba(17, 133, 254, 1)',
  linkedin: 'rgba(0, 123, 182, 1)',
  pinterest: 'rgba(189, 8, 28, 1)',
  reddit: 'rgba(255, 69, 0, 1)',
  whatsapp: 'rgba(37, 211, 102, 1)',
};

export default class extends Controller {
  static targets = ["pageViewsChart", "dailyPageViewsChart", "linkClicksChart", "dailyLinkClicksChart", "downloadsChart", "sharesChart", "sharesPerUrlPerPlatformChart", "linksByHostChart", "invalidByHostChart", "failuresDailyChart"]

  connect() {
    // Store chart instances for later updates
    this.charts = {}
    
    // Initialize charts with data from data attributes (only if targets exist)
    if (this.hasPageViewsChartTarget) this.renderPageViewsChart()
    if (this.hasDailyPageViewsChartTarget) this.renderDailyPageViewsChart()
    if (this.hasLinkClicksChartTarget) this.renderLinkClicksChart()
    if (this.hasDailyLinkClicksChartTarget) this.renderDailyLinkClicksChart()
    if (this.hasDownloadsChartTarget) this.renderDownloadsChart()
    if (this.hasSharesChartTarget) this.renderSharesChart()
    if (this.hasSharesPerUrlPerPlatformChartTarget) this.renderSharesPerUrlPerPlatformChart()
    if (this.hasLinksByHostChartTarget) this.renderLinksByHostChart()
    if (this.hasInvalidByHostChartTarget) this.renderInvalidByHostChart()
    if (this.hasFailuresDailyChartTarget) this.renderFailuresDailyChart()

    // Listen for filter updates on the element itself
    this.boundHandleDataUpdate = this.handleDataUpdate.bind(this)
    this.element.addEventListener('better-together--metrics-datetime-filter:dataLoaded', this.boundHandleDataUpdate)
    this.element.addEventListener('better-together--metrics-additional-filters:dataLoaded', this.boundHandleDataUpdate)
  }

  disconnect() {
    // Clean up event listeners
    if (this.boundHandleDataUpdate) {
      this.element.removeEventListener('better-together--metrics-datetime-filter:dataLoaded', this.boundHandleDataUpdate)
      this.element.removeEventListener('better-together--metrics-additional-filters:dataLoaded', this.boundHandleDataUpdate)
    }
    
    // Clean up chart instances
    Object.values(this.charts).forEach(chart => {
      if (chart) chart.destroy()
    })
    this.charts = {}
  }

  // Handle data updates from datetime filter
  handleDataUpdate(event) {
    const { chartType, data } = event.detail
    
    switch(chartType) {
      case 'pageViewsChart':
        this.updateStackedChart('pageViewsChart', data)
        break
      case 'dailyPageViewsChart':
        this.updateStackedChart('dailyPageViewsChart', data)
        break
      case 'linkClicksChart':
        this.updateChart('linkClicksChart', data)
        break
      case 'dailyLinkClicksChart':
        this.updateChart('dailyLinkClicksChart', data)
        break
      case 'downloadsChart':
        this.updateChart('downloadsChart', data)
        break
      case 'sharesChart':
        this.updateChart('sharesChart', data)
        break
      case 'sharesPerUrlPerPlatformChart':
        this.updateStackedChart('sharesPerUrlPerPlatformChart', data)
        break
      case 'linksByHostChart':
        this.updateChart('linksByHostChart', data)
        break
      case 'invalidByHostChart':
        this.updateChart('invalidByHostChart', data)
        break
      case 'failuresDailyChart':
        this.updateChart('failuresDailyChart', data)
        break
    }
  }

  // Update a simple chart with new data
  updateChart(chartName, data) {
    const chart = this.charts[chartName]
    if (chart) {
      chart.data.labels = data.labels
      chart.data.datasets[0].data = data.values
      chart.update()
    }
  }

  // Update a stacked chart with multiple datasets
  updateStackedChart(chartName, data) {
    const chart = this.charts[chartName]
    if (chart) {
      chart.data.labels = data.labels
      chart.data.datasets = data.datasets
      chart.update()
    }
  }

  renderPageViewsChart() {
    const data = JSON.parse(this.pageViewsChartTarget.dataset.chartData || '{"labels":[],"datasets":[]}')
    this.charts.pageViewsChart = new Chart(this.pageViewsChartTarget, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: data.datasets
      },
      options: Object.assign({}, sharedChartOptions, {
        scales: {
          x: {
            stacked: true
          },
          y: {
            stacked: true
          }
        }
      })
    })
  }

  renderDailyPageViewsChart() {
    const data = JSON.parse(this.dailyPageViewsChartTarget.dataset.chartData || '{"labels":[],"datasets":[]}')
    this.charts.dailyPageViewsChart = new Chart(this.dailyPageViewsChartTarget, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: data.datasets
      },
      options: Object.assign({}, sharedChartOptions, {
        scales: {
          y: {
            stacked: true
          }
        }
      })
    })
  }

  renderLinkClicksChart() {
    const data = JSON.parse(this.linkClicksChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    this.charts.linkClicksChart = new Chart(this.linkClicksChartTarget, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Link Clicks by URL',
          data: data.values,
          backgroundColor: 'rgba(255, 99, 132, 0.2)',
          borderColor: 'rgba(255, 99, 132, 1)',
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions)
    })
  }

  renderDailyLinkClicksChart() {
    const data = JSON.parse(this.dailyLinkClicksChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    this.charts.dailyLinkClicksChart = new Chart(this.dailyLinkClicksChartTarget, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Daily Link Clicks',
          data: data.values,
          backgroundColor: 'rgba(153, 102, 255, 0.2)',
          borderColor: 'rgba(153, 102, 255, 1)',
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions)
    })
  }

  renderDownloadsChart() {
    const data = JSON.parse(this.downloadsChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    this.charts.downloadsChart = new Chart(this.downloadsChartTarget, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Downloads by File',
          data: data.values,
          backgroundColor: 'rgba(54, 162, 235, 0.2)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions)
    })
  }

  renderSharesChart() {
    const data = JSON.parse(this.sharesChartTarget.dataset.chartData || '{"labels":[],"values":[]}')

    // Get the platform labels and corresponding colors
    const backgroundColors = data.labels.map(label => platformColors[label.toLowerCase()]);
    const borderColors = data.labels.map(label => platformBorderColors[label.toLowerCase()]);

    this.charts.sharesChart = new Chart(this.sharesChartTarget, {
      type: 'pie',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Shares by Platform',
          data: data.values,
          backgroundColor: backgroundColors,  // Use platform colors for the background
          borderColor: borderColors,          // Use platform colors for the border
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions, {
        plugins: {
          legend: {
            position: 'top'
          }
        }
      })
    })
  }

  renderSharesPerUrlPerPlatformChart() {
    const data = JSON.parse(this.sharesPerUrlPerPlatformChartTarget.dataset.chartData || '{"labels":[],"datasets":[]}')
    this.charts.sharesPerUrlPerPlatformChart = new Chart(this.sharesPerUrlPerPlatformChartTarget, {
      type: 'bar',
      data: data,
      options: Object.assign({}, sharedChartOptions, {
        plugins: {
          legend: {
            position: 'top'
          }
        }
      })
    })
  }

  renderLinksByHostChart() {
    const data = JSON.parse(this.linksByHostChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    this.charts.linksByHostChart = new Chart(this.linksByHostChartTarget, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Links by Host',
          data: data.values,
          backgroundColor: 'rgba(99, 132, 255, 0.2)',
          borderColor: 'rgba(99, 132, 255, 1)',
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions)
    })
  }

  renderInvalidByHostChart() {
    const data = JSON.parse(this.invalidByHostChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    this.charts.invalidByHostChart = new Chart(this.invalidByHostChartTarget, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Invalid Links by Host',
          data: data.values,
          backgroundColor: 'rgba(255, 159, 64, 0.2)',
          borderColor: 'rgba(255, 159, 64, 1)',
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions)
    })
  }

  renderFailuresDailyChart() {
    const data = JSON.parse(this.failuresDailyChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    this.charts.failuresDailyChart = new Chart(this.failuresDailyChartTarget, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Invalid Links Over Time',
          data: data.values,
          backgroundColor: 'rgba(255, 99, 132, 0.2)',
          borderColor: 'rgba(255, 99, 132, 1)',
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions)
    })
  }
}
