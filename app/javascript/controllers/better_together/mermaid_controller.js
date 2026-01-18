// app/javascript/controllers/better_together/mermaid_controller.js
import { Controller } from "@hotwired/stimulus"
import mermaid from "mermaid"
import { enhanceDiagrams } from "better_together/mermaid_tools"

/**
 * Stimulus controller for rendering Mermaid diagrams
 * 
 * Usage:
 *   <div data-controller="better-together--mermaid" data-better-together--mermaid-theme-value="default">
 *     <pre class="mermaid-diagram">
 *       graph TD
 *         A-->B
 *     </pre>
 *   </div>
 */
export default class extends Controller {
  static values = {
    theme: { type: String, default: "default" }
  }

  connect() {
    this.boundTurboLoad = this.handleTurboLoad.bind(this)
    this.initializeMermaid()
    this.renderDiagrams()
    document.addEventListener('turbo:load', this.boundTurboLoad)
  }

  disconnect() {
    document.removeEventListener('turbo:load', this.boundTurboLoad)
  }

  initializeMermaid() {
    mermaid.initialize({
      startOnLoad: false,
      theme: this.themeValue,
      securityLevel: 'strict',
      fontFamily: 'inherit'
    })
  }

  async renderDiagrams() {
    const diagrams = Array.from(this.element.querySelectorAll('.mermaid-diagram'))
    if (diagrams.length === 0) return

    for (const [index, diagram] of diagrams.entries()) {
      try {
        if (!diagram.dataset.originalContent) {
          diagram.dataset.originalContent = diagram.textContent
        }

        // Skip if already rendered and enhanced
        if (diagram.querySelector('svg')) continue

        const diagramText = (diagram.dataset.originalContent || diagram.textContent || '').trim()
        if (!diagramText) continue

        const diagramId = `mermaid-diagram-${Date.now()}-${index}`
        const { svg } = await mermaid.render(diagramId, diagramText)

        diagram.innerHTML = svg
        diagram.classList.add('mermaid-rendered')
        diagram.dataset.enhanced = 'false'
      } catch (error) {
        console.error('Mermaid rendering error:', error)
        this.handleRenderError(diagram, error)
      }
    }

    enhanceDiagrams(diagrams)
  }

  handleRenderError(diagram, error) {
    diagram.classList.add('mermaid-error')
    const errorMessage = document.createElement('div')
    errorMessage.className = 'alert alert-danger'
    errorMessage.innerHTML = `
      <strong>Diagram Rendering Error:</strong>
      <pre>${error.message || 'Unable to render diagram'}</pre>
    `
    diagram.appendChild(errorMessage)
  }

  handleTurboLoad() {
    this.renderDiagrams()
  }

  // Allow theme changes via value change
  themeValueChanged() {
    this.initializeMermaid()

    const diagrams = Array.from(this.element.querySelectorAll('.mermaid-diagram'))
    diagrams.forEach((diagram) => {
      diagram.classList.remove('mermaid-rendered')
      diagram.innerHTML = diagram.dataset.originalContent || diagram.textContent
      diagram.dataset.enhanced = 'false'
    })

    this.renderDiagrams()
  }
}
