import { Controller } from '@hotwired/stimulus'

// This controller is intentionally minimal; Turbo Streams handle most updates.
export default class extends Controller {
  static targets = [ 'list', 'form' ]
  static values = { checklistId: String }

  get locale() {
    try { return (window.I18n && I18n.locale) || document.documentElement.lang || 'en' } catch (e) { return 'en' }
  }

  get routeScopePath() {
    try { return (window.BetterTogether && BetterTogether.route_scope_path) || this.element.dataset.routeScopePath || '' } catch (e) { return '' }
  }

  connect() {
    // Accessible live region for announcements
    this.liveRegion = document.getElementById('a11y-live-region') || this.createLiveRegion()
  this._dragSrc = null
  // debug flag via data-bt-debug="true" on the controller element
  try { this._debug = this.element.dataset.btDebug === 'true' } catch (e) { this._debug = false }
    // lightweight logger (console.log is visible in Firefox even when debug level is filtered)
    this._log = (...args) => { try { if (this._debug) console.log(...args) } catch (e) {} }
    if (this._debug) this._log('bt:controller-connected', { id: this.element.id || null })
  this.addKeyboardHandlers()
  this.addDragHandlers()
  // Ensure disabled-checkbox tooltips are initialized even when drag handlers are skipped
  try { this._initTooltips() } catch (e) {}
  // Observe subtree changes on the controller element so we reattach handlers when Turbo replaces the inner list
  try {
      this._listObserver = new MutationObserver(() => {
        this.addKeyboardHandlers()
        this.addDragHandlers()
        this.updateMoveButtons()
      })
    this._listObserver.observe(this.element, { childList: true, subtree: true })
  } catch (e) {}
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
      // avoid attaching duplicate listeners
      if (li.dataset.kbAttached) return
      const handler = (e) => {
        if (e.key === 'ArrowUp' && e.ctrlKey) {
          e.preventDefault()
          li.querySelector('.keyboard-move-up')?.click()
        } else if (e.key === 'ArrowDown' && e.ctrlKey) {
          e.preventDefault()
          li.querySelector('.keyboard-move-down')?.click()
        }
      }
      li.addEventListener('keydown', handler)
      li.dataset.kbAttached = '1'
    })
  }

  updateMoveButtons() {
    if (!this.hasListTarget) return
    const items = Array.from(this.listTarget.querySelectorAll('li'))
    if (!items.length) return

    items.forEach((li, idx) => {
      const up = li.querySelector('.keyboard-move-up')
      const down = li.querySelector('.keyboard-move-down')

      // First item: disable up
      if (up) {
        if (idx === 0) {
          // mark disabled visually and for assistive tech
          up.classList.add('disabled')
          up.setAttribute('aria-disabled', 'true')
          if (up.tagName === 'A') up.setAttribute('tabindex', '-1')
          else up.setAttribute('disabled', 'disabled')
        } else {
          up.classList.remove('disabled')
          up.removeAttribute('aria-disabled')
          if (up.tagName === 'A') up.removeAttribute('tabindex')
          else up.removeAttribute('disabled')
        }
      }

      // Last item: disable down
      if (down) {
        if (idx === items.length - 1) {
          down.classList.add('disabled')
          down.setAttribute('aria-disabled', 'true')
          if (down.tagName === 'A') down.setAttribute('tabindex', '-1')
          else down.setAttribute('disabled', 'disabled')
        } else {
          down.classList.remove('disabled')
          down.removeAttribute('aria-disabled')
          if (down.tagName === 'A') down.removeAttribute('tabindex')
          else down.removeAttribute('disabled')
        }
      }
    })
  }

  addDragHandlers() {
    if (!this.hasListTarget) return
    // Skip attaching drag handlers if the server declared the user cannot update this checklist
    try {
      const canUpdate = this.listTarget.dataset.canUpdate === 'true'
      if (!canUpdate) return
    } catch (e) {}

    const list = this.listTarget || this.element.querySelector('[data-better_together--checklist-items-target="list"]')
    const controller = this

    // Delegated dragover on the list: compute nearest LI and show insertion indicator
    if (!list.dataset.dragOverAttached) {
      this._lastDropTarget = null
      list.addEventListener('dragover', (e) => {
        e.preventDefault()
        try { e.dataTransfer.dropEffect = 'move' } catch (er) {}
        try {
          const li = e.target.closest('li')
          const dragSrc = controller._dragSrc
            controller._log('bt:dragover', { liId: li?.id, dragSrcId: dragSrc?.id, clientY: e.clientY })
          if (!li || !dragSrc || li === dragSrc) {
            if (controller._lastDropTarget) {
              controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
              controller._lastDropTarget = null
            }
            return
          }
          const rect = li.getBoundingClientRect()
          const before = (e.clientY - rect.top) < (rect.height / 2)
          // Always clear any existing insertion indicators on this LI first so we
          // don't end up with both top and bottom indicators active at once when
          // the pointer crosses the midpoint within the same element.
          li.classList.remove('bt-drop-before', 'bt-drop-after')

          // If this potential drop would be a no-op (placing the dragged item
          // back into its current position), don't show an insertion indicator.
          try {
            const dragId = controller._dragSrc && controller._dragSrc.dataset && controller._dragSrc.dataset.id
            if (dragId) {
              const allIds = Array.from(list.querySelectorAll('li')).map((node) => node.dataset.id)
              // Build array as if the drag source were removed
              const without = allIds.filter((id) => id !== dragId)
              const targetId = li.dataset.id
              const baseIndex = without.indexOf(targetId)
              if (baseIndex >= 0) {
                const intendedIndex = before ? baseIndex : (baseIndex + 1)
                const simulated = [...without.slice(0, intendedIndex), dragId, ...without.slice(intendedIndex)]
                // If simulated equals the current order, it's a no-op; skip indicator
                if (simulated.length === allIds.length && simulated.join(',') === allIds.join(',')) {
                  if (controller._lastDropTarget && controller._lastDropTarget !== li) {
                    controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
                  }
                  controller._lastDropTarget = null
                  return
                }
              }
            }
          } catch (err) { /* non-fatal; fall back to showing indicator */ }

          if (controller._lastDropTarget && controller._lastDropTarget !== li) {
            controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
          }

          li.classList.add(before ? 'bt-drop-before' : 'bt-drop-after')
          controller._lastDropTarget = li
        } catch (err) { /* non-fatal */ }
      })

      // cleanup on drag end outside of a drop
      document.addEventListener('dragend', () => {
        try {
          if (controller._lastDropTarget) {
            controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
            controller._lastDropTarget = null
          }
        } catch (e) {}
  try { if (controller._dragSrc) controller._dragSrc.classList.remove('dragging') } catch (e) {}
  try { if (controller._dragImage) { controller._dragImage.remove(); controller._dragImage = null } } catch (e) {}
          // Destroy any tooltip instance created on the handle to avoid leaks
          try {
            Array.from(list.querySelectorAll('.drag-handle')).forEach((h) => {
              try { if (h._btTooltip && typeof h._btTooltip.dispose === 'function') h._btTooltip.dispose() } catch (er) {}
              try { delete h._btTooltip } catch (er) {}
            })
            Array.from(list.querySelectorAll('.checklist-checkbox')).forEach((cb) => {
              try { if (cb._btTooltipLock && typeof cb._btTooltipLock.dispose === 'function') cb._btTooltipLock.dispose() } catch (er) {}
              try { delete cb._btTooltipLock } catch (er) {}
            })
          } catch (er) {}
          controller._log('bt:dragend')
      })

      list.dataset.dragOverAttached = '1'
    }

  // Attach per-LI handlers (drop, make handle draggable). Re-run safe: skip already-attached LIs.
    Array.from(list.querySelectorAll('li')).forEach((el) => {
      if (el.dataset.dragAttached) return
      try { el.setAttribute('draggable', 'false') } catch (e) {}

      const handle = el.querySelector('.drag-handle')
      if (handle) {
  // Note: tooltip instances are also created centrally by _initTooltips
        if (!handle.hasAttribute('tabindex')) handle.setAttribute('tabindex', '0')
        try { handle.setAttribute('draggable', 'true') } catch (e) {}

        handle.addEventListener('dragstart', (e) => {
          controller._dragSrc = el
          e.dataTransfer.effectAllowed = 'move'
          try { e.dataTransfer.setData('text/plain', el.id) } catch (er) {}
          // Try native setDragImage first
          try { controller._setDragImage(el, e) } catch (er) {}
          // Add a pointer-following ghost as a cross-browser fallback (Firefox may ignore setDragImage)
          try { controller._createPointerGhost(el, e) } catch (er) {}
          el.classList.add('dragging')
            controller._log('bt:dragstart', { id: el.id })
        })

        handle.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            controller._dragSrc = el
            el.classList.add('dragging')
            try { if (controller.liveRegion) controller.liveRegion.textContent = 'Move started' } catch (er) {}
          }
        })
      }

      // drop on LI
      el.addEventListener('drop', (e) => {
        e.preventDefault()
        const dragSrc = controller._dragSrc
          controller._log('bt:drop', { targetId: el.id, dragSrcId: dragSrc?.id })
        if (!dragSrc || dragSrc === el) return
        const rect = el.getBoundingClientRect()
        const before = (e.clientY - rect.top) < (rect.height / 2)
        if (before) el.parentNode.insertBefore(dragSrc, el)
        else el.parentNode.insertBefore(dragSrc, el.nextSibling || null)

        // remove any temporary insertion indicators
        try { el.classList.remove('bt-drop-before', 'bt-drop-after') } catch (e) {}
        try { if (controller._lastDropTarget) controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after') } catch (e) {}
        controller._lastDropTarget = null
        // Visual highlight: briefly mark the moved item to draw attention
        try { dragSrc.classList.add('moved-item') } catch (e) {}
        try { dragSrc.dataset.moved = '1' } catch (e) {}
        // Schedule removal of moved highlight after the CSS animation completes
        try { setTimeout(() => { try { dragSrc.classList.remove('moved-item'); delete dragSrc.dataset.moved } catch (e) {} }, 1000) } catch (e) {}

        // Mark updating state immediately for smoother transitions and then POST the new order
        try { controller.markUpdating(true) } catch (e) {}
        controller.postReorder()

        // Cleanup local drag state
        try { dragSrc.classList.remove('dragging') } catch (e) {}
        controller._dragSrc = null
  // Re-initialize tooltips after the drop so handles show tooltips again
  try { controller._initTooltips() } catch (e) {}
  controller._log('bt:drop-complete')
      })

      el.dataset.dragAttached = '1'
    })

    // Ensure tooltips exist for any handles (useful when we disposed them during prior drag)
    try { this._initTooltips(list) } catch (e) {}
  }

  // Initialize (or re-initialize) Bootstrap tooltip instances for all drag handles
  _initTooltips(root) {
    try {
      const container = root || (this.hasListTarget ? this.listTarget : (this.element.querySelector('[data-better_together--checklist-items-target="list"]')))
      if (!container) return
      Array.from(container.querySelectorAll('.drag-handle')).forEach((h) => {
        try { if (h._btTooltip && typeof h._btTooltip.dispose === 'function') h._btTooltip.dispose() } catch (er) {}
        try {
          if (window.bootstrap && typeof window.bootstrap.Tooltip === 'function') {
            h._btTooltip = new window.bootstrap.Tooltip(h)
          }
        } catch (er) {}
      })
      // Also initialize tooltips for disabled checklist-checkboxes (lock glyph explanation)
      Array.from(container.querySelectorAll('.checklist-checkbox[aria-disabled="true"]')).forEach((cb) => {
        try { if (cb._btTooltipLock && typeof cb._btTooltipLock.dispose === 'function') cb._btTooltipLock.dispose() } catch (er) {}
        try {
          // Provide a helpful title (prefer JS I18n if available)
          const defaultMsg = 'Sign in to mark this item complete'
          const title = (window.I18n && typeof window.I18n.t === 'function') ? window.I18n.t('better_together.checklist_items.sign_in_to_toggle', { defaultValue: defaultMsg }) : defaultMsg
          // Ensure title attribute exists for Bootstrap Tooltip
          try { cb.setAttribute('title', title) } catch (er) {}
          if (window.bootstrap && typeof window.bootstrap.Tooltip === 'function') {
            cb._btTooltipLock = new window.bootstrap.Tooltip(cb, { placement: 'right' })
          }
        } catch (er) {}
      })
    } catch (e) {}
  }

  disconnect() {
  try { if (this._listObserver) this._listObserver.disconnect() } catch (e) {}
  try { this._dragSrc = null } catch (e) {}
  // Dispose tooltip instances created earlier
  try {
    const list = this.hasListTarget ? this.listTarget : (this.element.querySelector('[data-better_together--checklist-items-target="list"]'))
    if (list) {
      Array.from(list.querySelectorAll('.drag-handle')).forEach((h) => {
        try { if (h._btTooltip && typeof h._btTooltip.dispose === 'function') h._btTooltip.dispose() } catch (er) {}
        try { delete h._btTooltip } catch (er) {}
      })
      Array.from(list.querySelectorAll('.checklist-checkbox')).forEach((cb) => {
        try { if (cb._btTooltipLock && typeof cb._btTooltipLock.dispose === 'function') cb._btTooltipLock.dispose() } catch (er) {}
        try { delete cb._btTooltipLock } catch (er) {}
      })
    }
  } catch (er) {}
  }

  postReorder() {
    const ids = Array.from(this.listTarget.querySelectorAll('li[data-id]')).map((li) => li.dataset.id)
    const url = `/${this.locale}/${this.routeScopePath}/checklists/${this.checklistIdValue}/checklist_items/reorder`
    const csrfMeta = document.querySelector('meta[name=csrf-token]')
    const csrf = csrfMeta && csrfMeta.content ? csrfMeta.content : ''
    // Add a small visual transition: mark wrapper as updating so CSS can fade the UL
    this.markUpdating(true)
    fetch(url, {
      method: 'PATCH',
      // Request JSON so the server can respond with 204 No Content when the client has
      // already applied the DOM move locally. This prevents an unnecessary Turbo Stream
      // replacement of the list which causes flicker.
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'X-CSRF-Token': csrf },
      body: JSON.stringify({ ordered_ids: ids })
    }).then((resp) => resp.text()).then((text) => {
      if (this._debug) console.debug('bt:postReorder', { url, ids, response: text ? text.slice(0,200) : null })
      // If server returned Turbo Stream HTML, ask Turbo to apply it
      try {
        if (text && window.Turbo && typeof window.Turbo.renderStreamMessage === 'function') {
          window.Turbo.renderStreamMessage(text)
        }
      } catch (e) {}

      // Allow CSS transition to finish before clearing updating state
      setTimeout(() => {
        this.markUpdating(false)
        try { this.updateMoveButtons() } catch (e) {}
      }, 220)

      // Announce completion to screen readers if live region exists
      if (this.liveRegion) this.liveRegion.textContent = 'Items reordered'
    }).catch(() => {
      // Ensure we clear updating class on error
      setTimeout(() => {
        this.markUpdating(false)
        try { this.updateMoveButtons() } catch (e) {}
      }, 220)
    })
  }

  // Create a cloned element to serve as the drag image so the whole LI is visible while dragging
  _setDragImage(el, event) {
    try {
      const clone = el.cloneNode(true)
      const rect = el.getBoundingClientRect()
      clone.style.position = 'absolute'
      // place clone at the same on-screen position as the original element so setDragImage can pick it up
      clone.style.top = `${rect.top + window.scrollY}px`
      clone.style.left = `${rect.left + window.scrollX}px`
      clone.style.width = `${rect.width}px`
      clone.style.zIndex = '10000'
      clone.classList.add('bt-drag-image')
      // ensure it's visible for the browser to capture as drag image
      clone.style.opacity = '0.99'
      document.body.appendChild(clone)
      // Position the drag image offset to align pointer with the original element
      if (event.dataTransfer && typeof event.dataTransfer.setDragImage === 'function') {
        const offsetX = Math.max(10, Math.round(event.clientX - rect.left))
        const offsetY = Math.max(10, Math.round(event.clientY - rect.top))
        event.dataTransfer.setDragImage(clone, offsetX, offsetY)
      }

      // store a reference for cleanup
      try { this._dragImage = clone } catch (e) {}

      // Ensure dragend removes the clone and any dragging class
      const cleanup = () => {
        try { if (this._dragImage) { this._dragImage.remove(); this._dragImage = null } } catch (e) {}
        try { el.classList.remove('dragging') } catch (e) {}
        try { if (event && event.target) event.target.removeEventListener('dragend', cleanup) } catch (e) {}
        try { document.removeEventListener('dragend', cleanup) } catch (e) {}
      }
      // Attach cleanup to the element that started the drag (event.target) and to document as a fallback
      try { if (event && event.target) event.target.addEventListener('dragend', cleanup) } catch (e) {}
      try { document.addEventListener('dragend', cleanup) } catch (e) {}
    } catch (e) {}
  }

  // Fallback ghost for browsers (like Firefox) that ignore setDragImage for some elements.


  markUpdating(state = true) {
    try {
      const wrapper = this.hasListTarget ? this.listTarget : (this.element.querySelector('[data-better_together--checklist-items-target="list"]'))
      if (!wrapper) return
      if (state) wrapper.classList.add('is-updating')
      else wrapper.classList.remove('is-updating')
    } catch (e) {}
  }
}
