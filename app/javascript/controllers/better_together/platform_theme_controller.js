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
// Only mode settings, not theme content: Apply, Clear and the "custom" status leave these alone.
const MODE_KEYS = ["dark_mode", "default_mode"]
// Pairs checked in the contrast list: foreground, background, minimum ratio.
const PAIRS = [["primary_text", "primary", 4.5], ["navbar_link", "navbar_bg", 4.5], ["footer_link", "footer_bg", 4.5],
               ["body_text", "page_bg", 4.5], ["body_text", "band", 4.5], ["link", "page_bg", 4.5], ["link", "band", 4.5],
               ["accent_dark", "page_bg", 4.5], ["accent", "page_bg", 3]]
// Backdrop for the dark preview when a token is unset (Bootstrap 5.3 dark surfaces).
const DARK_FALLBACK = { page_bg: "#212529", band: "#2b3035", body_text: "#dee2e6", link: "#6ea8fe", navbar_bg: "#212529",
                        navbar_link: "#ffffff", footer_bg: "#212529", footer_link: "#ffffff", accent: "#6ea8fe" }

// Theme picker, live preview, contrast ratios, apply and reset for the platform theme fields.
// Picking a theme only previews it; Apply copies it into the fields; nothing is saved until the form is saved.
export default class extends Controller {
  static targets = ["input", "pair", "swatch", "picker", "apply", "preview", "status", "description", "state",
                    "modeButton", "darkFields", "summary"]
  static values = { deriveUrl: String }

  connect() {
    this.initial = this.snapshot()
    this.previewing = null
    this.previewModeName = "light"
    this.derived = null
    this.refresh()
    this.requestDerived()
  }

  snapshot() {
    return Object.fromEntries(this.inputTargets.map((input) => [input.dataset.key, input.value]))
  }

  field(key) { return this.inputTargets.find((input) => input.dataset.key === key) }

  fieldTokens() {
    return Object.fromEntries(this.inputTargets.map((input) => [input.dataset.key, input.value.trim().toLowerCase()]))
  }

  // Light tokens plus font and radius: the previewed theme, else the fields.
  lightTokens() {
    if (this.previewing) return this.previewing.tokens
    return this.fieldTokens()
  }

  // Dark tokens for colours that have a light value: the previewed theme's, else custom fields over derived ones.
  darkTokens() {
    const source = this.previewing ? this.previewing.tokens : this.fieldTokens()
    const custom = source.dark_source === "custom"
    const out = Object.assign({}, this.previewing ? {} : (this.derived ? this.derived.tokens : {}))
    if (custom) {
      COLOR_KEYS.forEach((key) => {
        if (this.valid(source[`dark_${key}`]) && (this.previewing || this.valid(source[key]))) out[key] = source[`dark_${key}`]
      })
    }
    return out
  }

  // Tokens that drive the preview and the contrast rows for the previewed mode.
  tokens() {
    const light = this.lightTokens()
    if (this.previewModeName !== "dark") return light
    const dark = this.darkTokens()
    const out = Object.assign({}, light)
    COLOR_KEYS.forEach((key) => { out[key] = dark[key] || DARK_FALLBACK[key] || "" })
    return out
  }

  // Derived dark tokens come from the server so the preview matches what is rendered.
  requestDerived() {
    if (!this.hasDeriveUrlValue || !this.deriveUrlValue) return
    clearTimeout(this.deriveTimer)
    this.deriveTimer = setTimeout(async () => {
      const fields = this.fieldTokens()
      const params = new URLSearchParams()
      COLOR_KEYS.forEach((key) => { if (this.valid(fields[key])) params.set(`theme[${key}]`, fields[key]) })
      if (this.deriveController) this.deriveController.abort()
      this.deriveController = new AbortController()
      try {
        const response = await fetch(`${this.deriveUrlValue}?${params}`, { headers: { Accept: "application/json" }, signal: this.deriveController.signal })
        if (!response.ok) return
        this.derived = await response.json()
        this.refresh()
      } catch (error) { /* aborted or offline: keep the previous derived tokens */ }
    }, 150)
  }

  previewMode(event) {
    this.previewModeName = event.currentTarget.dataset.mode === "dark" ? "dark" : "light"
    this.refresh()
  }

  modeEdited() { this.refresh() }

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
    this.renderModes()
  }

  // Mode switch state, custom dark fields visibility and the below-AA summary for both modes.
  renderModes() {
    this.modeButtonTargets.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.mode === this.previewModeName)))
    this.previewTarget.querySelector(".bts-preview").setAttribute("data-bs-theme", this.previewModeName)
    const source = this.previewing ? this.previewing.tokens.dark_source : this.field("dark_source").value
    this.darkFieldsTarget.hidden = source !== "custom"
    if (!this.hasSummaryTarget) return
    const enabled = this.field("dark_mode").value !== "disabled"
    const light = this.lightTokens()
    const dark = Object.assign({}, light)
    const darkOnly = this.darkTokens()
    COLOR_KEYS.forEach((key) => { dark[key] = darkOnly[key] || (this.valid(light[key]) ? DARK_FALLBACK[key] || "" : "") })
    const summary = this.summaryTarget
    const describe = (name, tokens, fallbackPage) => {
      const failing = PAIRS.filter(([fg, bg, min]) => {
        const back = tokens[bg] || (bg === "page_bg" ? fallbackPage : null)
        return this.valid(tokens[fg]) && this.valid(back) && this.ratio(tokens[fg], back) < min
      }).length
      return { failing, text: (failing ? summary.dataset.failText : summary.dataset.okText).replace("%{mode}", name).replace("%{count}", failing) }
    }
    const results = [describe(summary.dataset.lightName, light, "#ffffff")]
    if (enabled) results.push(describe(summary.dataset.darkName, dark, DARK_FALLBACK.page_bg))
    summary.textContent = results.map((result) => result.text).join(" ")
    summary.classList.toggle("text-danger", results.some((result) => result.failing > 0))
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
      const any = Object.entries(this.snapshot()).some(([key, value]) => !["preset", "dark_source", ...MODE_KEYS].includes(key) && value)
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
    this.inputTargets.forEach((input) => {
      const key = input.dataset.key
      if (MODE_KEYS.includes(key)) return
      if (key === "dark_source") input.value = tokens.dark_source || "derive"
      else input.value = key === "preset" ? id : (tokens[key] || "")
    })
    this.previewing = null
    this.refresh()
    this.statusTarget.textContent = this.statusTarget.dataset.appliedText.replace("%{name}", name)
  }

  // A manual edit leaves any previewed theme and marks the fields as custom.
  edited() {
    this.previewing = null
    this.field("preset").value = ""
    this.refresh()
    this.requestDerived()
  }

  // Back to the values the form loaded with.
  reset() {
    this.inputTargets.forEach((input) => { input.value = this.initial[input.dataset.key] || "" })
    this.previewing = null
    this.pickerTarget.value = this.initial.preset || ""
    this.descriptionTarget.textContent = ""
    this.refresh()
    this.requestDerived()
  }

  clear() {
    this.inputTargets.forEach((input) => {
      if (MODE_KEYS.includes(input.dataset.key)) return
      input.value = input.dataset.key === "dark_source" ? "derive" : ""
    })
    this.previewing = null
    this.refresh()
    this.requestDerived()
  }
}
