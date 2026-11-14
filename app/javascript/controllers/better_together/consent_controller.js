import { Controller } from "@hotwired/stimulus"

// Cookie consent banner. Stores the decision in the bt_consent cookie and announces it with a
// `better_together:consent` event so extension code (for example Google consent mode) can react.
// For a signed-in person the decision is also sent to the server (persistUrl), which stores it on
// their record; the server rewrites the same cookie on later visits.
export default class extends Controller {
  static targets = ["banner", "choices", "analytics", "marketing", "reopen", "choose", "status"]
  static values = {
    reload: Boolean,
    days: { type: Number, default: 180 },
    policyVersion: String,
    persistUrl: String
  }

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
    if (open && this.hasAnalyticsTarget) this.analyticsTarget.focus()
    else if (open && this.hasMarketingTarget) this.marketingTarget.focus()
  }

  saveChoices() { this.save(this.choiceFromForm()) }

  reopen() {
    const saved = this.read() || { analytics: false, marketing: false }
    if (this.hasAnalyticsTarget) this.analyticsTarget.checked = saved.analytics
    if (this.hasMarketingTarget) this.marketingTarget.checked = saved.marketing
    this.bannerTarget.hidden = false
    this.choicesTarget.hidden = false
    this.chooseTarget.setAttribute("aria-expanded", "true")
    this.reopenTarget.hidden = true
    if (this.hasAnalyticsTarget) this.analyticsTarget.focus()
    else if (this.hasMarketingTarget) this.marketingTarget.focus()
  }

  choiceFromForm() {
    return {
      analytics: this.hasAnalyticsTarget && this.analyticsTarget.checked,
      marketing: this.hasMarketingTarget && this.marketingTarget.checked
    }
  }

  async save(choice) {
    this.writeCookie(choice)
    this.bannerTarget.hidden = true
    this.reopenTarget.hidden = false
    if (this.hasStatusTarget) this.statusTarget.textContent = this.statusTarget.dataset.savedMessage
    this.announce(choice)
    // Wait for the server so a reload does not cancel the request.
    await this.persist(choice)
    if (this.reloadValue) { window.location.reload() } else { this.reopenTarget.focus() }
  }

  writeCookie(choice) {
    const value = JSON.stringify({ v: 1, ...choice, pv: this.policyVersionValue })
    const expires = new Date(Date.now() + this.daysValue * 864e5).toUTCString()
    const secure = location.protocol === "https:" ? "; Secure" : ""
    document.cookie = `bt_consent=${encodeURIComponent(value)}; Path=/; Expires=${expires}; SameSite=Lax${secure}`
  }

  // Signed-in people only (the layout sets persistUrl). A failure leaves the cookie decision in place.
  async persist(choice) {
    if (!this.hasPersistUrlValue || this.persistUrlValue === "") return null
    const token = document.querySelector("meta[name='csrf-token']")?.content
    try {
      const response = await fetch(this.persistUrlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": token || "" },
        body: JSON.stringify({ consent: choice })
      })
      return response.ok ? await response.json() : null
    } catch (_error) { return null }
  }

  read() {
    const match = document.cookie.split("; ").find((row) => row.startsWith("bt_consent="))
    if (!match) return null
    try {
      const data = JSON.parse(decodeURIComponent(match.split("=")[1]))
      if (data.v !== 1) return null
      if (this.policyVersionValue && data.pv !== this.policyVersionValue) return null
      return { analytics: data.analytics === true, marketing: data.marketing === true }
    } catch (_error) { return null }
  }

  announce(choice) {
    window.btConsent = choice
    window.dispatchEvent(new CustomEvent("better_together:consent", { detail: choice }))
  }
}
