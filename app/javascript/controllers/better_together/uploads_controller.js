import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "sort", "list", "item", "filterButton"]

  connect() {
    this.statusFilter = "all"
    this.updateFilterButtons()
  }

  filter() {
    this.applyFilters()
  }

  filterByStatus(event) {
    this.statusFilter = event.currentTarget.dataset.statusFilter || "all"
    this.updateFilterButtons()
    this.applyFilters()
  }

  sort() {
    const key = this.sortTarget.value
    const items = this.itemTargets.slice().sort((a, b) => {
      if (key === "name") {
        return a.dataset.name.localeCompare(b.dataset.name)
      }
      if (key === "created_at") {
        return new Date(b.dataset.createdAt) - new Date(a.dataset.createdAt)
      }
      return 0
    })
    items.forEach((item) => this.listTarget.appendChild(item))
  }

  copy(event) {
    const url = event.currentTarget.dataset.url
    navigator.clipboard?.writeText(url)
  }

  insert(event) {
    const signedId = event.currentTarget.dataset.signedId
    this.dispatch("insert", { detail: { signedId } })
  }

  applyFilters() {
    const query = this.searchTarget.value.toLowerCase()

    this.itemTargets.forEach((item) => {
      const name = item.dataset.name.toLowerCase()
      const matchesSearch = name.includes(query)
      const matchesStatus = this.statusFilter === "all" || item.dataset.reviewState === this.statusFilter

      item.classList.toggle("d-none", !(matchesSearch && matchesStatus))
    })
  }

  updateFilterButtons() {
    if (!this.hasFilterButtonTarget) return

    this.filterButtonTargets.forEach((button) => {
      const active = button.dataset.statusFilter === this.statusFilter
      button.classList.toggle("active", active)
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }
}
