import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['container', 'template', 'jsonField', 'row']
  static values = { keys: Array }

  connect() {
    // Parse the current JSON value and render rows for each item
    this.parseAndRenderRows()
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

  // Drag-and-drop handlers
  rowDragStart(event) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', event.target.innerHTML)
    this.draggedRow = event.currentTarget
    this.draggedRow.classList.add('opacity-50')
  }

  rowDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'

    const row = event.target.closest('[data-better_together--json-array-rows-target="row"]')
    if (!row || row === this.draggedRow) {
      if (this.lastDropTarget && this.lastDropTarget !== row) {
        this.lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
        this.lastDropTarget = null
      }
      return
    }

    // Determine if dropping before or after based on cursor position
    const rect = row.getBoundingClientRect()
    const before = (event.clientY - rect.top) < (rect.height / 2)

    // Clear previous indicator
    if (this.lastDropTarget && this.lastDropTarget !== row) {
      this.lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
    }

    // Add new indicator
    row.classList.remove('bt-drop-before', 'bt-drop-after')
    row.classList.add(before ? 'bt-drop-before' : 'bt-drop-after')
    this.lastDropTarget = row
  }

  rowDragLeave(event) {
    const row = event.target.closest('[data-better_together--json-array-rows-target="row"]')
    if (row) {
      row.classList.remove('bt-drop-before', 'bt-drop-after')
    }
  }

  rowDrop(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.draggedRow) return

    const dropTarget = event.target.closest('[data-better_together--json-array-rows-target="row"]')
    if (!dropTarget || dropTarget === this.draggedRow) return

    // Determine drop position
    const rect = dropTarget.getBoundingClientRect()
    const before = (event.clientY - rect.top) < (rect.height / 2)

    // Perform the reorder
    if (before) {
      this.containerTarget.insertBefore(this.draggedRow, dropTarget)
    } else {
      this.containerTarget.insertBefore(this.draggedRow, dropTarget.nextSibling)
    }

    this.syncJson()
  }

  rowDragEnd(event) {
    event.preventDefault()
    if (this.draggedRow) {
      this.draggedRow.classList.remove('opacity-50')
      this.draggedRow = null
    }

    // Clean up drop indicators
    if (this.lastDropTarget) {
      this.lastDropTarget.classList.remove('bt-drop-before', 'bt-drop-after')
      this.lastDropTarget = null
    }
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
