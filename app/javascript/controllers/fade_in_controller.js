import { Controller } from "@hotwired/stimulus"

// Fade in animation controller for elements
export default class extends Controller {
  static targets = ["element"]
  
  connect() {
    console.log("Fade-in controller connected")
    // Add initial state
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(20px)"
    this.element.style.transition = "opacity 0.6s ease-out, transform 0.6s ease-out"
    
    // Trigger animation after a short delay
    setTimeout(() => {
      this.fadeIn()
    }, 100)
  }
  
  fadeIn() {
    this.element.style.opacity = "1"
    this.element.style.transform = "translateY(0)"
  }
}