import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["citationFields"]

  importCitation(event) {
    event.preventDefault()

    const source = event.currentTarget.dataset
    const target = this.firstAvailableCitationFields()
    if (!target) return

    this.populateField(target, "reference_key", source.referenceKey)
    this.populateField(target, "source_kind", source.sourceKind)
    this.populateField(target, "title", source.title)
    this.populateField(target, "source_author", source.sourceAuthor)
    this.populateField(target, "publisher", source.publisher)
    this.populateField(target, "source_url", source.sourceUrl)
    this.populateField(target, "locator", source.locator)
    this.populateField(target, "excerpt", source.excerpt)
  }

  firstAvailableCitationFields() {
    return this.citationFieldsTargets.find((container) => {
      const title = this.readField(container, "title")
      const referenceKey = this.readField(container, "reference_key")
      return !title && !referenceKey
    }) || this.citationFieldsTargets[0]
  }

  populateField(container, fieldName, value) {
    if (!value) return

    const field = container.querySelector(`[data-field-name="${fieldName}"]`)
    if (!field) return

    field.value = value
    field.dispatchEvent(new Event("input", { bubbles: true }))
    field.dispatchEvent(new Event("change", { bubbles: true }))
  }

  readField(container, fieldName) {
    return container.querySelector(`[data-field-name="${fieldName}"]`)?.value?.trim()
  }
}
