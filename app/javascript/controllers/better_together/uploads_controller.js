import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "sort", "list", "item"]

  filter() {
    const query = this.searchTarget.value.toLowerCase()
    this.itemTargets.forEach((item) => {
      const name = item.dataset.name.toLowerCase()
      item.classList.toggle("d-none", !name.includes(query))
    })
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
}
