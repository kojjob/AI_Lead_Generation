import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navigation"
export default class extends Controller {
  static targets = [ 
    "mobileMenu", 
    "hamburgerIcon", 
    "closeIcon", 
    "userDropdown", 
    "userPanel",
    "notificationsDropdown",
    "notificationsPanel"
  ]

  connect() {
    // Close dropdowns when clicking outside
    document.addEventListener('click', this.handleOutsideClick.bind(this))
    
    // Close mobile menu on window resize
    window.addEventListener('resize', this.handleResize.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.handleOutsideClick.bind(this))
    window.removeEventListener('resize', this.handleResize.bind(this))
  }

  toggleMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.toggle('hidden')
      this.hamburgerIconTarget.classList.toggle('hidden')
      this.closeIconTarget.classList.toggle('hidden')
      
      // Update aria-expanded
      const button = event.currentTarget
      const expanded = button.getAttribute('aria-expanded') === 'true'
      button.setAttribute('aria-expanded', !expanded)
    }
  }

  toggleUserMenu(event) {
    event.stopPropagation()
    
    if (this.hasUserPanelTarget) {
      const isHidden = this.userPanelTarget.classList.contains('hidden')
      
      // Close other dropdowns first
      this.closeNotifications()
      
      if (isHidden) {
        this.userPanelTarget.classList.remove('hidden')
        event.currentTarget.setAttribute('aria-expanded', 'true')
      } else {
        this.userPanelTarget.classList.add('hidden')
        event.currentTarget.setAttribute('aria-expanded', 'false')
      }
    }
  }

  toggleNotifications(event) {
    event.stopPropagation()
    
    if (this.hasNotificationsPanelTarget) {
      const isHidden = this.notificationsPanelTarget.classList.contains('hidden')
      
      // Close other dropdowns first
      this.closeUserMenu()
      
      if (isHidden) {
        this.notificationsPanelTarget.classList.remove('hidden')
        event.currentTarget.setAttribute('aria-expanded', 'true')
      } else {
        this.notificationsPanelTarget.classList.add('hidden')
        event.currentTarget.setAttribute('aria-expanded', 'false')
      }
    }
  }

  closeUserMenu() {
    if (this.hasUserPanelTarget) {
      this.userPanelTarget.classList.add('hidden')
      const button = this.userDropdownTarget.querySelector('button')
      if (button) {
        button.setAttribute('aria-expanded', 'false')
      }
    }
  }

  closeNotifications() {
    if (this.hasNotificationsPanelTarget) {
      this.notificationsPanelTarget.classList.add('hidden')
      const button = this.notificationsDropdownTarget.querySelector('button')
      if (button) {
        button.setAttribute('aria-expanded', 'false')
      }
    }
  }

  closeMobileMenu() {
    if (this.hasMobileMenuTarget && !this.mobileMenuTarget.classList.contains('hidden')) {
      this.mobileMenuTarget.classList.add('hidden')
      this.hamburgerIconTarget.classList.remove('hidden')
      this.closeIconTarget.classList.add('hidden')
      
      const button = this.element.querySelector('.mobile-menu-button')
      if (button) {
        button.setAttribute('aria-expanded', 'false')
      }
    }
  }

  handleOutsideClick(event) {
    // Close user menu if clicking outside
    if (this.hasUserDropdownTarget && !this.userDropdownTarget.contains(event.target)) {
      this.closeUserMenu()
    }
    
    // Close notifications if clicking outside
    if (this.hasNotificationsDropdownTarget && !this.notificationsDropdownTarget.contains(event.target)) {
      this.closeNotifications()
    }
  }

  handleResize() {
    // Close mobile menu on resize to desktop
    if (window.innerWidth >= 768) {
      this.closeMobileMenu()
    }
  }
}