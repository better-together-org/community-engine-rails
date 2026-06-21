import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['container', 'template', 'jsonField', 'row']
  static values = { keys: Array }

  connect() {
    // Parse the current JSON value and render rows for each item
    this.parseAndRenderRows()
    this._dragSrc = null
    this.addDragHandlers()
  }

  parseAndRenderRows() {
    const jsonValue = this.jsonFieldTarget.value.trim()
    let items = []

    if (jsonValue) {
      try {
        items = JSON.parse(jsonValue)
        if (!Array.isArray(items)) items = []
      } catch (e) {
        console.error('Failed to parse JSON field:', e)
        items = []
      }
    }

    // Clear the container
    this.containerTarget.innerHTML = ''

    // If no items, create one empty row
    if (items.length === 0) {
      this.addRow()
    } else {
      // Render a row for each item
      items.forEach((item, index) => {
        this.renderRow(item, index === 0)
      })
    }

    // Set up event delegation for input changes
    this.containerTarget.addEventListener('input', () => this.syncJson())
  }

  renderRow(item = {}, focus = false) {
    const template = this.templateTarget.content.cloneNode(true)
    const row = template.querySelector('[data-better_together--json-array-rows-target="row"]')

    if (!row) {
      console.error('Template does not contain a row element with target="row"')
      return
    }

    // Populate input fields with item values
    this.keysValue.forEach((key) => {
      const input = row.querySelector(`[data-json-key="${key}"]`)
      if (input && item[key]) {
        input.value = item[key]
      }
    })

    this.containerTarget.appendChild(row)

    // Focus the first input if requested
    if (focus) {
      const firstInput = row.querySelector('input, textarea')
      if (firstInput) firstInput.focus()
    }
  }

  addRow(event) {
    if (event) event.preventDefault()
    this.renderRow({}, true)
    this.syncJson()
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.target.closest('[data-better_together--json-array-rows-target="row"]')
    if (row) {
      row.remove()
      this.syncJson()
    }
  }

  moveUp(event) {
    event.preventDefault()
    const row = event.target.closest('[data-better_together--json-array-rows-target="row"]')
    if (row && row.previousElementSibling) {
      const prev = row.previousElementSibling
      prev.parentNode.insertBefore(row, prev)
      this.syncJson()
      row.focus()
    }
  }

  moveDown(event) {
    event.preventDefault()
    const row = event.target.closest('[data-better_together--json-array-rows-target="row"]')
    if (row && row.nextElementSibling) {
      row.parentNode.insertBefore(row.nextElementSibling, row)
      this.syncJson()
      row.focus()
    }
  }

  addDragHandlers() {
    const container = this.containerTarget
    const controller = this

    // Delegated dragover on the container: show insertion indicator
    container.addEventListener('dragover', (e) => {
      e.preventDefault()
      e.dataTransfer.dropEffect = 'move'

      const row = e.target.closest('[data-better_together--json-array-rows-target="row"]')
      if (!row || !controller._dragSrc || row === controller._dragSrc) {
        if (controller._lastDropTarget && controller._lastDropTarget !== row) {
          controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
          controller._lastDropTarget = null
        }
        return
      }

      const rect = row.getBoundingClientRect()
      const before = (e.clientY - rect.top) < (rect.height / 2)

      if (controller._lastDropTarget && controller._lastDropTarget !== row) {
        controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
      }

      row.classList.remove('bt-drop-before', 'bt-drop-after')
      row.classList.add(before ? 'bt-drop-before' : 'bt-drop-after')
      controller._lastDropTarget = row
    })

    // Document-level dragend cleanup
    document.addEventListener('dragend', () => {
      if (controller._lastDropTarget) {
        controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
        controller._lastDropTarget = null
      }
      if (controller._dragSrc) {
        controller._dragSrc.classList.remove('opacity-50')
        controller._dragSrc = null
      }
    })

    // Per-row dragstart and drop handlers
    Array.from(container.querySelectorAll('[data-better_together--json-array-rows-target="row"]')).forEach((row) => {
      if (row.dataset.dragAttached) return

      const handle = row.querySelector('.drag-handle')
      if (handle) {
        handle.setAttribute('draggable', 'true')
        handle.addEventListener('dragstart', (e) => {
          controller._dragSrc = row
          e.dataTransfer.effectAllowed = 'move'
          row.classList.add('opacity-50')
        })
      }

      row.addEventListener('drop', (e) => {
        e.preventDefault()
        e.stopPropagation()

        if (!controller._dragSrc || controller._dragSrc === row) return

        const rect = row.getBoundingClientRect()
        const before = (e.clientY - rect.top) < (rect.height / 2)

        if (before) {
          container.insertBefore(controller._dragSrc, row)
        } else {
          container.insertBefore(controller._dragSrc, row.nextSibling)
        }

        try { row.classList.remove('bt-drop-before', 'bt-drop-after') } catch (er) {}
        if (controller._lastDropTarget) {
          controller._lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
          controller._lastDropTarget = null
        }

        controller.syncJson()
      })

      row.dataset.dragAttached = '1'
    })
  }

  syncJson() {
    const items = this.rowTargets.map((row) => {
      const item = {}
      this.keysValue.forEach((key) => {
        const input = row.querySelector(`[data-json-key="${key}"]`)
        if (input) {
          item[key] = input.value
        }
      })
      return item
    })

    this.jsonFieldTarget.value = JSON.stringify(items)
  }
}
