import ConsentController from "controllers/better_together/consent_controller"

// Cookie consent form in the person's settings. Reuses the banner's cookie writing, server
// persistence and `better_together:consent` event, so scripts react without a page reload.
export default class extends ConsentController {
  static targets = ["analytics", "marketing", "stored", "status"]

  connect() {
    const saved = this.read()
    if (saved) this.announce(saved)
  }

  submit(event) {
    event.preventDefault()
    this.apply(this.choiceFromForm())
  }

  withdrawAll() {
    if (this.hasAnalyticsTarget) this.analyticsTarget.checked = false
    if (this.hasMarketingTarget) this.marketingTarget.checked = false
    this.apply({ analytics: false, marketing: false })
  }

  async apply(choice) {
    this.writeCookie(choice)
    this.announce(choice)
    const stored = await this.persist(choice)
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = stored ? this.statusTarget.dataset.savedMessage : this.statusTarget.dataset.errorMessage
    }
    if (stored && this.hasStoredTarget) this.storedTarget.textContent = this.storedTarget.dataset.savedTemplate.replace("%{date}", new Date(stored.decided_at).toLocaleDateString(document.documentElement.lang || undefined, { dateStyle: "long" }))
  }
}
