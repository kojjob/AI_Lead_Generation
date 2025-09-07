import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-validation"
export default class extends Controller {
  static targets = ["email", "password", "passwordConfirmation", "submit", "error"]

  connect() {
    console.log("Form validation controller connected")
    this.hasInteracted = false // Track if user has interacted with form
    this.setupValidation()
    // Don't disable submit button initially
  }

  setupValidation() {
    // Email validation
    if (this.hasEmailTarget) {
      this.emailTarget.addEventListener("input", () => this.validateEmail())
      this.emailTarget.addEventListener("blur", () => this.validateEmail(true))
    }

    // Password validation
    if (this.hasPasswordTarget) {
      this.passwordTarget.addEventListener("input", () => this.validatePassword())
      this.passwordTarget.addEventListener("blur", () => this.validatePassword(true))
    }

    // Password confirmation validation
    if (this.hasPasswordConfirmationTarget) {
      this.passwordConfirmationTarget.addEventListener("input", () => this.validatePasswordConfirmation())
      this.passwordConfirmationTarget.addEventListener("blur", () => this.validatePasswordConfirmation(true))
    }

    // Form submission
    this.element.addEventListener("submit", (event) => this.handleSubmit(event))
  }

  validateEmail(showError = false) {
    if (!this.hasEmailTarget) return true

    const email = this.emailTarget.value.trim()
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    let isValid = true
    let errorMessage = ""

    // Mark as interacted when user types something
    if (email.length > 0) {
      this.hasInteracted = true
    }

    if (email.length === 0) {
      isValid = false
      errorMessage = "Email is required"
    } else if (!emailRegex.test(email)) {
      isValid = false
      errorMessage = "Please enter a valid email address"
    }

    if (showError || email.length > 0) {
      this.setFieldState(this.emailTarget, isValid, errorMessage)
    }

    return isValid
  }

  validatePassword(showError = false) {
    if (!this.hasPasswordTarget) return true

    const password = this.passwordTarget.value
    let isValid = true
    let errorMessage = ""

    // Mark as interacted when user types something
    if (password.length > 0) {
      this.hasInteracted = true
    }

    // For login forms (no password confirmation field), just check if password exists
    // For signup forms (has password confirmation), enforce minimum length
    const isSignupForm = this.hasPasswordConfirmationTarget
    
    if (password.length === 0) {
      isValid = false
      errorMessage = "Password is required"
    } else if (isSignupForm && password.length < 8) {
      isValid = false
      errorMessage = "Password must be at least 8 characters"
    }

    if (showError || password.length > 0) {
      this.setFieldState(this.passwordTarget, isValid, errorMessage)
    }

    // Also validate confirmation if it exists and has content
    if (this.hasPasswordConfirmationTarget && this.passwordConfirmationTarget.value.length > 0) {
      this.validatePasswordConfirmation()
    }

    return isValid
  }

  validatePasswordConfirmation(showError = false) {
    if (!this.hasPasswordConfirmationTarget || !this.hasPasswordTarget) return true

    const password = this.passwordTarget.value
    const confirmation = this.passwordConfirmationTarget.value
    let isValid = true
    let errorMessage = ""

    if (confirmation.length === 0) {
      isValid = false
      errorMessage = "Password confirmation is required"
    } else if (password !== confirmation) {
      isValid = false
      errorMessage = "Passwords do not match"
    }

    if (showError || confirmation.length > 0) {
      this.setFieldState(this.passwordConfirmationTarget, isValid, errorMessage)
    }

    return isValid
  }

  setFieldState(field, isValid, errorMessage = "") {
    const wrapper = field.closest(".relative") || field.parentElement
    const existingError = wrapper.querySelector(".field-error")

    // Remove existing error message
    if (existingError) {
      existingError.remove()
    }

    if (isValid) {
      // Valid state
      field.classList.remove("border-red-500", "focus:border-red-500", "focus:ring-red-500")
      field.classList.add("border-green-500", "focus:border-green-500", "focus:ring-green-500")
      
      // Add checkmark icon
      this.addValidIcon(wrapper)
    } else {
      // Invalid state
      field.classList.remove("border-green-500", "focus:border-green-500", "focus:ring-green-500")
      field.classList.add("border-red-500", "focus:border-red-500", "focus:ring-red-500")
      
      // Remove valid icon
      this.removeValidIcon(wrapper)
      
      // Add error message
      if (errorMessage) {
        const errorEl = document.createElement("p")
        errorEl.className = "field-error mt-1 text-xs text-red-600 animate-fade-in"
        errorEl.textContent = errorMessage
        wrapper.appendChild(errorEl)
      }
    }

    this.validateForm()
  }

  addValidIcon(wrapper) {
    // Remove existing icon if any
    this.removeValidIcon(wrapper)
    
    const icon = document.createElement("div")
    icon.className = "valid-icon absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none"
    icon.innerHTML = `
      <svg class="h-5 w-5 text-green-500 animate-fade-in" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 0016 0zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
      </svg>
    `
    
    // For password fields with toggle button, insert before the toggle
    const toggleButton = wrapper.querySelector('[data-password-toggle-target="button"]')
    if (toggleButton) {
      icon.style.right = "2.5rem"
    }
    
    wrapper.appendChild(icon)
  }

  removeValidIcon(wrapper) {
    const icon = wrapper.querySelector(".valid-icon")
    if (icon) {
      icon.remove()
    }
  }

  validateForm() {
    const emailValid = this.validateEmail(false)
    const passwordValid = this.validatePassword(false)
    const confirmationValid = !this.hasPasswordConfirmationTarget || this.validatePasswordConfirmation(false)

    const isFormValid = emailValid && passwordValid && confirmationValid

    // Only manage submit button state after user has interacted with the form
    if (this.hasSubmitTarget && this.hasInteracted) {
      if (isFormValid) {
        this.submitTarget.disabled = false
        this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
        this.submitTarget.classList.add("hover:scale-[1.02]")
      } else {
        this.submitTarget.disabled = true
        this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
        this.submitTarget.classList.remove("hover:scale-[1.02]")
      }
    }

    return isFormValid
  }

  handleSubmit(event) {
    // Validate all fields with error display
    const emailValid = this.validateEmail(true)
    const passwordValid = this.validatePassword(true)
    const confirmationValid = !this.hasPasswordConfirmationTarget || this.validatePasswordConfirmation(true)

    if (!emailValid || !passwordValid || !confirmationValid) {
      event.preventDefault()
      
      // Shake the form to indicate error
      this.element.classList.add("animate-shake")
      setTimeout(() => {
        this.element.classList.remove("animate-shake")
      }, 500)
      
      // Focus first invalid field
      if (!emailValid && this.hasEmailTarget) {
        this.emailTarget.focus()
      } else if (!passwordValid && this.hasPasswordTarget) {
        this.passwordTarget.focus()
      } else if (!confirmationValid && this.hasPasswordConfirmationTarget) {
        this.passwordConfirmationTarget.focus()
      }
      
      return false
    }

    // Show loading state on submit button
    if (this.hasSubmitTarget) {
      const originalText = this.submitTarget.textContent
      this.submitTarget.disabled = true
      this.submitTarget.innerHTML = `
        <svg class="animate-spin h-5 w-5 mx-auto" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      `
    }

    return true
  }

  // Listen to password strength events
  passwordStrengthChanged(event) {
    if (event.detail && this.hasPasswordTarget) {
      const { isValid } = event.detail
      if (!isValid && this.passwordTarget.value.length > 0) {
        this.setFieldState(this.passwordTarget, false, "Password is too weak")
      }
    }
  }

  disconnect() {
    console.log("Form validation controller disconnected")
  }
}