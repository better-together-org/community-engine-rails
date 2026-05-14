import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["button"]

  copy() {
    if (!this.urlValue) return
    navigator.clipboard.writeText(this.urlValue).then(() => {
      this._flashIcon()
    }).catch(() => {
      const inp = document.createElement('input')
      inp.value = this.urlValue
      document.body.appendChild(inp)
      inp.select()
      document.execCommand('copy')
      document.body.removeChild(inp)
      this._flashIcon()
    })
  }

  _flashIcon() {
    const icon = this.buttonTarget.querySelector('i.icon')
    if (!icon) return
    icon.className = 'fa-stack-1x icon fas fa-check'
    setTimeout(() => { icon.className = 'fa-stack-1x icon fas fa-link' }, 2000)
  }
}
