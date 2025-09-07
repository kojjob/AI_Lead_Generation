import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password-toggle"
export default class extends Controller {
  static targets = ["input", "showIcon", "hideIcon", "button"]

  toggle() {
    const input = this.inputTarget
    const showIcon = this.showIconTarget
    const hideIcon = this.hideIconTarget

    if (input.type === "password") {
      input.type = "text"
      showIcon.classList.add("hidden")
      hideIcon.classList.remove("hidden")
    } else {
      input.type = "password"
      showIcon.classList.remove("hidden")
      hideIcon.classList.add("hidden")
    }
  }
}