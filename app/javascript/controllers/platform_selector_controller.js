import { Controller } from "@hotwired/stimulus"

// Platform Selector Controller for interactive platform selection cards
export default class extends Controller {
  connect() {
    console.log("Platform selector controller connected")
    this.initializeSelection()
  }

  // Handle platform card selection
  selectPlatform(event) {
    const card = event.currentTarget
    const platform = card.dataset.platform
    
    // Update visual selection
    this.updateCardSelection(card)
    
    // Update the form select field
    this.updateFormSelection(platform)
    
    // Trigger platform change event for the form controller
    this.triggerPlatformChange(platform)
    
    // Smooth scroll to form
    this.scrollToForm()
  }

  // Update visual selection of cards
  updateCardSelection(selectedCard) {
    // Remove selection from all cards
    const allCards = this.element.querySelectorAll('.platform-card')
    allCards.forEach(card => {
      card.classList.remove('ring-2', 'ring-indigo-500', 'border-indigo-500', 'bg-indigo-50')
      card.classList.add('border-gray-200', 'bg-white')
      
      // Reset transform
      card.style.transform = ''
    })
    
    // Add selection to clicked card
    selectedCard.classList.remove('border-gray-200', 'bg-white')
    selectedCard.classList.add('ring-2', 'ring-indigo-500', 'border-indigo-500', 'bg-indigo-50')
    
    // Add a subtle scale effect
    selectedCard.style.transform = 'scale(1.02)'
    
    // Add selection indicator
    this.addSelectionIndicator(selectedCard)
  }

  // Add visual selection indicator to card
  addSelectionIndicator(card) {
    // Remove existing indicators
    const existingIndicator = card.querySelector('.selection-indicator')
    if (existingIndicator) {
      existingIndicator.remove()
    }
    
    // Create new indicator
    const indicator = document.createElement('div')
    indicator.className = 'selection-indicator absolute top-3 right-3 w-6 h-6 bg-indigo-600 rounded-full flex items-center justify-center'
    indicator.innerHTML = `
      <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
      </svg>
    `
    
    // Make card relative positioned if not already
    card.style.position = 'relative'
    card.appendChild(indicator)
    
    // Animate the indicator
    indicator.style.opacity = '0'
    indicator.style.transform = 'scale(0.5)'
    
    setTimeout(() => {
      indicator.style.transition = 'all 0.3s ease-out'
      indicator.style.opacity = '1'
      indicator.style.transform = 'scale(1)'
    }, 50)
  }

  // Update the form select field
  updateFormSelection(platform) {
    const platformSelect = document.querySelector('select[name="integration[platform_name]"]')
    if (platformSelect) {
      platformSelect.value = platform
      
      // Add visual feedback to the select
      platformSelect.classList.add('bg-indigo-50', 'border-indigo-300')
      
      setTimeout(() => {
        platformSelect.classList.remove('bg-indigo-50', 'border-indigo-300')
      }, 2000)
    }
  }

  // Trigger platform change event for other controllers
  triggerPlatformChange(platform) {
    const platformSelect = document.querySelector('select[name="integration[platform_name]"]')
    if (platformSelect) {
      // Create and dispatch change event
      const changeEvent = new Event('change', { bubbles: true })
      platformSelect.dispatchEvent(changeEvent)
    }
  }

  // Smooth scroll to the form section
  scrollToForm() {
    const formSection = document.querySelector('.integration-form')
    if (formSection) {
      setTimeout(() => {
        formSection.scrollIntoView({ 
          behavior: 'smooth', 
          block: 'start',
          inline: 'nearest'
        })
      }, 300)
    }
  }

  // Initialize selection based on existing form value
  initializeSelection() {
    const platformSelect = document.querySelector('select[name="integration[platform_name]"]')
    if (platformSelect && platformSelect.value) {
      const selectedPlatform = platformSelect.value
      const correspondingCard = this.element.querySelector(`[data-platform="${selectedPlatform}"]`)
      
      if (correspondingCard) {
        this.updateCardSelection(correspondingCard)
      }
    }
  }

  // Handle keyboard navigation
  handleKeydown(event) {
    const cards = Array.from(this.element.querySelectorAll('.platform-card'))
    const currentIndex = cards.findIndex(card => card.classList.contains('ring-2'))
    
    let newIndex = currentIndex
    
    switch (event.key) {
      case 'ArrowRight':
      case 'ArrowDown':
        event.preventDefault()
        newIndex = (currentIndex + 1) % cards.length
        break
      case 'ArrowLeft':
      case 'ArrowUp':
        event.preventDefault()
        newIndex = currentIndex > 0 ? currentIndex - 1 : cards.length - 1
        break
      case 'Enter':
      case ' ':
        event.preventDefault()
        if (currentIndex >= 0) {
          this.selectPlatform({ currentTarget: cards[currentIndex] })
        }
        return
      default:
        return
    }
    
    if (newIndex !== currentIndex && newIndex >= 0) {
      cards[newIndex].focus()
      this.updateCardSelection(cards[newIndex])
    }
  }

  // Add hover effects
  addHoverEffects() {
    const cards = this.element.querySelectorAll('.platform-card')
    
    cards.forEach(card => {
      card.addEventListener('mouseenter', () => {
        if (!card.classList.contains('ring-2')) {
          card.style.transform = 'translateY(-2px) scale(1.02)'
          card.style.boxShadow = '0 10px 25px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)'
        }
      })
      
      card.addEventListener('mouseleave', () => {
        if (!card.classList.contains('ring-2')) {
          card.style.transform = ''
          card.style.boxShadow = ''
        }
      })
    })
  }

  // Platform-specific animations
  addPlatformAnimations() {
    const cards = this.element.querySelectorAll('.platform-card')
    
    cards.forEach((card, index) => {
      // Stagger the initial animation
      card.style.opacity = '0'
      card.style.transform = 'translateY(20px)'
      
      setTimeout(() => {
        card.style.transition = 'all 0.5s ease-out'
        card.style.opacity = '1'
        card.style.transform = 'translateY(0)'
      }, index * 100)
    })
  }

  // Initialize all effects
  initialize() {
    this.addHoverEffects()
    this.addPlatformAnimations()
    
    // Add keyboard event listener to the container
    this.element.addEventListener('keydown', this.handleKeydown.bind(this))
    
    // Make cards focusable for keyboard navigation
    const cards = this.element.querySelectorAll('.platform-card')
    cards.forEach(card => {
      card.setAttribute('tabindex', '0')
      card.setAttribute('role', 'button')
      card.setAttribute('aria-label', `Select ${card.dataset.platform} platform`)
    })
  }

  // Enhanced connect method
  connect() {
    console.log("Platform selector controller connected")
    this.initialize()
    this.initializeSelection()
  }

  // Cleanup
  disconnect() {
    console.log("Platform selector controller disconnected")
    
    // Remove event listeners
    this.element.removeEventListener('keydown', this.handleKeydown.bind(this))
    
    // Reset any transforms
    const cards = this.element.querySelectorAll('.platform-card')
    cards.forEach(card => {
      card.style.transform = ''
      card.style.transition = ''
      card.style.opacity = ''
      card.style.boxShadow = ''
    })
  }
}
