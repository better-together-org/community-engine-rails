import { Controller } from "@hotwired/stimulus"

const COLOR_KEYS = ["primary", "primary_text", "accent", "accent_dark", "page_bg", "band", "body_text", "link",
                    "navbar_bg", "navbar_link", "footer_bg", "footer_link"]
const FONTS = {
  system: 'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
  tahoma: "Tahoma, Verdana, Segoe, sans-serif",
  georgia: 'Georgia, "Times New Roman", Times, serif',
  monospace: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
}
const RADII = { none: "0", small: "0.25rem", medium: "0.5rem", large: "1rem" }

// Theme picker, live preview, contrast ratios, apply and reset for the platform theme fields.
// Picking a theme only previews it; Apply copies it into the fields; nothing is saved until the form is saved.
export default class extends Controller {
  static targets = ["input", "pair", "swatch", "picker", "apply", "preview", "status", "description", "state"]

  connect() {
    this.initial = this.snapshot()
    this.previewing = null
    this.refresh()
  }

  snapshot() {
    return Object.fromEntries(this.inputTargets.map((input) => [input.dataset.key, input.value]))
  }

  field(key) { return this.inputTargets.find((input) => input.dataset.key === key) }

  // Tokens that drive the preview and the contrast rows: the previewed theme, else the fields.
  tokens() {
    if (this.previewing) return this.previewing.tokens
    return Object.fromEntries(this.inputTargets.map((input) => [input.dataset.key, input.value.trim().toLowerCase()]))
  }

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

  valid(hex) { return /^#[0-9a-f]{6}$/i.test(hex || "") }

  refresh() {
    const tokens = this.tokens()
    this.swatchTargets.forEach((swatch) => {
      const value = this.field(swatch.dataset.key)?.value
      swatch.style.backgroundColor = this.valid(value) ? value : "transparent"
    })
    this.pairTargets.forEach((row) => this.updatePair(row, tokens))
    this.renderPreview(tokens)
    this.renderStatus()
  }

  renderPreview(tokens) {
    const el = this.previewTarget
    COLOR_KEYS.forEach((key) => {
      const name = `--bts-${key.replace(/_/g, "-")}`
      if (this.valid(tokens[key])) el.style.setProperty(name, tokens[key])
      else el.style.removeProperty(name)
    })
    if (FONTS[tokens.font]) el.style.setProperty("--bts-font", FONTS[tokens.font])
    else el.style.removeProperty("--bts-font")
    if (RADII[tokens.radius]) el.style.setProperty("--bts-radius", RADII[tokens.radius])
    else el.style.removeProperty("--bts-radius")
  }

  renderStatus() {
    const status = this.statusTarget
    const current = status.dataset.currentName
    const fieldsPreset = this.field("preset").value
    let text
    let state
    if (this.previewing) {
      text = status.dataset.previewingText.replace("%{name}", this.previewing.name)
      state = this.previewing.name
    } else if (fieldsPreset && current) {
      text = status.dataset.currentText.replace("%{name}", this.nameFor(fieldsPreset) || current)
      state = this.nameFor(fieldsPreset) || current
    } else {
      const any = Object.entries(this.snapshot()).some(([key, value]) => key !== "preset" && value)
      text = any ? status.dataset.customText : status.dataset.noneText
      state = text
    }
    if (status.textContent !== text) status.textContent = text
    this.stateTarget.textContent = state
    this.applyTarget.disabled = !this.previewing
  }

  nameFor(id) {
    const option = this.pickerTarget.querySelector(`option[value="${id}"]`)
    return option ? option.textContent.trim() : null
  }

  updatePair(row, tokens) {
    const fg = tokens[row.dataset.foreground]
    const bgKey = row.dataset.background
    const bg = tokens[bgKey] || (bgKey === "page_bg" ? "#ffffff" : null)
    const output = row.querySelector("[data-role='ratio']")
    const status = row.querySelector("[data-role='status']")
    row.classList.remove("text-danger", "text-success")
    if (!this.valid(fg) || !this.valid(bg)) {
      output.textContent = "-"
      status.textContent = ""
      return
    }
    const ratio = this.ratio(fg, bg)
    const minimum = parseFloat(row.dataset.minimum)
    const passes = ratio >= minimum
    output.textContent = `${ratio.toFixed(2)}:1`
    status.textContent = !passes ? row.dataset.failText : (ratio >= 7 && minimum >= 4.5 ? row.dataset.aaaText : row.dataset.passText)
    row.classList.add(passes ? "text-success" : "text-danger")
  }

  selectTheme() {
    const option = this.pickerTarget.selectedOptions[0]
    if (!option || !option.value) {
      this.previewing = null
      this.descriptionTarget.textContent = ""
    } else {
      this.previewing = { id: option.value, name: option.textContent.trim(), tokens: JSON.parse(option.dataset.tokens) }
      this.descriptionTarget.textContent = option.dataset.description || ""
    }
    this.refresh()
  }

  applyTheme() {
    if (!this.previewing) return
    const { id, name, tokens } = this.previewing
    this.inputTargets.forEach((input) => { input.value = input.dataset.key === "preset" ? id : (tokens[input.dataset.key] || "") })
    this.previewing = null
    this.refresh()
    this.statusTarget.textContent = this.statusTarget.dataset.appliedText.replace("%{name}", name)
  }

  // A manual edit leaves any previewed theme and marks the fields as custom.
  edited() {
    this.previewing = null
    this.field("preset").value = ""
    this.refresh()
  }

  // Back to the values the form loaded with.
  reset() {
    this.inputTargets.forEach((input) => { input.value = this.initial[input.dataset.key] || "" })
    this.previewing = null
    this.pickerTarget.value = this.initial.preset || ""
    this.descriptionTarget.textContent = ""
    this.refresh()
  }

  clear() {
    this.inputTargets.forEach((input) => { input.value = "" })
    this.previewing = null
    this.refresh()
  }
}
