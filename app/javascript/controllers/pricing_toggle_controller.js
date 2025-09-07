import { Controller } from "@hotwired/stimulus"

// Pricing toggle controller for monthly/annual switching
export default class extends Controller {
  static targets = ["toggle", "monthlyPrice", "annualPrice", "period", "savings"]
  
  connect() {
    this.isAnnual = false
    this.updateDisplay()
  }
  
  toggle() {
    this.isAnnual = !this.isAnnual
    this.updateDisplay()
    
    // Animate the toggle button
    if (this.hasToggleTarget) {
      const toggleButton = this.toggleTarget.querySelector('span')
      if (toggleButton) {
        if (this.isAnnual) {
          toggleButton.style.transform = "translateX(2rem)"
        } else {
          toggleButton.style.transform = "translateX(0)"
        }
      }
    }
  }
  
  updateDisplay() {
    // Update all price displays
    this.monthlyPriceTargets.forEach(price => {
      price.style.display = this.isAnnual ? "none" : "block"
    })
    
    this.annualPriceTargets.forEach(price => {
      price.style.display = this.isAnnual ? "block" : "none"
    })
    
    // Update period text
    this.periodTargets.forEach(period => {
      period.textContent = this.isAnnual ? "/year" : "/month"
    })
    
    // Show/hide savings badges
    this.savingsTargets.forEach(savings => {
      if (this.isAnnual) {
        savings.classList.remove("opacity-0")
        savings.classList.add("opacity-100")
      } else {
        savings.classList.remove("opacity-100")
        savings.classList.add("opacity-0")
      }
    })
  }
  
  selectPlan(event) {
    const button = event.currentTarget
    const plan = button.dataset.plan
    const billing = this.isAnnual ? "annual" : "monthly"
    
    // Add click animation
    button.style.transform = "scale(0.95)"
    setTimeout(() => {
      button.style.transform = "scale(1)"
    }, 100)
    
    // Here you would typically redirect to signup with plan info
    console.log(`Selected plan: ${plan} - ${billing}`)
    
    // For now, just show visual feedback
    button.textContent = "Selected!"
    button.classList.add("bg-green-600")
    
    setTimeout(() => {
      button.textContent = "Start Free Trial"
      button.classList.remove("bg-green-600")
    }, 2000)
  }
}