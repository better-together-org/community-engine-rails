// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"
import mermaid from "mermaid"
import { enhanceDiagrams } from "better_together/mermaid_tools"

// Connects to data-controller="better-together--markdown-block"
export default class extends Controller {
  static targets = [
    "sourceTypeRadio",
    "inlineField",
    "fileField",
    "sourceTextarea",
    "filePathInput",
    "preview"
  ]

  static values = {
    mermaidTheme: { type: String, default: "default" },
    previewUrl: String
  }

  connect() {
    this.previousSourceType = this.selectedSourceType

    // Render any existing content on initial load (e.g., when editing saved blocks)
    queueMicrotask(() => this.refreshPreview())
  }

  get locale() {
    try {
      if (typeof I18n !== 'undefined' && I18n && I18n.locale) return I18n.locale
    } catch (e) {}
    try {
      const htmlLang = document.documentElement.getAttribute('lang')
      if (htmlLang) return htmlLang
    } catch (e) {}
    return 'en'
  }

  get routeScopePath() {
    try {
      if (typeof BetterTogether !== 'undefined' && BetterTogether && BetterTogether.route_scope_path) return BetterTogether.route_scope_path
    } catch (e) {}
    try {
      if (this.element && this.element.dataset && this.element.dataset.routeScopePath) return this.element.dataset.routeScopePath
    } catch (e) {}
    return ''
  }

  handleSourceTypeChange() {
    const selectedType = this.selectedSourceType
    if (!selectedType) return

    if (selectedType !== this.previousSourceType) {
      if (selectedType === 'inline' && this.hasFilePathInputTarget) {
        this.filePathInputTarget.value = ''
      } else if (selectedType === 'file' && this.hasSourceTextareaTarget) {
        this.sourceTextareaTarget.value = ''
      }

      this.previousSourceType = selectedType
    }

    this.refreshPreview()
  }

  async refreshPreview() {
    if (!this.hasPreviewTarget) return

    const selectedType = this.selectedSourceType
    let markdownContent = ''

    if (selectedType === 'inline' && this.hasSourceTextareaTarget) {
      markdownContent = this.sourceTextareaTarget.value
    } else if (selectedType === 'file' && this.hasFilePathInputTarget) {
      const filePath = this.filePathInputTarget.value
      if (filePath) {
        // For file paths, we'd need to make an AJAX request to render the preview
        // For now, show a placeholder
        this.previewTarget.innerHTML = `
          <p class="text-muted mb-0">
            <em>Preview for file: <code>${this.escapeHtml(filePath)}</code></em>
          </p>
          <p class="text-muted mb-0 mt-2">
            <small>File preview will be available after saving.</small>
          </p>
        `
        return
      }
    }

    if (markdownContent.trim() === '') {
      this.previewTarget.innerHTML = `
        <p class="text-muted mb-0">
          <em>Preview will appear here...</em>
        </p>
      `
      return
    }

    // Render markdown preview using a simple client-side markdown library
    // or make an AJAX call to the server to render it
    try {
      const response = await this.renderMarkdown(markdownContent)
      this.previewTarget.innerHTML = response
      this.renderMermaidDiagrams()
    } catch (error) {
      console.error('Failed to render markdown preview:', error)
      this.previewTarget.innerHTML = `
        <div class="alert alert-warning mb-0">
          <i class="fa fa-exclamation-triangle"></i>
          Failed to render preview. Please check your markdown syntax.
        </div>
      `
    }
  }

  async renderMarkdown(content) {
    // Make an AJAX request to render the markdown on the server
    const url = this.previewUrlValue || this.defaultPreviewUrl()

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({ markdown: content })
    })

    if (!response.ok) {
      throw new Error('Failed to render markdown')
    }

    const data = await response.json()
    return data.html
  }

  get selectedSourceType() {
    return this.sourceTypeRadioTargets.find(radio => radio.checked)?.value
  }

  defaultPreviewUrl() {
    const locale = this.locale
    const routeScope = this.routeScopePath
    const scopeSegment = routeScope ? `/${routeScope}` : ''
    return `/${locale}${scopeSegment}/content/blocks/preview_markdown`
  }

  async renderMermaidDiagrams() {
    if (!this.hasPreviewTarget) return

    const diagrams = this.previewTarget.querySelectorAll('.mermaid-diagram')
    if (diagrams.length === 0) return

    mermaid.initialize({
      startOnLoad: false,
      theme: this.mermaidThemeValue,
      securityLevel: 'strict',
      fontFamily: 'inherit'
    })

    try {
      await mermaid.run({ querySelector: '.mermaid-diagram', nodes: diagrams })
      enhanceDiagrams(diagrams)
    } catch (error) {
      console.error('Mermaid rendering error:', error)
      diagrams.forEach((diagram) => {
        diagram.classList.add('mermaid-error')
        diagram.innerHTML = `
          <div class="alert alert-danger mb-0">
            <strong>Diagram Rendering Error:</strong>
            <pre>${this.escapeHtml(error?.message || 'Unable to render diagram')}</pre>
          </div>
        `
      })
    }
  }


  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ''
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
