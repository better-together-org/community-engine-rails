import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "citationSelect",
    "locatorInput",
    "quotedTextInput",
    "originFilter",
    "recordTypeFilter",
    "roleFilter",
    "contributionTypeFilter",
    "group",
    "githubGroups",
    "githubStatus",
    "githubLoadButton"
  ]
  static values = { githubUrl: String, githubImportUrl: String, githubLoaded: Boolean }

  chooseCitation(event) {
    event.preventDefault()

    const button = event.currentTarget
    if (this.hasCitationSelectTarget) {
      this.citationSelectTarget.value = button.dataset.citationId
      this.citationSelectTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    if (this.hasLocatorInputTarget && !this.locatorInputTarget.value.trim() && button.dataset.locator) {
      this.locatorInputTarget.value = button.dataset.locator
    }

    if (this.hasQuotedTextInputTarget && !this.quotedTextInputTarget.value.trim() && button.dataset.excerpt) {
      this.quotedTextInputTarget.value = button.dataset.excerpt
    }
  }

  filter() {
    const origin = this.hasOriginFilterTarget ? this.originFilterTarget.value : ""
    const recordType = this.hasRecordTypeFilterTarget ? this.recordTypeFilterTarget.value : ""
    const role = this.hasRoleFilterTarget ? this.roleFilterTarget.value : ""
    const contributionType = this.hasContributionTypeFilterTarget ? this.contributionTypeFilterTarget.value : ""

    this.groupTargets.forEach((group) => {
      const matches =
        this.matchesFilter(group.dataset.origin, origin) &&
        this.matchesFilter(group.dataset.recordType, recordType) &&
        this.matchesFilter(group.dataset.role, role) &&
        this.matchesFilter(group.dataset.contributionType, contributionType)

      group.classList.toggle("d-none", !matches)
    })
  }

  matchesFilter(candidate, selectedValue) {
    return true if !selectedValue

    return candidate === selectedValue
  }

  async loadGithubSources(event) {
    if (event) event.preventDefault()
    if (!this.hasGithubUrlValue || this.githubLoadedValue || !this.hasGithubGroupsTarget) return

    this.githubStatusTarget.textContent = "Loading GitHub evidence..."
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
      this.githubStatusTarget.textContent = payload.groups?.length ? "GitHub evidence loaded." : "No linked GitHub sources found."
    } catch (_error) {
      this.githubStatusTarget.textContent = "Unable to load GitHub evidence right now."
    } finally {
      if (this.hasGithubLoadButtonTarget) this.githubLoadButtonTarget.disabled = false
    }
  }

  async importAndUseGithubCitation(event) {
    event.preventDefault()
    if (!this.hasGithubImportUrlValue) return

    const response = await fetch(this.githubImportUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin",
      body: JSON.stringify({
        source: {
          reference_key: event.currentTarget.dataset.referenceKey,
          source_kind: event.currentTarget.dataset.sourceKind,
          title: event.currentTarget.dataset.title,
          source_author: event.currentTarget.dataset.sourceAuthor,
          publisher: event.currentTarget.dataset.publisher,
          source_url: event.currentTarget.dataset.sourceUrl,
          locator: event.currentTarget.dataset.locator,
          excerpt: event.currentTarget.dataset.excerpt,
          published_on: event.currentTarget.dataset.publishedOn,
          accessed_on: event.currentTarget.dataset.accessedOn,
          metadata: this.parseMetadata(event.currentTarget.dataset.metadata)
        }
      })
    })

    if (!response.ok) return

    const payload = await response.json()
    const citation = payload.citation
    if (!citation) return

    this.ensureCitationOption(citation.id, `${citation.reference_key}: ${citation.title}`)
    this.citationSelectTarget.value = citation.id
    this.citationSelectTarget.dispatchEvent(new Event("change", { bubbles: true }))

    if (this.hasLocatorInputTarget && !this.locatorInputTarget.value.trim() && citation.locator) {
      this.locatorInputTarget.value = citation.locator
    }

    if (this.hasQuotedTextInputTarget && !this.quotedTextInputTarget.value.trim() && citation.excerpt) {
      this.quotedTextInputTarget.value = citation.excerpt
    }
  }

  ensureCitationOption(value, label) {
    if (!this.hasCitationSelectTarget) return
    const existingOption = Array.from(this.citationSelectTarget.options).find((option) => option.value === String(value))
    if (existingOption) return

    this.citationSelectTarget.add(new Option(label, value))
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
      this.githubGroupsTarget.innerHTML = '<p class="small text-muted mb-0">No linked GitHub evidence is available yet.</p>'
      return
    }

    this.githubGroupsTarget.innerHTML = groups.map((group) => {
      const citations = (group.citations || []).map((citation) => `
        <div class="border rounded p-2 bg-light-subtle">
          <div class="d-flex justify-content-between gap-2 align-items-start">
            <div>
              <div class="fw-semibold">${this.escapeHtml(citation.reference_key)}: ${this.escapeHtml(citation.title)}</div>
              <div class="small text-muted">${this.escapeHtml([this.humanize(citation.source_kind), citation.source_author, citation.publisher].filter(Boolean).join(" | "))}</div>
            </div>
            <button
              type="button"
              class="btn btn-sm btn-outline-primary"
              data-action="click->better_together--evidence-browser#importAndUseGithubCitation"
              data-reference-key="${this.escapeHtml(citation.reference_key)}"
              data-source-kind="${this.escapeHtml(citation.source_kind)}"
              data-title="${this.escapeHtml(citation.title)}"
              data-source-author="${this.escapeHtml(citation.source_author || "")}"
              data-publisher="${this.escapeHtml(citation.publisher || "")}"
              data-source-url="${this.escapeHtml(citation.source_url || "")}"
              data-locator="${this.escapeHtml(citation.locator || "")}"
              data-excerpt="${this.escapeHtml(citation.excerpt || "")}"
              data-published-on="${this.escapeHtml(citation.published_on || "")}"
              data-accessed-on="${this.escapeHtml(citation.accessed_on || "")}"
              data-metadata="${this.escapeHtml(JSON.stringify(citation.metadata || {}))}">
              Import and Use Citation
            </button>
          </div>
        </div>
      `).join("")

      return `
        <div class="mb-3">
          <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
            <h5 class="h6 mb-0">${this.escapeHtml(group.label)}</h5>
            <span class="badge text-bg-secondary">GitHub</span>
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

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
