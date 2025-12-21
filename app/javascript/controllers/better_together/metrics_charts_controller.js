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
      display: false,
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
    this.chartTargets = {}
    this.chartOrder = []
    
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
    this.chartTargets = {}
    this.chartOrder = []
  }

  exportPng(event) {
    this.exportSingle(event, 'png')
  }

  exportCsv(event) {
    this.exportSingle(event, 'csv')
  }

  exportJpg(event) {
    this.exportSingle(event, 'jpg')
  }

  exportAllPng() {
    this.exportAll('png')
  }

  exportAllCsv() {
    this.exportAll('csv')
  }

  exportAllJpg() {
    this.exportAll('jpg')
  }

  exportSingle(event, format) {
    const chartName = event.currentTarget?.dataset?.chartName
    if (!chartName) return

    if (format === 'png') this.downloadChartImage(chartName, 'png')
    if (format === 'csv') this.downloadChartCsv(chartName)
    if (format === 'jpg') this.downloadChartImage(chartName, 'jpg')
  }

  exportAll(format) {
    const chartNames = this.chartOrder.length ? this.chartOrder : Object.keys(this.charts)
    if (!chartNames.length) return

    if (format === 'png') chartNames.forEach(name => this.downloadChartImage(name, 'png'))
    if (format === 'csv') chartNames.forEach(name => this.downloadChartCsv(name))
    if (format === 'jpg') chartNames.forEach(name => this.downloadChartImage(name, 'jpg'))
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
    const chart = new Chart(this.pageViewsChartTarget, {
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
    this.registerChart('pageViewsChart', this.pageViewsChartTarget, chart)
  }

  renderDailyPageViewsChart() {
    const data = JSON.parse(this.dailyPageViewsChartTarget.dataset.chartData || '{"labels":[],"datasets":[]}')
    const chart = new Chart(this.dailyPageViewsChartTarget, {
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
    this.registerChart('dailyPageViewsChart', this.dailyPageViewsChartTarget, chart)
  }

  renderLinkClicksChart() {
    const data = JSON.parse(this.linkClicksChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    const chart = new Chart(this.linkClicksChartTarget, {
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
    this.registerChart('linkClicksChart', this.linkClicksChartTarget, chart)
  }

  renderDailyLinkClicksChart() {
    const data = JSON.parse(this.dailyLinkClicksChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    const chart = new Chart(this.dailyLinkClicksChartTarget, {
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
    this.registerChart('dailyLinkClicksChart', this.dailyLinkClicksChartTarget, chart)
  }

  renderDownloadsChart() {
    const data = JSON.parse(this.downloadsChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    const chart = new Chart(this.downloadsChartTarget, {
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
    this.registerChart('downloadsChart', this.downloadsChartTarget, chart)
  }

  renderSharesChart() {
    const data = JSON.parse(this.sharesChartTarget.dataset.chartData || '{"labels":[],"values":[]}')

    // Get the platform labels and corresponding colors
    const backgroundColors = data.labels.map(label => platformColors[label.toLowerCase()]);
    const borderColors = data.labels.map(label => platformBorderColors[label.toLowerCase()]);

    const chart = new Chart(this.sharesChartTarget, {
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
            display: false,
            position: 'top'
          }
        }
      })
    })
    this.registerChart('sharesChart', this.sharesChartTarget, chart)
  }

  renderSharesPerUrlPerPlatformChart() {
    const data = JSON.parse(this.sharesPerUrlPerPlatformChartTarget.dataset.chartData || '{"labels":[],"datasets":[]}')
    const chart = new Chart(this.sharesPerUrlPerPlatformChartTarget, {
      type: 'bar',
      data: data,
      options: Object.assign({}, sharedChartOptions, {
        plugins: {
          legend: {
            display: false,
            position: 'top'
          }
        }
      })
    })
    this.registerChart('sharesPerUrlPerPlatformChart', this.sharesPerUrlPerPlatformChartTarget, chart)
  }

  renderLinksByHostChart() {
    const data = JSON.parse(this.linksByHostChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    const chart = new Chart(this.linksByHostChartTarget, {
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
    this.registerChart('linksByHostChart', this.linksByHostChartTarget, chart)
  }

  renderInvalidByHostChart() {
    const data = JSON.parse(this.invalidByHostChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    const chart = new Chart(this.invalidByHostChartTarget, {
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
    this.registerChart('invalidByHostChart', this.invalidByHostChartTarget, chart)
  }

  renderFailuresDailyChart() {
    const data = JSON.parse(this.failuresDailyChartTarget.dataset.chartData || '{"labels":[],"values":[]}')
    const chart = new Chart(this.failuresDailyChartTarget, {
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
    this.registerChart('failuresDailyChart', this.failuresDailyChartTarget, chart)
  }

  registerChart(chartName, target, chart) {
    this.charts[chartName] = chart
    this.chartTargets[chartName] = target
    if (!this.chartOrder.includes(chartName)) this.chartOrder.push(chartName)
  }

  downloadChartImage(chartName, format = 'png') {
    const chart = this.charts[chartName]
    if (!chart) return
    const mimeType = format === 'jpg' ? 'image/jpeg' : 'image/png'
    const extension = format === 'jpg' ? 'jpg' : 'png'
    const dataUrl = chart.toBase64Image(mimeType, 0.92)
    this.triggerDownload(`${this.platformFilenamePrefix()}${chartName}-${this.timestamp()}.${extension}`, dataUrl)
  }

  downloadChartCsv(chartName) {
    const chart = this.charts[chartName]
    if (!chart) return

    const csv = this.chartToCsv(chart, chartName)
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    this.triggerBlobDownload(`${this.platformFilenamePrefix()}${chartName}-${this.timestamp()}.csv`, blob)
  }


  chartToCsv(chart, chartName) {
    const labels = chart.data.labels || []
    const datasets = chart.data.datasets || []
    if (!datasets.length) return ''

    const labelHeading = this.chartLabelHeading(chartName)
    const header = [labelHeading, ...datasets.map((dataset, index) => dataset.label || `Series ${index + 1}`)]
    const rows = labels.map((label, index) => {
      const values = datasets.map(dataset => dataset.data?.[index] ?? '')
      return [label, ...values]
    })

    return [header, ...rows].map(row => row.map(this.escapeCsv).join(',')).join('\n')
  }

  triggerDownload(filename, dataUrl) {
    const link = document.createElement('a')
    link.href = dataUrl
    link.download = filename
    link.rel = 'noopener'
    link.click()
  }

  triggerBlobDownload(filename, blob) {
    const url = URL.createObjectURL(blob)
    this.triggerDownload(filename, url)
    URL.revokeObjectURL(url)
  }

  chartTitle(chartName, target) {
    const container = target?.closest('.metrics-chart-block')
    const heading = container?.querySelector('h2')
    return heading?.textContent?.trim() || chartName
  }

  chartLabelHeading(chartName) {
    const target = this.chartTargets[chartName]
    return target?.dataset?.chartLabel || 'Label'
  }

  normalizedAxisLabel(value) {
    if (value == null) return ''
    if (Array.isArray(value)) {
      return value.map(item => (item == null ? '' : String(item))).filter(Boolean).join(' ')
    }
    return String(value)
  }

  platformFilenamePrefix() {
    const rawName = this.element?.dataset?.hostPlatformName
    if (!rawName) return ''
    const sanitized = rawName
      .trim()
      .replace(/[^A-Za-z0-9-_]+/g, '-')
      .replace(/^-+|-+$/g, '')
    return sanitized ? `${sanitized}-` : ''
  }



  escapeCsv(value) {
    const stringValue = value == null ? '' : String(value)
    if (stringValue.includes('"') || stringValue.includes(',') || stringValue.includes('\n')) {
      return `"${stringValue.replace(/"/g, '""')}"`
    }
    return stringValue
  }

  escapeHtml(value) {
    const stringValue = value == null ? '' : String(value)
    return stringValue
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
  }

  timestamp() {
    return new Date().toISOString().replace(/[:.]/g, '-')
  }
}
