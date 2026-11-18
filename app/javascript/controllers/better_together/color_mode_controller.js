import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "bts-color-mode"
const COOKIE = "bts_color_mode"
const MODES = ["auto", "light", "dark"]

// Visitor colour mode: Auto follows prefers-color-scheme, Light and Dark are explicit. The header shows one button
// for the appearance in use; a click switches to the opposite explicitly. Auto is set from Preferences.
// The choice is kept in localStorage and a cookie (so the server renders the right mode on first paint)
// and applied through Bootstrap 5.3's data-bs-theme on the html element.
export default class extends Controller {
  static targets = ["button", "status"]
  static values = { saveUrl: String, announceLight: String, announceDark: String, labelToLight: String, labelToDark: String }

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

  get dark() { return this.root.getAttribute("data-bs-theme") === "dark" }

  toggle() {
    const mode = this.dark ? "light" : "dark"
    this.root.dataset.btsColorMode = mode
    if (this.hasSaveUrlValue && this.saveUrlValue) this.root.dataset.btsUserMode = mode
    this.save(mode)
    this.apply()
    this.statusTarget.textContent = mode === "dark" ? this.announceDarkValue : this.announceLightValue
  }

  apply() {
    const mode = this.mode
    const dark = mode === "dark" || (mode === "auto" && this.media && this.media.matches)
    this.root.setAttribute("data-bs-theme", dark ? "dark" : "light")
    this.buttonTargets.forEach((button) => {
      const label = dark ? this.labelToLightValue : this.labelToDarkValue
      button.setAttribute("aria-label", label)
      button.setAttribute("title", label)
    })
  }

  save(mode) {
    try { window.localStorage.setItem(STORAGE_KEY, mode) } catch (e) { /* storage may be unavailable */ }
    const secure = window.location.protocol === "https:" ? "; Secure" : ""
    document.cookie = `${COOKIE}=${mode}; path=/; max-age=31536000; SameSite=Lax${secure}`
    this.saveToAccount(mode)
  }

  // A signed-in person's stored preference is the source of truth, so keep it in step with the toggle.
  saveToAccount(mode) {
    if (!this.hasSaveUrlValue || !this.saveUrlValue) return
    const body = new FormData()
    body.append("person[color_mode]", mode)
    fetch(this.saveUrlValue, {
      method: "PATCH",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content, "Accept": "application/json" },
      body
    }).catch(() => { /* the local choice still applies */ })
  }
}
