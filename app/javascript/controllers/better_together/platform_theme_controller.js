import { Controller } from "@hotwired/stimulus"

// Live WCAG contrast ratios, preset loading and reset for the platform theme fields.
export default class extends Controller {
  static targets = ["input", "pair", "swatch"]
  static values = { threshold: { type: Number, default: 4.5 } }

  connect() { this.refresh() }

  refresh() {
    this.swatchTargets.forEach((swatch) => {
      const input = this.field(swatch.dataset.key)
      swatch.style.backgroundColor = this.valid(input?.value) ? input.value : "transparent"
    })
    this.pairTargets.forEach((row) => this.updatePair(row))
  }

  updatePair(row) {
    const fg = this.value(row.dataset.foreground)
    const bg = row.dataset.background === "white" ? "#ffffff" : this.value(row.dataset.background)
    const output = row.querySelector("[data-role='ratio']")
    const status = row.querySelector("[data-role='status']")
    if (!this.valid(fg) || !this.valid(bg)) {
      output.textContent = "-"
      status.textContent = ""
      row.classList.remove("text-danger", "text-success")
      return
    }
    const ratio = this.ratio(fg, bg)
    const passes = ratio >= this.thresholdValue
    output.textContent = `${ratio.toFixed(2)}:1`
    status.textContent = passes ? row.dataset.passText : row.dataset.failText
    row.classList.toggle("text-danger", !passes)
    row.classList.toggle("text-success", passes)
  }

  applyPreset(event) {
    const preset = JSON.parse(event.currentTarget.dataset.preset)
    this.inputTargets.forEach((input) => { input.value = preset[input.dataset.key] || "" })
    this.refresh()
  }

  reset() {
    this.inputTargets.forEach((input) => { input.value = "" })
    this.refresh()
  }

  field(key) { return this.inputTargets.find((input) => input.dataset.key === key) }
  value(key) { return this.field(key)?.value?.trim().toLowerCase() }
  valid(hex) { return /^#[0-9a-f]{6}$/i.test(hex || "") }

  ratio(a, b) {
    const [hi, lo] = [this.luminance(a), this.luminance(b)].sort((x, y) => y - x)
    return (hi + 0.05) / (lo + 0.05)
  }

  luminance(hex) {
    const [r, g, bl] = [1, 3, 5].map((i) => {
      const c = parseInt(hex.slice(i, i + 2), 16) / 255
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
    })
    return 0.2126 * r + 0.7152 * g + 0.0722 * bl
  }
}
