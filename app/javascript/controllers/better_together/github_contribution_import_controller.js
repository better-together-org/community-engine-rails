import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["groups", "status", "loadButton", "roleSelect"]
  static values = { githubUrl: String, importUrl: String, githubLoaded: Boolean, contributorId: String }

  async loadGithubSources(event) {
    if (event) event.preventDefault()
    if (!this.hasGithubUrlValue || this.githubLoadedValue || !this.hasGroupsTarget) return

    this.statusTarget.textContent = "Loading GitHub contribution sources..."
    if (this.hasLoadButtonTarget) this.loadButtonTarget.disabled = true

    try {
      const response = await fetch(this.githubUrlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`GitHub source load failed: ${response.status}`)

      const payload = await response.json()
      this.renderGroups(payload.groups || [])
      this.githubLoadedValue = true
      this.statusTarget.textContent = payload.groups?.length ? "GitHub contribution sources loaded." : "No linked GitHub sources found."
    } catch (_error) {
      this.statusTarget.textContent = "Unable to load GitHub contribution sources right now."
    } finally {
      if (this.hasLoadButtonTarget) this.loadButtonTarget.disabled = false
    }
  }

  async importContribution(event) {
    event.preventDefault()
    if (!this.hasImportUrlValue) return

    const response = await fetch(this.importUrlValue, {
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
    const contribution = payload.contribution
    if (!contribution) return

    this.selectContributor(contribution.role, contribution.contributor_id || this.contributorIdValue)
    this.statusTarget.textContent = `Imported ${this.humanize(contribution.role)} contribution from GitHub (${contribution.github_sources_count} source${contribution.github_sources_count === 1 ? "" : "s"}).`
  }

  selectContributor(role, contributorId) {
    const select = this.roleSelectTargets.find((target) => target.dataset.roleName === role)
    if (!select || !contributorId) return

    const option = Array.from(select.options).find((candidate) => candidate.value === String(contributorId))
    if (!option) return

    option.selected = true
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }

  renderGroups(groups) {
    if (!this.hasGroupsTarget) return

    if (!groups.length) {
      this.groupsTarget.innerHTML = '<p class="small text-muted mb-0">No linked GitHub contribution sources are available yet.</p>'
      return
    }

    this.groupsTarget.innerHTML = groups.map((group) => {
      const citations = (group.citations || []).map((citation) => `
        <div class="border rounded p-2 bg-light-subtle">
          <div class="d-flex justify-content-between gap-2 align-items-start">
            <div>
              <div class="fw-semibold">${this.escapeHtml(citation.reference_key)}: ${this.escapeHtml(citation.title)}</div>
              <div class="small text-muted">${this.escapeHtml([this.humanize(citation.source_kind), citation.source_author, citation.publisher].filter(Boolean).join(" | "))}</div>
            </div>
            <button
              type="button"
              class="btn btn-sm btn-outline-secondary"
              data-action="click->better_together--github-contribution-import#importContribution"
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
              Import Contribution
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

  parseMetadata(value) {
    if (!value) return {}

    try {
      return JSON.parse(value)
    } catch (_error) {
      return {}
    }
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
