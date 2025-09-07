import { Controller } from "@hotwired/stimulus"

// Testimonial carousel controller for rotating testimonials
export default class extends Controller {
  static targets = ["testimonial", "indicator", "prevButton", "nextButton"]
  
  connect() {
    this.currentIndex = 0
    this.testimonialCount = this.testimonialTargets.length
    
    // Initialize display
    this.updateDisplay()
    
    // Start auto-rotation
    this.startAutoRotate()
    
    // Add swipe support for mobile
    this.addSwipeSupport()
  }
  
  disconnect() {
    this.stopAutoRotate()
  }
  
  next() {
    this.currentIndex = (this.currentIndex + 1) % this.testimonialCount
    this.updateDisplay()
    this.resetAutoRotate()
  }
  
  previous() {
    this.currentIndex = (this.currentIndex - 1 + this.testimonialCount) % this.testimonialCount
    this.updateDisplay()
    this.resetAutoRotate()
  }
  
  goToSlide(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.currentIndex = index
    this.updateDisplay()
    this.resetAutoRotate()
  }
  
  updateDisplay() {
    // Update testimonials visibility
    this.testimonialTargets.forEach((testimonial, index) => {
      if (index === this.currentIndex) {
        testimonial.classList.remove("hidden")
        testimonial.style.opacity = "0"
        setTimeout(() => {
          testimonial.style.transition = "opacity 0.5s ease-in-out"
          testimonial.style.opacity = "1"
        }, 10)
      } else {
        testimonial.classList.add("hidden")
      }
    })
    
    // Update indicators
    if (this.hasIndicatorTarget) {
      this.indicatorTargets.forEach((indicator, index) => {
        if (index === this.currentIndex) {
          indicator.classList.add("bg-indigo-600")
          indicator.classList.remove("bg-gray-300")
        } else {
          indicator.classList.remove("bg-indigo-600")
          indicator.classList.add("bg-gray-300")
        }
      })
    }
  }
  
  startAutoRotate() {
    this.autoRotateInterval = setInterval(() => {
      this.next()
    }, 5000) // Rotate every 5 seconds
  }
  
  stopAutoRotate() {
    if (this.autoRotateInterval) {
      clearInterval(this.autoRotateInterval)
    }
  }
  
  resetAutoRotate() {
    this.stopAutoRotate()
    this.startAutoRotate()
  }
  
  addSwipeSupport() {
    let touchStartX = 0
    let touchEndX = 0
    
    this.element.addEventListener('touchstart', (e) => {
      touchStartX = e.changedTouches[0].screenX
    })
    
    this.element.addEventListener('touchend', (e) => {
      touchEndX = e.changedTouches[0].screenX
      this.handleSwipe(touchStartX, touchEndX)
    })
  }
  
  handleSwipe(startX, endX) {
    const swipeThreshold = 50
    const diff = startX - endX
    
    if (Math.abs(diff) > swipeThreshold) {
      if (diff > 0) {
        // Swipe left - next testimonial
        this.next()
      } else {
        // Swipe right - previous testimonial
        this.previous()
      }
    }
  }
}