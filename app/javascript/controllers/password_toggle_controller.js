import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password-toggle"
export default class extends Controller {
  static targets = ["input", "showIcon", "hideIcon"]

  connect() {
    console.log("Password toggle controller connected")
    // Ensure initial state is correct
    this.resetState()
  }

  toggle(event) {
    event.preventDefault()
    
    if (!this.hasInputTarget) {
      console.error("Password input target not found")
      return
    }

    const input = this.inputTarget
    const isPassword = input.type === "password"
    
    // Toggle input type
    input.type = isPassword ? "text" : "password"
    
    // Toggle icons if they exist
    if (this.hasShowIconTarget && this.hasHideIconTarget) {
      if (isPassword) {
        this.showIconTarget.classList.add("hidden")
        this.hideIconTarget.classList.remove("hidden")
      } else {
        this.showIconTarget.classList.remove("hidden")
        this.hideIconTarget.classList.add("hidden")
      }
    }
    
    // Keep focus on the input
    input.focus()
    
    // Maintain cursor position
    const cursorPosition = input.selectionStart
    requestAnimationFrame(() => {
      input.setSelectionRange(cursorPosition, cursorPosition)
    })
  }

  resetState() {
    // Ensure password field starts as password type
    if (this.hasInputTarget) {
      this.inputTarget.type = "password"
    }
    
    // Ensure correct icon visibility
    if (this.hasShowIconTarget && this.hasHideIconTarget) {
      this.showIconTarget.classList.remove("hidden")
      this.hideIconTarget.classList.add("hidden")
    }
  }

  disconnect() {
    console.log("Password toggle controller disconnected")
  }
}