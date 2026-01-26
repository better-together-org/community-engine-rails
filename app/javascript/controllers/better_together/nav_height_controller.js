import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.updateNavHeight()
    
    // Update on resize with debouncing for performance
    this.resizeObserver = new ResizeObserver(this.debounce(() => {
      this.updateNavHeight()
    }, 100))
    
    this.resizeObserver.observe(this.element)
    
    // Also listen for Bootstrap collapse events (when nav expands/collapses)
    const collapseElements = this.element.querySelectorAll('.collapse')
    collapseElements.forEach(el => {
      el.addEventListener('shown.bs.collapse', () => this.updateNavHeight())
      el.addEventListener('hidden.bs.collapse', () => this.updateNavHeight())
    })
  }
  
  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  }
  
  updateNavHeight() {
    requestAnimationFrame(() => {
      const height = this.element.offsetHeight
      document.documentElement.style.setProperty('--nav-height', `${height}px`)
    })
  }
  
  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }
}
