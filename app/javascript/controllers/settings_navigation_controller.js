import { Controller } from "@hotwired/stimulus"

// Settings page navigation controller
export default class extends Controller {
  static targets = ["section", "navItem"]

  connect() {
    // Show the first section by default
    this.showSection({ currentTarget: { dataset: { section: 'notifications' } } })
  }

  showSection(event) {
    const sectionName = event.currentTarget.dataset.section
    
    // Hide all sections
    this.sectionTargets.forEach(section => {
      section.classList.add('hidden')
    })
    
    // Show selected section
    const selectedSection = document.getElementById(`${sectionName}-section`)
    if (selectedSection) {
      selectedSection.classList.remove('hidden')
      
      // Add entrance animation
      selectedSection.style.opacity = '0'
      selectedSection.style.transform = 'translateY(10px)'
      
      requestAnimationFrame(() => {
        selectedSection.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out'
        selectedSection.style.opacity = '1'
        selectedSection.style.transform = 'translateY(0)'
      })
    }
    
    // Update navigation styling
    const navItems = this.element.querySelectorAll('.settings-nav-item')
    navItems.forEach(item => {
      item.classList.remove('bg-indigo-50', 'text-indigo-700', 'border', 'border-indigo-200')
      item.classList.add('text-gray-700')
    })
    
    // Add active styling to clicked item
    event.currentTarget.classList.remove('text-gray-700')
    event.currentTarget.classList.add('bg-indigo-50', 'text-indigo-700', 'border', 'border-indigo-200')
  }
}