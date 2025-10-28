import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "input"]
  static values = {
    searchUrl: String,
    searchDelay: { type: Number, default: 300 }
  }

  connect() {
    this.setupPersonSearch()
  }

  setupPersonSearch() {
    const select = this.selectTarget

    // Convert select to a searchable input
    this.createSearchInput(select)

    // Hide the original select
    select.style.display = 'none'
  }

  createSearchInput(select) {
    const searchContainer = select.parentElement

    // Create search input
    const searchInput = document.createElement('input')
    searchInput.type = 'text'
    searchInput.className = 'form-control person-search-input'
    searchInput.placeholder = select.options[0]?.text || 'Search for people...'
    searchInput.setAttribute('data-person-search-target', 'input')

    // Create results dropdown
    const resultsDropdown = document.createElement('div')
    resultsDropdown.className = 'person-search-results'
    resultsDropdown.style.cssText = `
      position: absolute;
      top: 100%;
      left: 0;
      right: 0;
      background: white;
      border: 1px solid #ced4da;
      border-top: none;
      border-radius: 0 0 0.375rem 0.375rem;
      max-height: 200px;
      overflow-y: auto;
      z-index: 1000;
      display: none;
    `

    // Insert elements
    searchContainer.style.position = 'relative'
    searchContainer.insertBefore(searchInput, select)
    searchContainer.appendChild(resultsDropdown)

    // Setup event listeners
    let searchTimeout
    searchInput.addEventListener('input', (e) => {
      clearTimeout(searchTimeout)
      searchTimeout = setTimeout(() => {
        this.performSearch(e.target.value, resultsDropdown, select)
      }, this.searchDelayValue)
    })

    searchInput.addEventListener('focus', () => {
      if (searchInput.value) {
        this.performSearch(searchInput.value, resultsDropdown, select)
      }
    })

    // Hide dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (!searchContainer.contains(e.target)) {
        resultsDropdown.style.display = 'none'
      }
    })
  }

  async performSearch(query, resultsDropdown, select) {
    if (query.length < 2) {
      resultsDropdown.style.display = 'none'
      return
    }

    try {
      const response = await fetch(`${this.searchUrlValue}?search=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) throw new Error('Search failed')

      const people = await response.json()
      this.displayResults(people, resultsDropdown, select)
    } catch (error) {
      console.error('Person search error:', error)
      resultsDropdown.innerHTML = '<div class="p-2 text-danger">Search failed</div>'
      resultsDropdown.style.display = 'block'
    }
  }

  displayResults(people, resultsDropdown, select) {
    if (people.length === 0) {
      resultsDropdown.innerHTML = '<div class="p-2 text-muted">No people found</div>'
      resultsDropdown.style.display = 'block'
      return
    }

    const resultsHtml = people.map(person => `
      <div class="person-result p-2 border-bottom"
           style="cursor: pointer; display: flex; align-items: center;"
           data-person-id="${person.id}"
           data-person-name="${person.name}">
        <div class="me-2" style="width: 32px; height: 32px; background-color: #dee2e6; border-radius: 50%; display: flex; align-items: center; justify-content: center;">
          <i class="fas fa-user text-muted"></i>
        </div>
        <div>
          <div class="fw-medium">${person.name}</div>
          <small class="text-muted">@${person.slug}</small>
        </div>
      </div>
    `).join('')

    resultsDropdown.innerHTML = resultsHtml
    resultsDropdown.style.display = 'block'

    // Add click handlers to results
    resultsDropdown.querySelectorAll('.person-result').forEach(result => {
      result.addEventListener('click', () => {
        this.selectPerson(result, select)
        resultsDropdown.style.display = 'none'
      })
    })
  }

  selectPerson(resultElement, select) {
    const personId = resultElement.dataset.personId
    const personName = resultElement.dataset.personName

    // Update the hidden select
    select.innerHTML = `<option value="${personId}" selected>${personName}</option>`
    select.value = personId

    // Update the search input
    const searchInput = this.inputTarget
    searchInput.value = personName

    // Trigger change event for form handling
    select.dispatchEvent(new Event('change', { bubbles: true }))
  }
}
