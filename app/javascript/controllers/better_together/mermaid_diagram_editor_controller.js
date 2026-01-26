import { Controller } from "@hotwired/stimulus"
import mermaid from "mermaid"
import { enhanceDiagrams } from "better_together/mermaid_tools"

// Live-preview Mermaid diagrams while editing block content
export default class extends Controller {
  static targets = ["sourceInput", "preview", "themeSelect"]

  static values = {
    theme: { type: String, default: "default" },
    placeholderText: { type: String, default: "Preview will appear here..." }
  }

  connect() {
    this.renderPreview()
  }

  updatePreview() {
    this.renderPreview()
  }

  async renderPreview() {
    if (!this.hasPreviewTarget || !this.hasSourceInputTarget) return

    const source = this.activeSourceInput()
    const content = this.currentDiagramSource(source)

    if (!content) {
      this.previewTarget.innerHTML = this.placeholderMarkup()
      return
    }

    const theme = this.currentTheme()
    mermaid.initialize({
      startOnLoad: false,
      theme,
      securityLevel: "strict",
      fontFamily: "inherit"
    })

    const diagramId = `mermaid-preview-${Date.now()}`

    try {
      const { svg } = await mermaid.render(diagramId, content)
      this.previewTarget.innerHTML = `<div class="mermaid-diagram">${svg}</div>`
      enhanceDiagrams(this.previewTarget.querySelectorAll('.mermaid-diagram'))
    } catch (error) {
      console.error("Mermaid rendering error:", error)
      this.previewTarget.innerHTML = this.placeholderMarkup()
    }
  }

  currentTheme() {
    if (this.hasThemeSelectTarget) return this.themeSelectTarget.value || this.themeValue
    return this.themeValue
  }

  activeSourceInput() {
    const active = this.sourceInputTargets.find((input) => this.isActivePane(input))
    return active || this.sourceInputTargets[0]
  }

  isActivePane(element) {
    const pane = element.closest(".tab-pane")
    return pane && pane.classList.contains("show") && pane.classList.contains("active")
  }

  placeholderMarkup() {
    const text = this.placeholderTextValue || "Preview will appear here..."
    const escaped = this.escapeHtml(text)
    return `
      <p class="text-muted text-center mb-0">
        <i class="fas fa-info-circle" aria-hidden="true"></i>
        ${escaped}
      </p>
    `
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  currentDiagramSource(source) {
    const directValue = source?.value?.trim()
    if (directValue) return directValue

    const existingPreview = this.previewTarget.querySelector(".mermaid-diagram")
    if (existingPreview) {
      const text = existingPreview.textContent || existingPreview.innerText || ""
      return text.trim()
    }

    return ""
  }
}
