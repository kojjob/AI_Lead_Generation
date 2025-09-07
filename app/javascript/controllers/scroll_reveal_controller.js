import { Controller } from "@hotwired/stimulus"

// Reveal elements on scroll with animation
export default class extends Controller {
  static targets = ["element"]
  static values = { 
    delay: { type: Number, default: 0 },
    threshold: { type: Number, default: 0.1 }
  }
  
  connect() {
    // Set initial state
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(30px)"
    this.element.style.transition = `opacity 0.8s ease-out ${this.delayValue}ms, transform 0.8s ease-out ${this.delayValue}ms`
    
    // Create intersection observer
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersect(entries),
      {
        threshold: this.thresholdValue,
        rootMargin: "0px 0px -50px 0px"
      }
    )
    
    this.observer.observe(this.element)
  }
  
  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
  
  handleIntersect(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        this.reveal()
        this.observer.unobserve(entry.target)
      }
    })
  }
  
  reveal() {
    this.element.style.opacity = "1"
    this.element.style.transform = "translateY(0)"
  }
}