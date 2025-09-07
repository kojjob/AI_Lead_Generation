import { Controller } from "@hotwired/stimulus"

// Accordion controller for FAQ section
export default class extends Controller {
  static targets = ["item", "icon", "content"]
  
  connect() {
    console.log("Accordion controller connected with", this.itemTargets.length, "items")
    // Hide all content initially
    this.contentTargets.forEach(content => {
      content.classList.add("hidden")
    })
  }
  
  toggle(event) {
    event.preventDefault()
    
    // Find the clicked item
    const button = event.currentTarget
    const item = button.closest('[data-accordion-target="item"]')
    const itemIndex = this.itemTargets.indexOf(item)
    
    if (itemIndex === -1) return
    
    const content = this.contentTargets[itemIndex]
    const icon = this.iconTargets[itemIndex]
    
    // Check if this item is currently open
    const isOpen = !content.classList.contains("hidden")
    
    // Close all items
    this.closeAll()
    
    // If it wasn't open, open it
    if (!isOpen) {
      this.open(content, icon)
    }
  }
  
  open(content, icon) {
    // Show content
    content.classList.remove("hidden")
    
    // Animate opening
    content.style.maxHeight = "0"
    content.style.overflow = "hidden"
    content.style.transition = "max-height 0.3s ease-out"
    
    // Force browser to recalculate
    content.offsetHeight
    
    // Set to actual height
    content.style.maxHeight = content.scrollHeight + "px"
    
    // Rotate icon
    icon.style.transform = "rotate(180deg)"
  }
  
  closeAll() {
    this.contentTargets.forEach((content, index) => {
      if (!content.classList.contains("hidden")) {
        content.style.maxHeight = "0"
        
        setTimeout(() => {
          content.classList.add("hidden")
          content.style.maxHeight = ""
        }, 300)
      }
      
      // Reset icon rotation
      const icon = this.iconTargets[index]
      icon.style.transform = "rotate(0deg)"
    })
  }
}