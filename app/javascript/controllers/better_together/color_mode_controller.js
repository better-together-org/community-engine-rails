import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "bts-color-mode"
const COOKIE = "bts_color_mode"
const MODES = ["auto", "light", "dark"]

// Visitor colour mode: Auto follows prefers-color-scheme, Light and Dark are explicit.
// The choice is kept in localStorage and a cookie (so the server renders the right mode on first paint)
// and applied through Bootstrap 5.3's data-bs-theme on the html element.
export default class extends Controller {
  static targets = ["button", "status"]
  static values = { announceAuto: String, announceLight: String, announceDark: String }

  connect() {
    this.root = document.documentElement
    this.media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null
    this.onSystemChange = () => { if (this.mode === "auto") this.apply() }
    if (this.media) this.media.addEventListener("change", this.onSystemChange)
    this.apply()
  }

  disconnect() {
    if (this.media) this.media.removeEventListener("change", this.onSystemChange)
  }

  get mode() {
    const mode = this.root.dataset.btsColorMode
    return MODES.includes(mode) ? mode : "auto"
  }

  select(event) {
    const mode = event.currentTarget.dataset.mode
    if (!MODES.includes(mode)) return
    this.root.dataset.btsColorMode = mode
    this.save(mode)
    this.apply()
    this.statusTarget.textContent = this[`announce${mode[0].toUpperCase()}${mode.slice(1)}Value`]
  }

  apply() {
    const mode = this.mode
    const dark = mode === "dark" || (mode === "auto" && this.media && this.media.matches)
    this.root.setAttribute("data-bs-theme", dark ? "dark" : "light")
    this.buttonTargets.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.mode === mode)))
  }

  save(mode) {
    try { window.localStorage.setItem(STORAGE_KEY, mode) } catch (e) { /* storage may be unavailable */ }
    const secure = window.location.protocol === "https:" ? "; Secure" : ""
    document.cookie = `${COOKIE}=${mode}; path=/; max-age=31536000; SameSite=Lax${secure}`
  }
}
