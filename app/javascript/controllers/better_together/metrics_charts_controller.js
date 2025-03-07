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
  twitter: 'rgba(29, 161, 242, 0.5)',  // Twitter Blue
  linkedin: 'rgba(0, 123, 182, 0.5)',  // LinkedIn Blue
  pinterest: 'rgba(189, 8, 28, 0.5)',  // Pinterest Red
  reddit: 'rgba(255, 69, 0, 0.5)',     // Reddit Orange
  whatsapp: 'rgba(37, 211, 102, 0.5)', // WhatsApp Green
};

const platformBorderColors = {
  facebook: 'rgba(59, 89, 152, 1)',
  twitter: 'rgba(29, 161, 242, 1)',
  linkedin: 'rgba(0, 123, 182, 1)',
  pinterest: 'rgba(189, 8, 28, 1)',
  reddit: 'rgba(255, 69, 0, 1)',
  whatsapp: 'rgba(37, 211, 102, 1)',
};

export default class extends Controller {
  static targets = ["pageViewsChart", "dailyPageViewsChart", "linkClicksChart", "dailyLinkClicksChart", "downloadsChart", "sharesChart", "sharesPerUrlPerPlatformChart"]
  
  connect() {
    this.renderPageViewsChart()
    this.renderDailyPageViewsChart()
    this.renderLinkClicksChart()
    this.renderDailyLinkClicksChart()
    this.renderDownloadsChart()
    this.renderSharesChart()
    this.renderSharesPerUrlPerPlatformChart()
  }

  renderPageViewsChart() {
    const data = JSON.parse(this.pageViewsChartTarget.dataset.chartData)
    new Chart(this.pageViewsChartTarget, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Page Views by Page',
          data: data.values,
          backgroundColor: 'rgba(75, 192, 192, 0.2)',
          borderColor: 'rgba(75, 192, 192, 1)',
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions)
    })
  }

  renderDailyPageViewsChart() {
    const data = JSON.parse(this.dailyPageViewsChartTarget.dataset.chartData)
    new Chart(this.dailyPageViewsChartTarget, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Daily Page Views',
          data: data.values,
          backgroundColor: 'rgba(153, 102, 255, 0.2)',
          borderColor: 'rgba(153, 102, 255, 1)',
          borderWidth: 1
        }]
      },
      options: Object.assign({}, sharedChartOptions)
    })
  }

  renderLinkClicksChart() {
    const data = JSON.parse(this.linkClicksChartTarget.dataset.chartData)
    new Chart(this.linkClicksChartTarget, {
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
    const data = JSON.parse(this.dailyLinkClicksChartTarget.dataset.chartData)
    new Chart(this.dailyLinkClicksChartTarget, {
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
    const data = JSON.parse(this.downloadsChartTarget.dataset.chartData)
    new Chart(this.downloadsChartTarget, {
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
    const data = JSON.parse(this.sharesChartTarget.dataset.chartData)
  
    // Get the platform labels and corresponding colors
    const backgroundColors = data.labels.map(label => platformColors[label.toLowerCase()]);
    const borderColors = data.labels.map(label => platformBorderColors[label.toLowerCase()]);
  
    new Chart(this.sharesChartTarget, {
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
    const data = JSON.parse(this.sharesPerUrlPerPlatformChartTarget.dataset.chartData)
    new Chart(this.sharesPerUrlPerPlatformChartTarget, {
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
}
