// Chart.js text, grid and legend colours read the Bootstrap colour variables when a chart is drawn, and the charts
// redraw when data-bs-theme changes. Data series colours are left to the charts that set them.
const cssVar = (name, fallback) => getComputedStyle(document.documentElement).getPropertyValue(name).trim() || fallback

export function applyChartColours() {
  if (!window.Chart) return
  window.Chart.defaults.color = cssVar("--bs-body-color", "#212529")
  window.Chart.defaults.borderColor = cssVar("--bs-border-color", "#dee2e6")
}

// Returns a function that stops watching. `charts` is called on each change and returns the live Chart instances.
export function watchChartColours(charts) {
  applyChartColours()
  const observer = new MutationObserver(() => {
    applyChartColours()
    charts().forEach((chart) => { if (chart) chart.update("none") })
  })
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ["data-bs-theme"] })
  return () => observer.disconnect()
}
