import { Controller } from "@hotwired/stimulus"
import { syncThemeStyles } from "better_together/theme_styles"

const MODES = ["auto", "light", "dark"]

// Live preview for a person's theme and colour mode in their settings. Nothing is saved by choosing;
// each field saves through the preference field controller, then this applies the saved choice to the
// page in place: the colour mode at once, the theme styles as the server now renders them.
export default class extends Controller {
  static targets = ["preview", "state", "note"]
  static values = { themes: Object, stateText: String, contrastNote: String }

  connect() {
    this.applied = []
    this.update()
  }

  get themeSelect() { return this.element.querySelector("#person_theme") }
  get modeSelect() { return this.element.querySelector("#person_color_mode") }

  update() {
    const themeId = this.themeSelect ? this.themeSelect.value : ""
    const theme = this.themesValue[themeId] || this.themesValue[""] || { light: {}, dark: {}, failures: 0 }
    const mode = this.resolve(this.modeSelect ? this.modeSelect.value : "auto")
    const el = this.previewTarget
    this.applied.forEach((name) => el.style.removeProperty(name))
    this.applied = []
    const tokens = Object.assign({}, theme.light, mode === "dark" ? theme.dark : {})
    Object.entries(tokens).forEach(([name, value]) => { el.style.setProperty(name, value); this.applied.push(name) })
    el.setAttribute("data-bs-theme", mode)
    this.describe(themeId, mode, theme)
  }

  describe(themeId, mode, theme) {
    const option = this.themeSelect ? this.themeSelect.selectedOptions[0] : null
    const themeName = option ? option.textContent.trim() : ""
    const modeOption = this.modeSelect ? this.modeSelect.selectedOptions[0] : null
    const modeName = modeOption ? modeOption.textContent.trim() : mode
    this.stateTarget.textContent = this.stateTextValue.replace("%{theme}", themeName).replace("%{mode}", modeName)
    const failing = theme.failures > 0
    this.noteTarget.hidden = !failing
    this.noteTarget.textContent = failing ? this.contrastNoteValue : ""
  }

  resolve(mode) {
    if (mode === "dark" || mode === "light") return mode
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }

  saved(event) {
    const { field, value } = event.detail
    if (field === "color_mode" && MODES.includes(value)) this.applyMode(value)
    if (field === "theme" || field === "color_mode") this.refreshThemeStyles()
  }

  // Swaps in the theme styles the server now renders, without leaving the page. Only the newest save applies,
  // so quick successive choices cannot land out of order.
  async refreshThemeStyles() {
    const request = (this.request = (this.request || 0) + 1)
    let doc
    try {
      const response = await fetch(window.location.href, { headers: { Accept: "text/html" }, cache: "no-store", credentials: "same-origin" })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      doc = new DOMParser().parseFromString(await response.text(), "text/html")
    } catch (e) {
      window.location.reload()
      return
    }
    if (request !== this.request) return

    syncThemeStyles(doc)
    const mode = document.documentElement.getAttribute("data-bts-user-mode")
    if (MODES.includes(mode)) this.applyMode(mode)
    if (window.Turbo && window.Turbo.cache) window.Turbo.cache.clear()
    this.element.dispatchEvent(new CustomEvent("theme:applied", { bubbles: true }))
  }

  applyMode(mode) {
    const root = document.documentElement
    root.dataset.btsColorMode = mode
    root.dataset.btsUserMode = mode
    root.setAttribute("data-bs-theme", this.resolve(mode))
    try { window.localStorage.setItem("bts-color-mode", mode) } catch (e) { /* storage may be unavailable */ }
    const secure = window.location.protocol === "https:" ? "; Secure" : ""
    document.cookie = `bts_color_mode=${mode}; path=/; max-age=31536000; SameSite=Lax${secure}`
  }
}
