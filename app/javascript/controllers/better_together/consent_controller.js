import { Controller } from "@hotwired/stimulus"

// Cookie consent banner. Stores the decision in the bt_consent cookie and announces it with a
// `better_together:consent` event so extension code (for example Google consent mode) can react.
export default class extends Controller {
  static targets = ["banner", "choices", "analytics", "marketing", "reopen", "choose", "status"]
  static values = { reload: Boolean, days: { type: Number, default: 180 } }

  connect() {
    const saved = this.read()
    if (saved) this.bannerTarget.hidden = true
    this.reopenTarget.hidden = !saved
    if (saved) this.announce(saved)
  }

  acceptAll() { this.save({ analytics: true, marketing: true }) }

  essentialOnly() { this.save({ analytics: false, marketing: false }) }

  toggleChoices() {
    const open = this.choicesTarget.hidden
    this.choicesTarget.hidden = !open
    this.chooseTarget.setAttribute("aria-expanded", String(open))
    if (open) this.analyticsTarget.focus()
  }

  saveChoices() {
    this.save({ analytics: this.analyticsTarget.checked, marketing: this.marketingTarget.checked })
  }

  reopen() {
    const saved = this.read() || { analytics: false, marketing: false }
    this.analyticsTarget.checked = saved.analytics
    this.marketingTarget.checked = saved.marketing
    this.bannerTarget.hidden = false
    this.choicesTarget.hidden = false
    this.chooseTarget.setAttribute("aria-expanded", "true")
    this.reopenTarget.hidden = true
    this.analyticsTarget.focus()
  }

  save(choice) {
    const value = JSON.stringify({ v: 1, ...choice })
    const expires = new Date(Date.now() + this.daysValue * 864e5).toUTCString()
    const secure = location.protocol === "https:" ? "; Secure" : ""
    document.cookie = `bt_consent=${encodeURIComponent(value)}; Path=/; Expires=${expires}; SameSite=Lax${secure}`
    this.bannerTarget.hidden = true
    this.reopenTarget.hidden = false
    if (this.hasStatusTarget) this.statusTarget.textContent = this.statusTarget.dataset.savedMessage
    this.announce(choice)
    if (this.reloadValue) { window.location.reload() } else { this.reopenTarget.focus() }
  }

  read() {
    const match = document.cookie.split("; ").find((row) => row.startsWith("bt_consent="))
    if (!match) return null
    try {
      const data = JSON.parse(decodeURIComponent(match.split("=")[1]))
      return data.v === 1 ? { analytics: data.analytics === true, marketing: data.marketing === true } : null
    } catch (_error) { return null }
  }

  announce(choice) {
    window.btConsent = choice
    window.dispatchEvent(new CustomEvent("better_together:consent", { detail: choice }))
  }
}
