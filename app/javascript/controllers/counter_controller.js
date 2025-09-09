import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="counter"
export default class extends Controller {
  static targets = [ "number" ]
  
  connect() {
    this.animateCounter()
  }
  
  animateCounter() {
    const element = this.numberTarget
    const endValue = parseInt(element.dataset.counterEndValue || element.textContent)
    const duration = 2000 // 2 seconds
    const startTime = performance.now()
    
    const updateCounter = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      // Use easing function for smooth animation
      const easeOutQuart = 1 - Math.pow(1 - progress, 4)
      const currentValue = Math.floor(easeOutQuart * endValue)
      
      element.textContent = currentValue.toLocaleString()
      
      if (progress < 1) {
        requestAnimationFrame(updateCounter)
      }
    }
    
    // Start animation when element is in viewport
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          requestAnimationFrame(updateCounter)
          observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.5 })
    
    observer.observe(element)
  }
}