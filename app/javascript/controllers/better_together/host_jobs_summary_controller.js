import { Controller } from '@hotwired/stimulus'

// Reloads the background jobs summary frame on an interval, pausing while the tab is hidden.
// The status region is only written when a watched count rises (or workers drop to zero),
// so screen readers hear about new trouble, not every refresh.
export default class extends Controller {
  static targets = ['frame', 'status']
  static values = { interval: { type: Number, default: 30000 } }

  connect() {
    this.previous = null
    this.onFrameLoad = this.frameLoaded.bind(this)
    this.onVisibility = this.visibilityChanged.bind(this)
    this.element.addEventListener('turbo:frame-load', this.onFrameLoad)
    document.addEventListener('visibilitychange', this.onVisibility)
    this.start()
  }

  disconnect() {
    this.stop()
    this.element.removeEventListener('turbo:frame-load', this.onFrameLoad)
    document.removeEventListener('visibilitychange', this.onVisibility)
  }

  start() {
    this.stop()
    if (document.hidden || this.intervalValue <= 0) return
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }

  refresh() {
    if (!this.hasFrameTarget || document.hidden) return
    this.frameTarget.reload()
  }

  visibilityChanged() {
    if (document.hidden) {
      this.stop()
    } else {
      this.refresh()
      this.start()
    }
  }

  frameLoaded(event) {
    if (this.hasFrameTarget && event.target !== this.frameTarget) return
    const content = this.frameTarget.querySelector('[data-host-jobs-summary-counts]')
    if (!content) return

    let counts
    try {
      counts = JSON.parse(content.dataset.hostJobsSummaryCounts)
    } catch (_error) {
      return
    }
    if (this.previous && this.worsened(this.previous, counts)) {
      this.announce(content.dataset.hostJobsSummaryAnnouncement)
    }
    this.previous = counts
  }

  worsened(before, after) {
    const rose = ['failed', 'retrying', 'dead', 'stalled'].some((key) => (after[key] || 0) > (before[key] || 0))
    const workersStopped = (before.processes || 0) > 0 && (after.processes || 0) === 0
    return rose || workersStopped
  }

  announce(message) {
    if (!this.hasStatusTarget || !message) return
    this.statusTarget.textContent = ''
    window.setTimeout(() => { this.statusTarget.textContent = message }, 50)
  }
}
