import { Controller } from "@hotwired/stimulus"

// Lead Form Controller for interactive form functionality
export default class extends Controller {
  static targets = ["radioGroup", "radioOption"]

  connect() {
    console.log("Lead form controller connected")
    this.initializeRadioGroups()
  }

  // Initialize radio button groups with visual feedback
  initializeRadioGroups() {
    this.updateAllRadioGroups()
  }

  // Handle radio button changes
  radioChanged(event) {
    const radioButton = event.target
    const groupName = radioButton.name
    
    // Update visual state for this radio group
    this.updateRadioGroup(groupName)
  }

  // Update visual state for all radio groups
  updateAllRadioGroups() {
    const radioGroups = {}
    
    // Group radio buttons by name
    this.element.querySelectorAll('input[type="radio"]').forEach(radio => {
      const groupName = radio.name
      if (!radioGroups[groupName]) {
        radioGroups[groupName] = []
      }
      radioGroups[groupName].push(radio)
    })
    
    // Update each group
    Object.keys(radioGroups).forEach(groupName => {
      this.updateRadioGroup(groupName)
    })
  }

  // Update visual state for a specific radio group
  updateRadioGroup(groupName) {
    const radios = this.element.querySelectorAll(`input[name="${groupName}"]`)
    
    radios.forEach(radio => {
      const label = radio.closest('label')
      const checkIcon = label.querySelector('svg')
      
      if (radio.checked) {
        // Selected state
        label.classList.add('border-indigo-500', 'bg-indigo-50')
        label.classList.remove('border-gray-300', 'bg-white')
        if (checkIcon) {
          checkIcon.classList.remove('opacity-0')
          checkIcon.classList.add('opacity-100')
        }
      } else {
        // Unselected state
        label.classList.remove('border-indigo-500', 'bg-indigo-50')
        label.classList.add('border-gray-300', 'bg-white')
        if (checkIcon) {
          checkIcon.classList.add('opacity-0')
          checkIcon.classList.remove('opacity-100')
        }
      }
    })
  }

  // Form validation
  validateForm(event) {
    const form = event.target
    const requiredFields = form.querySelectorAll('[required]')
    let isValid = true
    
    requiredFields.forEach(field => {
      if (!field.value.trim()) {
        this.showFieldError(field, 'This field is required')
        isValid = false
      } else {
        this.clearFieldError(field)
      }
    })
    
    // Email validation
    const emailField = form.querySelector('input[type="email"]')
    if (emailField && emailField.value) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      if (!emailRegex.test(emailField.value)) {
        this.showFieldError(emailField, 'Please enter a valid email address')
        isValid = false
      }
    }
    
    // Qualification score validation
    const scoreField = form.querySelector('input[name*="qualification_score"]')
    if (scoreField && scoreField.value) {
      const score = parseInt(scoreField.value)
      if (score < 0 || score > 100) {
        this.showFieldError(scoreField, 'Score must be between 0 and 100')
        isValid = false
      }
    }
    
    if (!isValid) {
      event.preventDefault()
      this.showFormError('Please fix the errors above before submitting')
    }
    
    return isValid
  }

  // Show field-specific error
  showFieldError(field, message) {
    this.clearFieldError(field)
    
    field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.remove('border-gray-300', 'focus:border-indigo-500', 'focus:ring-indigo-500')
    
    const errorDiv = document.createElement('div')
    errorDiv.className = 'mt-1 text-sm text-red-600 field-error'
    errorDiv.textContent = message
    
    field.parentNode.appendChild(errorDiv)
  }

  // Clear field error
  clearFieldError(field) {
    field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.add('border-gray-300', 'focus:border-indigo-500', 'focus:ring-indigo-500')
    
    const existingError = field.parentNode.querySelector('.field-error')
    if (existingError) {
      existingError.remove()
    }
  }

  // Show form-level error
  showFormError(message) {
    this.clearFormError()
    
    const errorDiv = document.createElement('div')
    errorDiv.className = 'bg-red-50 border border-red-200 rounded-lg p-4 mb-6 form-error'
    errorDiv.innerHTML = `
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm text-red-800">${message}</p>
        </div>
      </div>
    `
    
    const formContent = this.element.querySelector('.px-6.py-8, .px-8')
    if (formContent) {
      formContent.insertBefore(errorDiv, formContent.firstChild)
    }
  }

  // Clear form error
  clearFormError() {
    const existingError = this.element.querySelector('.form-error')
    if (existingError) {
      existingError.remove()
    }
  }

  // Auto-save functionality (optional)
  autoSave() {
    const formData = new FormData(this.element)
    const leadId = this.element.querySelector('input[name*="id"]')?.value
    
    if (leadId) {
      // Only auto-save for existing leads
      fetch(`/leads/${leadId}`, {
        method: 'PATCH',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        }
      })
      .then(response => {
        if (response.ok) {
          this.showAutoSaveSuccess()
        }
      })
      .catch(error => {
        console.error('Auto-save failed:', error)
      })
    }
  }

  // Show auto-save success indicator
  showAutoSaveSuccess() {
    const indicator = document.createElement('div')
    indicator.className = 'fixed top-4 right-4 bg-green-100 border border-green-200 rounded-lg p-3 text-sm text-green-800 z-50 auto-save-indicator'
    indicator.innerHTML = `
      <div class="flex items-center">
        <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
        </svg>
        Changes saved
      </div>
    `
    
    document.body.appendChild(indicator)
    
    setTimeout(() => {
      indicator.remove()
    }, 3000)
  }

  // Handle form submission
  submitForm(event) {
    if (!this.validateForm(event)) {
      return false
    }
    
    // Show loading state
    const submitButton = this.element.querySelector('input[type="submit"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.value = 'Saving...'
      submitButton.classList.add('opacity-75', 'cursor-not-allowed')
    }
    
    return true
  }

  // Smart field interactions
  handleEmailChange(event) {
    const email = event.target.value
    const nameField = this.element.querySelector('input[name*="name"]')
    
    // Auto-populate name from email if name is empty
    if (email && !nameField.value) {
      const emailParts = email.split('@')[0]
      const nameParts = emailParts.split(/[._-]/)
      const suggestedName = nameParts.map(part => 
        part.charAt(0).toUpperCase() + part.slice(1)
      ).join(' ')
      
      nameField.value = suggestedName
      nameField.classList.add('bg-yellow-50', 'border-yellow-300')
      
      // Remove highlight after a few seconds
      setTimeout(() => {
        nameField.classList.remove('bg-yellow-50', 'border-yellow-300')
      }, 3000)
    }
  }

  // Handle company field changes
  handleCompanyChange(event) {
    const company = event.target.value
    const emailField = this.element.querySelector('input[type="email"]')
    
    // Suggest email domain based on company name
    if (company && emailField && !emailField.value.includes('@')) {
      const domain = company.toLowerCase().replace(/[^a-z0-9]/g, '') + '.com'
      // This is just a suggestion - don't auto-fill
    }
  }

  // Keyboard shortcuts
  handleKeydown(event) {
    // Ctrl/Cmd + S to save
    if ((event.ctrlKey || event.metaKey) && event.key === 's') {
      event.preventDefault()
      this.element.requestSubmit()
    }
    
    // Escape to cancel
    if (event.key === 'Escape') {
      const cancelLink = this.element.querySelector('a[href*="leads"]')
      if (cancelLink) {
        window.location.href = cancelLink.href
      }
    }
  }

  // Cleanup
  disconnect() {
    console.log("Lead form controller disconnected")
    this.clearFormError()
  }
}
