import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="better_together--event-hover-card"
export default class extends Controller {
  static values = {
    eventId: String,
    eventUrl: String
  }

  connect() {
    this.popover = null
    this.isPopoverVisible = false
    this.isNavigating = false
    this.showTimeout = null
    this.hideTimeout = null
    this.eventCardContent = null
    this.contentLoaded = false
    
    // Pre-fetch the event card content immediately
    this.prefetchEventCard()
    this.setupPopover()
  }

  disconnect() {
    this.cleanupPopover()
  }

  async setupPopover() {
    // Setup popover with initial loading content
    this.popover = new bootstrap.Popover(this.element, {
      content: this.getPopoverContent(),
      html: true,
      placement: 'auto',
      fallbackPlacements: ['top', 'bottom', 'right', 'left'],
      trigger: 'manual', // Use manual trigger for better control
      delay: { show: 0, hide: 100 }, // No delay for show since content is pre-fetched
      customClass: 'event-hover-card-popover',
      sanitize: false,
      container: 'body', // Render in body to avoid positioning issues
      boundary: 'viewport',
      offset: [0, 8] // Add some offset from the trigger element
    })

    // Setup manual hover events
    this.setupHoverEvents()
  }

  getPopoverContent() {
    if (this.contentLoaded && this.eventCardContent) {
      return this.eventCardContent
    } else {
      return '<div class="text-center py-3"><div class="spinner-border spinner-border-sm" role="status"><span class="visually-hidden">Loading...</span></div><div class="small text-muted mt-2">Loading event details...</div></div>'
    }
  }

  async prefetchEventCard() {
    const requestUrl = `${this.eventUrlValue}?format=card`

    try {
      const response = await fetch(`${this.eventUrlValue}?format=card`, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest',
          'X-Card-Request': 'true'
        }
      })

      if (response.ok) {
        const cardHtml = await response.text()
        this.eventCardContent = cardHtml
        this.contentLoaded = true
        
        // Update popover content if it exists and is already shown
        if (this.popover && this.isPopoverVisible) {
          this.updatePopoverContent(cardHtml)
        }
      } else {
        this.eventCardContent = this.generateFallbackContent()
        this.contentLoaded = true
      }
    } catch (error) {
      console.error('Error pre-fetching event card:', error)
      this.eventCardContent = this.generateFallbackContent()
      this.contentLoaded = true
    }
  }

  setupHoverEvents() {
    const showPopover = () => {
      // Don't show popover if we're navigating
      if (this.isNavigating) return
      
      clearTimeout(this.hideTimeout)
      this.showTimeout = setTimeout(() => {
        if (!this.isNavigating) {
          this.isPopoverVisible = true
          
          // Update content if it's been loaded since popover creation
          if (this.contentLoaded) {
            this.popover.setContent({
              '.popover-body': this.eventCardContent
            })
          }
          
          this.popover.show()
        }
      }, 300) // Reduced delay since content is pre-fetched
    }

    const hidePopover = () => {
      clearTimeout(this.showTimeout)
      
      // Don't hide if we're navigating (cleanup will handle it)
      if (this.isNavigating) return
      
      this.hideTimeout = setTimeout(() => {
        if (!this.isNavigating) {
          this.isPopoverVisible = false
          this.popover.hide()
        }
      }, 100)
    }

    // Show on hover
    this.element.addEventListener('mouseenter', showPopover)
    this.element.addEventListener('focus', showPopover)

    // Hide when leaving the trigger element
    this.element.addEventListener('mouseleave', hidePopover)
    this.element.addEventListener('blur', hidePopover)

    // Keep popover open when hovering over it
    this.element.addEventListener('shown.bs.popover', () => {
      const popoverElement = document.querySelector('.event-hover-card-popover')
      if (popoverElement) {
        popoverElement.addEventListener('mouseenter', () => {
          clearTimeout(this.hideTimeout)
        })
        popoverElement.addEventListener('mouseleave', hidePopover)
        
        // Intercept link clicks within the popover
        this.setupPopoverLinkInterception(popoverElement)
      }
    })

    // Handle popover hiding
    this.element.addEventListener('hidden.bs.popover', () => {
      this.isPopoverVisible = false
    })
  }

  setupPopoverLinkInterception(popoverElement) {
    // Find all links within the popover
    const links = popoverElement.querySelectorAll('a[href]')
    
    links.forEach(link => {
      link.addEventListener('click', (event) => {
        // Set a flag to prevent any hover events from interfering
        this.isNavigating = true
        
        // Hide the popover gracefully without disposing immediately
        if (this.popover) {
          this.popover.hide()
        }
        
        // Schedule cleanup after Bootstrap's hide animation completes
        setTimeout(() => {
          this.safeCleanup()
        }, 200)
        
        // Note: We don't preventDefault() here to allow normal navigation
      })
    })
  }

  safeCleanup() {
    // Clear all timeouts
    if (this.showTimeout) clearTimeout(this.showTimeout)
    if (this.hideTimeout) clearTimeout(this.hideTimeout)
    
    // Reset state
    this.isPopoverVisible = false
    this.isNavigating = false
    
    // Only dispose if popover still exists and is not in transition
    if (this.popover) {
      try {
        this.popover.dispose()
        this.popover = null
      } catch (error) {
        console.warn('Error disposing popover:', error)
        this.popover = null
      }
    }
    
    // Clean up any remaining popover DOM elements
    const remainingPopovers = document.querySelectorAll('.event-hover-card-popover')
    remainingPopovers.forEach(popover => {
      try {
        popover.remove()
      } catch (error) {
        console.warn('Error removing popover element:', error)
      }
    })
  }

  cleanupPopover() {
    // Clear all timeouts
    if (this.showTimeout) clearTimeout(this.showTimeout)
    if (this.hideTimeout) clearTimeout(this.hideTimeout)
    
    // Reset state
    this.isPopoverVisible = false
    
    // Hide and dispose popover safely
    if (this.popover) {
      try {
        this.popover.hide()
        // Delay disposal to allow hide animation to complete
        setTimeout(() => {
          if (this.popover) {
            try {
              this.popover.dispose()
              this.popover = null
            } catch (error) {
              console.warn('Error disposing popover:', error)
              this.popover = null
            }
          }
        }, 150)
      } catch (error) {
        console.warn('Error hiding popover:', error)
        this.popover = null
      }
    }
    
    // Clean up any remaining popover DOM elements
    setTimeout(() => {
      const remainingPopovers = document.querySelectorAll('.event-hover-card-popover')
      remainingPopovers.forEach(popover => {
        try {
          popover.remove()
        } catch (error) {
          console.warn('Error removing popover element:', error)
        }
      })
    }, 200)
  }

  updatePopoverContent(content) {
    if (this.popover) {
      this.popover.setContent({
        '.popover-body': content
      })
    }
  }

  generateFallbackContent() {
    return `
      <div class="event-hover-card">
        <div class="text-center">
          <i class="fas fa-exclamation-triangle text-warning"></i>
          <p class="mb-0 small">Unable to load event details</p>
          <a href="${this.eventUrlValue}" class="btn btn-sm btn-outline-primary mt-2">
            <i class="fas fa-eye me-1"></i> View Event
          </a>
        </div>
      </div>
    `
  }
}
