import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["citationFields", "githubGroups", "githubLoadButton", "githubPanel", "githubStatus"]
  static values = { githubUrl: String, githubLoaded: Boolean }

  importCitation(event) {
    event.preventDefault()

    const source = event.currentTarget.dataset
    this.importDataset(source)
  }

  async loadGithubSources(event) {
    if (event) event.preventDefault()
    if (!this.hasGithubUrlValue || this.githubLoadedValue) return
    if (!this.hasGithubGroupsTarget) return

    this.githubStatusTarget.textContent = "Loading GitHub sources..."
    if (this.hasGithubLoadButtonTarget) this.githubLoadButtonTarget.disabled = true

    try {
      const response = await fetch(this.githubUrlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error(`GitHub source load failed: ${response.status}`)

      const payload = await response.json()
      this.renderGithubGroups(payload.groups || [])
      this.githubLoadedValue = true
      this.githubStatusTarget.textContent = payload.groups?.length ? "GitHub sources loaded." : "No linked GitHub sources found."
    } catch (_error) {
      this.githubStatusTarget.textContent = "Unable to load GitHub sources right now."
    } finally {
      if (this.hasGithubLoadButtonTarget) this.githubLoadButtonTarget.disabled = false
    }
  }

  importGithubCitation(event) {
    event.preventDefault()
    this.importDataset(event.currentTarget.dataset)
  }

  importDataset(source) {
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
    this.populateField(target, "published_on", source.publishedOn)
    this.populateField(target, "accessed_on", source.accessedOn)
    this.populateMetadata(target, {
      ...this.parseMetadata(source.metadata),
      imported_from_citation_id: source.citationId,
      imported_from_reference_key: source.referenceKey,
      imported_from_record_label: source.recordLabel,
      imported_from_record_type: source.recordType
    })
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

  populateMetadata(container, values) {
    const field = container.querySelector('[data-field-name="metadata"]')
    if (!field) return

    let metadata = {}
    try {
      metadata = field.value ? JSON.parse(field.value) : {}
    } catch (_error) {
      metadata = {}
    }

    Object.entries(values).forEach(([key, value]) => {
      if (value) metadata[key] = value
    })

    field.value = JSON.stringify(metadata)
    field.dispatchEvent(new Event("input", { bubbles: true }))
    field.dispatchEvent(new Event("change", { bubbles: true }))
  }

  parseMetadata(value) {
    if (!value) return {}

    try {
      return JSON.parse(value)
    } catch (_error) {
      return {}
    }
  }

  renderGithubGroups(groups) {
    if (!this.hasGithubGroupsTarget) return

    if (!groups.length) {
      this.githubGroupsTarget.innerHTML = '<p class="small text-muted mb-0">No linked GitHub sources are available yet.</p>'
      return
    }

    this.githubGroupsTarget.innerHTML = groups.map((group) => {
      const badges = [
        group.record_type ? `<span class="badge text-bg-light border">${group.record_type}</span>` : "",
        group.contribution_role ? `<span class="badge text-bg-info">${this.humanize(group.contribution_role)}</span>` : "",
        group.contribution_type ? `<span class="badge text-bg-warning">${this.humanize(group.contribution_type)}</span>` : ""
      ].join("")

      const citations = (group.citations || []).map((citation) => {
        const metadata = JSON.stringify(citation.metadata || {})
        const locator = citation.locator ? `<div class="small mt-2"><strong>Locator:</strong> ${this.escapeHtml(citation.locator)}</div>` : ""
        const excerpt = citation.excerpt ? `<div class="small mt-1"><strong>Excerpt:</strong> ${this.escapeHtml(citation.excerpt)}</div>` : ""

        return `
          <div class="border rounded p-2 bg-light-subtle">
            <div class="d-flex justify-content-between align-items-start gap-2">
              <div>
                <div class="fw-semibold">${this.escapeHtml(citation.reference_key)}: ${this.escapeHtml(citation.title)}</div>
                <div class="small text-muted">${this.escapeHtml([this.humanize(citation.source_kind), citation.source_author, citation.publisher].filter(Boolean).join(" | "))}</div>
              </div>
              <button
                type="button"
                class="btn btn-sm btn-outline-secondary"
                data-action="click->better_together--citation-import#importGithubCitation"
                data-reference-key="${this.escapeHtml(citation.reference_key)}"
                data-record-label="${this.escapeHtml(group.label)}"
                data-record-type="${this.escapeHtml(group.record_type || "GitHub")}"
                data-title="${this.escapeHtml(citation.title)}"
                data-source-kind="${this.escapeHtml(citation.source_kind)}"
                data-source-author="${this.escapeHtml(citation.source_author || "")}"
                data-publisher="${this.escapeHtml(citation.publisher || "")}"
                data-source-url="${this.escapeHtml(citation.source_url || "")}"
                data-locator="${this.escapeHtml(citation.locator || "")}"
                data-excerpt="${this.escapeHtml(citation.excerpt || "")}"
                data-published-on="${this.escapeHtml(citation.published_on || "")}"
                data-accessed-on="${this.escapeHtml(citation.accessed_on || "")}"
                data-metadata="${this.escapeHtml(metadata)}">
                Import Citation
              </button>
            </div>
            ${locator}
            ${excerpt}
          </div>
        `
      }).join("")

      return `
        <div class="mb-3">
          <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
            <h4 class="h6 mb-0">${this.escapeHtml(group.label)}</h4>
            ${badges}
          </div>
          <div class="d-grid gap-2">${citations}</div>
        </div>
      `
    }).join("")
  }

  humanize(value) {
    return (value || "").replace(/_/g, " ").replace(/\b\w/g, (match) => match.toUpperCase())
  }

  escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }
}
