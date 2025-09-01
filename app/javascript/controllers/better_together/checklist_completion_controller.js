import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { checklistId: String }
  static targets = [ 'message' ]

  // safe accessors for environments where I18n or BetterTogether globals aren't present
  get locale() {
    try { return (window.I18n && I18n.locale) || document.documentElement.lang || 'en' } catch (e) { return 'en' }
  }

  get routeScopePath() {
    try { return (window.BetterTogether && BetterTogether.route_scope_path) || this.element.dataset.routeScopePath || '' } catch (e) { return '' }
  }

  connect() {
    this.checkCompletion = this.checkCompletion.bind(this)
    this.element.addEventListener('person-checklist-item:toggled', this.checkCompletion)
  // Prepare message text, then perform an initial check
  this.messageText = this.element.dataset.betterTogetherChecklistCompletionMessageValue || 'Checklist complete'

  // Initial check
  this.checkCompletion()
  }

  disconnect() {
    this.element.removeEventListener('person-checklist-item:toggled', this.checkCompletion)
  }

  checkCompletion() {
    const url = `/${this.locale}/${this.routeScopePath}/checklists/${this.checklistIdValue}/completion_status`
    fetch(url, { credentials: 'same-origin', headers: { Accept: 'application/json' } })
      .then((r) => r.json())
      .then((data) => {
        // expose a DOM attribute for tests to observe
        this.element.setAttribute('data-checklist-complete', data.complete)
        if (this.hasMessageTarget) {
          if (data.complete) {
            this.messageTarget.innerHTML = `<div class="alert alert-success">${this.messageText}</div>`
          } else {
            this.messageTarget.innerHTML = ''
          }
        }
      }).catch(() => {})
  }
}
