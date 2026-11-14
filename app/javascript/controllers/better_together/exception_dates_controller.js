import { Controller } from "@hotwired/stimulus"

// Manages the repeatable exception-date rows for a recurring event.
// Mirrors the add/remove template-clone pattern used by event_hosts_controller.js,
// simplified because exception_dates is a plain array attribute (no per-row
// id/_destroy bookkeeping — removing a row just removes it from the DOM).
export default class extends Controller {
  static targets = ["container", "template", "row", "announcement"]

  add(event) {
    event.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/EXCEPTION_INDEX/g, `new-${Date.now()}`)
    this.containerTarget.insertAdjacentHTML('beforeend', content)

    const rows = this.rowTargets
    const newest = rows[rows.length - 1]
    const input = newest ? newest.querySelector('input[type="date"]') : null
    if (input) input.focus()
  }

  remove(event) {
    event.preventDefault()

    const row = event.target.closest('[data-better-together--exception-dates-target="row"]')
    if (!row) return

    row.remove()
    this.announce()
  }

  announce() {
    if (!this.hasAnnouncementTarget) return

    this.announcementTarget.textContent = this.element.dataset.exceptionDateRemovedText || 'Exception date removed'
    setTimeout(() => { this.announcementTarget.textContent = '' }, 3000)
  }
}
