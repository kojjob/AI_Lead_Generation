import { Controller } from "@hotwired/stimulus"

// Accordion controller for FAQ section
export default class extends Controller {
  static targets = ["question", "answer", "icon"]
  
  connect() {
    // Hide all answers initially
    this.answerTargets.forEach(answer => {
      answer.style.maxHeight = "0"
      answer.style.overflow = "hidden"
      answer.style.transition = "max-height 0.3s ease-out, padding 0.3s ease-out"
      answer.classList.add("py-0")
    })
  }
  
  toggle(event) {
    const clickedQuestion = event.currentTarget
    const index = this.questionTargets.indexOf(clickedQuestion)
    const answer = this.answerTargets[index]
    const icon = this.iconTargets[index]
    
    // Check if this item is currently open
    const isOpen = answer.style.maxHeight && answer.style.maxHeight !== "0px"
    
    // Close all items
    this.closeAll()
    
    // If it wasn't open, open it
    if (!isOpen) {
      this.open(answer, icon)
    }
  }
  
  open(answer, icon) {
    // Calculate the height needed
    answer.style.maxHeight = answer.scrollHeight + "px"
    answer.classList.remove("py-0")
    answer.classList.add("py-4")
    
    // Rotate icon
    icon.style.transform = "rotate(180deg)"
    icon.style.transition = "transform 0.3s ease-out"
  }
  
  closeAll() {
    this.answerTargets.forEach((answer, index) => {
      answer.style.maxHeight = "0"
      answer.classList.remove("py-4")
      answer.classList.add("py-0")
      
      // Reset icon rotation
      const icon = this.iconTargets[index]
      icon.style.transform = "rotate(0deg)"
    })
  }
}