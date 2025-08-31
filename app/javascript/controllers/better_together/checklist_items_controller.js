import { Controller } from '@hotwired/stimulus'

// This controller is intentionally minimal; Turbo Streams handle most updates.
export default class extends Controller {
  static targets = [ 'list', 'form' ]
  static values = { checklistId: String }

  connect() {
    // Accessible live region for announcements
    this.liveRegion = document.getElementById('a11y-live-region') || this.createLiveRegion()
  this.addKeyboardHandlers()
  this.addDragHandlers()
  }

  createLiveRegion() {
    const lr = document.createElement('div')
    lr.id = 'a11y-live-region'
    lr.setAttribute('aria-live', 'polite')
    lr.setAttribute('aria-atomic', 'true')
    lr.style.position = 'absolute'
    lr.style.left = '-9999px'
    lr.style.width = '1px'
    lr.style.height = '1px'
    document.body.appendChild(lr)
    return lr
  }

  focusForm(event) {
    // Called via data-action on the appended stream node
    // Give DOM a tick for Turbo to render the new nodes, then focus
    setTimeout(() => {
      const f = this.hasFormTarget ? this.formTarget.querySelector('form') : null
      if (f) {
        f.querySelector('input, textarea')?.focus()
      }

      // Announce success if provided
      const elem = event.currentTarget || event.target
      const announcement = elem?.dataset?.betterTogetherChecklistItemsAnnouncement
      if (announcement) this.liveRegion.textContent = announcement
    }, 50)
  }

  addKeyboardHandlers() {
    if (!this.hasListTarget) return

    this.listTarget.querySelectorAll('li[tabindex]').forEach((li) => {
      li.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowUp' && e.ctrlKey) {
          e.preventDefault()
          li.querySelector('.keyboard-move-up')?.click()
        } else if (e.key === 'ArrowDown' && e.ctrlKey) {
          e.preventDefault()
          li.querySelector('.keyboard-move-down')?.click()
        }
      })
    })
  }

  addDragHandlers() {
    if (!this.hasListTarget) return

    let dragSrc = null
    const list = this.listTarget

    list.querySelectorAll('li[draggable]').forEach((el) => {
      el.addEventListener('dragstart', (e) => {
        dragSrc = el
        e.dataTransfer.effectAllowed = 'move'
      })

      el.addEventListener('dragover', (e) => {
        e.preventDefault()
        e.dataTransfer.dropEffect = 'move'
      })

      el.addEventListener('drop', (e) => {
        e.preventDefault()
        if (!dragSrc || dragSrc === el) return
        // Insert dragSrc before or after target depending on position
        const rect = el.getBoundingClientRect()
        const before = (e.clientY - rect.top) < (rect.height / 2)
        if (before) el.parentNode.insertBefore(dragSrc, el)
        else el.parentNode.insertBefore(dragSrc, el.nextSibling)

        this.postReorder()
      })
    })
  }

  postReorder() {
    const ids = Array.from(this.listTarget.querySelectorAll('li[data-id]')).map((li) => li.dataset.id)
    const url = `/` + I18n.locale + `/${BetterTogether.route_scope_path}/checklists/${this.checklistIdValue}/checklist_items/reorder`
    fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'X-CSRF-Token': document.querySelector('meta[name=csrf-token]').content },
      body: JSON.stringify({ ordered_ids: ids })
    }).then(() => {
      // Optionally announce completion
      this.liveRegion.textContent = 'Items reordered'
    })
  }
}
