import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="contact-form"
export default class extends Controller {
  static targets = [
    "form",
    "nameInput", "nameError",
    "emailInput", "emailError",
    "phoneInput", "phoneError",
    "companyInput",
    "inquiryInput", "inquiryError",
    "messageInput", "messageError",
    "charCount",
    "submitButton"
  ]

  connect() {
    // Add input event listeners for real-time validation and character counting
    if (this.hasMessageInputTarget) {
      this.messageInputTarget.addEventListener('input', this.updateCharCount.bind(this))
      this.updateCharCount()
    }
    
    // Add blur event listeners for field validation
    this.addValidationListeners()
  }

  disconnect() {
    if (this.hasMessageInputTarget) {
      this.messageInputTarget.removeEventListener('input', this.updateCharCount.bind(this))
    }
  }

  addValidationListeners() {
    if (this.hasNameInputTarget) {
      this.nameInputTarget.addEventListener('blur', () => this.validateName())
    }
    
    if (this.hasEmailInputTarget) {
      this.emailInputTarget.addEventListener('blur', () => this.validateEmail())
    }
    
    if (this.hasPhoneInputTarget) {
      this.phoneInputTarget.addEventListener('blur', () => this.validatePhone())
    }
    
    if (this.hasInquiryInputTarget) {
      this.inquiryInputTarget.addEventListener('blur', () => this.validateInquiry())
    }
    
    if (this.hasMessageInputTarget) {
      this.messageInputTarget.addEventListener('blur', () => this.validateMessage())
    }
  }

  updateCharCount() {
    const length = this.messageInputTarget.value.length
    this.charCountTarget.textContent = length
    
    // Change color based on character count
    if (length > 1000) {
      this.charCountTarget.classList.add('text-red-500')
      this.charCountTarget.classList.remove('text-gray-500', 'text-yellow-500')
    } else if (length > 900) {
      this.charCountTarget.classList.add('text-yellow-500')
      this.charCountTarget.classList.remove('text-gray-500', 'text-red-500')
    } else {
      this.charCountTarget.classList.add('text-gray-500')
      this.charCountTarget.classList.remove('text-yellow-500', 'text-red-500')
    }
  }

  validateName() {
    const name = this.nameInputTarget.value.trim()
    const errorElement = this.nameErrorTarget
    
    if (name.length < 2) {
      this.showError(this.nameInputTarget, errorElement, 'Name must be at least 2 characters')
      return false
    } else if (name.length > 100) {
      this.showError(this.nameInputTarget, errorElement, 'Name must be less than 100 characters')
      return false
    } else {
      this.hideError(this.nameInputTarget, errorElement)
      return true
    }
  }

  validateEmail() {
    const email = this.emailInputTarget.value.trim()
    const errorElement = this.emailErrorTarget
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    
    if (!emailRegex.test(email)) {
      this.showError(this.emailInputTarget, errorElement, 'Please enter a valid email address')
      return false
    } else {
      this.hideError(this.emailInputTarget, errorElement)
      return true
    }
  }

  validatePhone() {
    if (!this.hasPhoneInputTarget) return true
    
    const phone = this.phoneInputTarget.value.trim()
    const errorElement = this.phoneErrorTarget
    
    if (phone === '') {
      this.hideError(this.phoneInputTarget, errorElement)
      return true
    }
    
    const phoneRegex = /^[\d\s\-\+\(\)]+$/
    
    if (!phoneRegex.test(phone)) {
      this.showError(this.phoneInputTarget, errorElement, 'Please enter a valid phone number')
      return false
    } else {
      this.hideError(this.phoneInputTarget, errorElement)
      return true
    }
  }

  validateInquiry() {
    const inquiry = this.inquiryInputTarget.value
    const errorElement = this.inquiryErrorTarget
    
    if (!inquiry || inquiry === '') {
      this.showError(this.inquiryInputTarget, errorElement, 'Please select an inquiry type')
      return false
    } else {
      this.hideError(this.inquiryInputTarget, errorElement)
      return true
    }
  }

  validateMessage() {
    const message = this.messageInputTarget.value.trim()
    const errorElement = this.messageErrorTarget
    
    if (message.length < 10) {
      this.showError(this.messageInputTarget, errorElement, 'Message must be at least 10 characters')
      return false
    } else if (message.length > 1000) {
      this.showError(this.messageInputTarget, errorElement, 'Message must be less than 1000 characters')
      return false
    } else {
      this.hideError(this.messageInputTarget, errorElement)
      return true
    }
  }

  showError(inputElement, errorElement, message) {
    inputElement.classList.add('border-red-500')
    inputElement.classList.remove('border-gray-300')
    errorElement.textContent = message
    errorElement.classList.remove('hidden')
  }

  hideError(inputElement, errorElement) {
    inputElement.classList.remove('border-red-500')
    inputElement.classList.add('border-gray-300')
    errorElement.classList.add('hidden')
  }

  validateAndSubmit(event) {
    event.preventDefault()
    
    // Run all validations
    const isNameValid = this.validateName()
    const isEmailValid = this.validateEmail()
    const isPhoneValid = this.validatePhone()
    const isInquiryValid = this.validateInquiry()
    const isMessageValid = this.validateMessage()
    
    // If all validations pass, submit the form
    if (isNameValid && isEmailValid && isPhoneValid && isInquiryValid && isMessageValid) {
      // Disable submit button and show loading state
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = 'Sending...'
      this.submitButtonTarget.classList.add('opacity-75', 'cursor-not-allowed')
      
      // Submit the form
      this.formTarget.submit()
    } else {
      // Scroll to first error
      const firstError = this.element.querySelector('.border-red-500')
      if (firstError) {
        firstError.scrollIntoView({ behavior: 'smooth', block: 'center' })
        firstError.focus()
      }
    }
  }
}