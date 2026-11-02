import { Controller } from "@hotwired/stimulus"
import "chart.js"

// Draws the stored 14 day weather history. The server provides the series, the translated
// dataset names and the axis units; this controller only renders them. A null value is a
// measurement the station did not report, so it stays a gap and is never drawn as zero.
const COLORS = {
  hot: "#b02a37",
  cold: "#0a58ca",
  neutral: "#495057",
  rain: "#0a58ca",
  wind: "#087990",
  gust: "#b35900"
}

export default class extends Controller {
  static targets = ["temperature", "precipitation", "wind"]
  static values = { series: Object, labels: Object, units: Object }

  connect() {
    this.charts = []
    if (this.hasTemperatureTarget) this.draw(this.temperatureTarget, this.temperatureConfig())
    if (this.hasPrecipitationTarget) this.draw(this.precipitationTarget, this.precipitationConfig())
    if (this.hasWindTarget) this.draw(this.windTarget, this.windConfig())
  }

  disconnect() {
    this.charts.forEach((chart) => chart.destroy())
    this.charts = []
  }

  draw(canvas, config) {
    this.charts.push(new Chart(canvas, config))
  }

  line(key, color, extra = {}) {
    return {
      label: this.labelsValue[key],
      data: this.seriesValue[key],
      borderColor: color,
      backgroundColor: color,
      spanGaps: false,
      tension: 0.2,
      ...extra
    }
  }

  bar(key, color) {
    return { label: this.labelsValue[key], data: this.seriesValue[key], backgroundColor: color }
  }

  temperatureConfig() {
    return this.config("line", [
      this.line("temperature_max_c", COLORS.hot, { pointStyle: "circle" }),
      this.line("temperature_min_c", COLORS.cold, { pointStyle: "triangle" }),
      this.line("temperature_mean_c", COLORS.neutral, { borderDash: [6, 4], pointStyle: "rect" })
    ].filter((set) => this.hasValues(set)), this.unitsValue.celsius)
  }

  precipitationConfig() {
    return this.config("bar", [
      this.bar("precip_mm", COLORS.rain)
    ].filter((set) => this.hasValues(set)), this.unitsValue.mm)
  }

  windConfig() {
    return this.config("line", [
      this.line("wind_speed_kmh", COLORS.wind, { pointStyle: "circle" }),
      this.line("wind_gust_kmh", COLORS.gust, { pointStyle: "triangle" })
    ].filter((set) => this.hasValues(set)), this.unitsValue.kmh)
  }

  hasValues(dataset) {
    return dataset.data.some((value) => value !== null && value !== undefined)
  }

  config(type, datasets, unit) {
    return {
      type,
      data: { labels: this.seriesValue.labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        scales: {
          x: { ticks: { maxRotation: 60, minRotation: 0, autoSkip: true } },
          y: { beginAtZero: type === "bar", title: { display: true, text: unit } }
        },
        plugins: { legend: { display: true, position: "bottom" } }
      }
    }
  }
}
