import { Controller } from "@hotwired/stimulus"

// Enhanced dropdown controller with smooth animations and accessibility
export default class extends Controller {
  static targets = ["menu", "button"]
  static values = { 
    open: Boolean,
    closeOnSelect: { type: Boolean, default: true }
  }

  connect() {
    // Set initial state
    this.openValue = false
    
    // Add click outside listener
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundHandleEscape = this.handleEscape.bind(this)
  }

  disconnect() {
    document.removeEventListener('click', this.boundHandleClickOutside)
    document.removeEventListener('keydown', this.boundHandleEscape)
  }

  toggle(event) {
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    if (this.openValue) {
      this.showMenu()
    } else {
      this.hideMenu()
    }
  }

  showMenu() {
    if (!this.hasMenuTarget) return

    // Remove hidden class first
    this.menuTarget.classList.remove('hidden')
    
    // Force reflow
    this.menuTarget.offsetHeight
    
    // Add animation classes
    this.menuTarget.classList.add('dropdown-enter')
    
    // Start animation
    requestAnimationFrame(() => {
      this.menuTarget.classList.add('dropdown-enter-active')
      this.menuTarget.classList.remove('dropdown-enter')
    })

    // Update button aria
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute('aria-expanded', 'true')
    }

    // Add event listeners
    document.addEventListener('click', this.boundHandleClickOutside)
    document.addEventListener('keydown', this.boundHandleEscape)

    // Focus first menu item for accessibility
    const firstMenuItem = this.menuTarget.querySelector('[role="menuitem"]')
    if (firstMenuItem) {
      firstMenuItem.focus()
    }
  }

  hideMenu() {
    if (!this.hasMenuTarget) return

    // Add exit animation classes
    this.menuTarget.classList.add('dropdown-exit')
    this.menuTarget.classList.add('dropdown-exit-active')

    // Wait for animation to complete
    const handleTransitionEnd = () => {
      this.menuTarget.classList.add('hidden')
      this.menuTarget.classList.remove('dropdown-exit', 'dropdown-exit-active', 'dropdown-enter-active')
      this.menuTarget.removeEventListener('transitionend', handleTransitionEnd)
    }

    this.menuTarget.addEventListener('transitionend', handleTransitionEnd)

    // Update button aria
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute('aria-expanded', 'false')
    }

    // Remove event listeners
    document.removeEventListener('click', this.boundHandleClickOutside)
    document.removeEventListener('keydown', this.boundHandleEscape)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close()
      if (this.hasButtonTarget) {
        this.buttonTarget.focus()
      }
    }
  }

  // Handle keyboard navigation
  handleKeydown(event) {
    if (!this.openValue) {
      if (event.key === 'Enter' || event.key === ' ' || event.key === 'ArrowDown') {
        event.preventDefault()
        this.open()
      }
      return
    }

    const items = Array.from(this.menuTarget.querySelectorAll('[role="menuitem"]:not([disabled])'))
    const currentIndex = items.indexOf(document.activeElement)

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        const nextIndex = currentIndex === items.length - 1 ? 0 : currentIndex + 1
        items[nextIndex]?.focus()
        break
      case 'ArrowUp':
        event.preventDefault()
        const prevIndex = currentIndex <= 0 ? items.length - 1 : currentIndex - 1
        items[prevIndex]?.focus()
        break
      case 'Home':
        event.preventDefault()
        items[0]?.focus()
        break
      case 'End':
        event.preventDefault()
        items[items.length - 1]?.focus()
        break
      case 'Tab':
        // Let tab close the menu
        this.close()
        break
    }
  }

  // Handle menu item selection
  selectItem(event) {
    if (this.closeOnSelectValue) {
      this.close()
    }
  }
}