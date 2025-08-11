import { Controller } from "@hotwired/stimulus"
import { updateUnreadNotifications } from "better_together/notifications"

// Marks a notification as read when it enters the viewport or is clicked
export default class extends Controller {
  static values = { markReadUrl: String }

  connect() {
    this.markAsRead = this.markAsRead.bind(this)
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          this.markAsRead()
        }
      })
    }, { threshold: 0.5 })
    this.observer.observe(this.element)
    this.element.addEventListener("click", this.markAsRead)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    this.element.removeEventListener("click", this.markAsRead)
  }

  markAsRead(event) {
    if (this.marked) return
    this.marked = true

    const link = event?.target.closest("a")
    if (link) event.preventDefault()

    fetch(this.markReadUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json",
      },
    })
      .then((response) => response.json())
      .then((data) => {
        this.element.classList.remove("list-group-item-action")
        const badge = this.element.querySelector(".badge")
        if (badge) badge.remove()
        if (data.unread_count !== undefined) {
          updateUnreadNotifications(data.unread_count)
          const counter = document.getElementById("notifications_unread_count")
          if (counter) counter.textContent = data.unread_count
        }
        if (link) { window.location = link.href }
      })
      .catch(() => { this.marked = false })
  }
}

