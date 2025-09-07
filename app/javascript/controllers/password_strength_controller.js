import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password-strength"
export default class extends Controller {
  static targets = ["password", "bar", "label"]

  connect() {
    this.passwordTarget.addEventListener("input", () => this.checkStrength())
  }

  checkStrength() {
    const password = this.passwordTarget.value
    let strength = 0
    let label = "Too weak"
    let colorClass = "bg-red-500"

    if (password.length > 0) {
      // Length check
      if (password.length >= 8) strength += 25
      if (password.length >= 12) strength += 10

      // Character variety checks
      if (/[a-z]/.test(password)) strength += 15
      if (/[A-Z]/.test(password)) strength += 15
      if (/[0-9]/.test(password)) strength += 20
      if (/[^a-zA-Z0-9]/.test(password)) strength += 15

      // Set label and color based on strength
      if (strength < 30) {
        label = "Too weak"
        colorClass = "bg-red-500"
      } else if (strength < 50) {
        label = "Weak"
        colorClass = "bg-orange-500"
      } else if (strength < 70) {
        label = "Fair"
        colorClass = "bg-yellow-500"
      } else if (strength < 90) {
        label = "Good"
        colorClass = "bg-blue-500"
      } else {
        label = "Strong"
        colorClass = "bg-green-500"
      }
    } else {
      strength = 0
      label = "Enter a password"
      colorClass = "bg-gray-300"
    }

    // Update UI
    this.barTarget.style.width = `${strength}%`
    this.barTarget.className = `h-1.5 rounded-full transition-all duration-300 ${colorClass}`
    this.labelTarget.textContent = label
  }
}