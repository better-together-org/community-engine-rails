// app/javascript/controllers/invitation_timer_controller.js

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    expiresAt: Number // Timestamp in seconds (epoch time)
  }

  connect() {
    this.updateTimer()
    this.interval = setInterval(() => this.updateTimer(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  updateTimer() {
    const now = Math.floor(Date.now() / 1000)
    const remainingSeconds = this.expiresAtValue - now
    console.log("Timer:", { expiresAt: this.expiresAtValue, now, remainingSeconds })

    if (remainingSeconds <= 0) {
      this.element.textContent = 'Expired'
      this.element.classList.remove('bg-info')
      this.element.classList.add('bg-danger')
      clearInterval(this.interval)
      return
    }

    const minutes = Math.floor(remainingSeconds / 60)
    this.element.textContent = `${minutes} min`
  }
}
