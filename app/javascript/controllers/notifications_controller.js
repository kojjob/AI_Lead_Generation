import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["count", "list", "bell"]
  
  connect() {
    // Subscribe to notification updates via Turbo Streams
    this.subscription = this.createSubscription()
    
    // Mark notifications as read when clicked
    this.element.addEventListener("click", this.handleNotificationClick.bind(this))
  }
  
  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }
  
  createSubscription() {
    // This will work with Turbo Streams from the server
    return {
      unsubscribe: () => {}
    }
  }
  
  handleNotificationClick(event) {
    const notificationElement = event.target.closest("[data-notification-id]")
    if (notificationElement && notificationElement.dataset.unread === "true") {
      this.markAsRead(notificationElement.dataset.notificationId)
    }
  }
  
  markAsRead(notificationId) {
    const url = `/notifications/${notificationId}/mark_as_read`
    
    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
  }
  
  updateCount(count) {
    if (this.hasCountTarget) {
      if (count > 0) {
        this.countTarget.textContent = count > 99 ? "99+" : count
        this.countTarget.classList.remove("hidden")
      } else {
        this.countTarget.classList.add("hidden")
      }
    }
    
    // Add animation to bell icon when new notification arrives
    if (this.hasBellTarget && count > 0) {
      this.animateBell()
    }
  }
  
  animateBell() {
    this.bellTarget.classList.add("animate-bounce")
    setTimeout(() => {
      this.bellTarget.classList.remove("animate-bounce")
    }, 1000)
  }
}