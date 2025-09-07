import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password-strength"
export default class extends Controller {
  static targets = ["password", "bar", "label", "suggestions"]

  connect() {
    console.log("Password strength controller connected")
    this.bindEvents()
    this.checkStrength() // Initial check
  }

  bindEvents() {
    if (this.hasPasswordTarget) {
      // Use input event for real-time feedback
      this.passwordTarget.addEventListener("input", () => this.checkStrength())
      this.passwordTarget.addEventListener("focus", () => this.showSuggestions())
      this.passwordTarget.addEventListener("blur", () => this.hideSuggestionsDelayed())
    }
  }

  checkStrength() {
    if (!this.hasPasswordTarget) return

    const password = this.passwordTarget.value
    const analysis = this.analyzePassword(password)
    
    this.updateStrengthBar(analysis.strength, analysis.colorClass)
    this.updateLabel(analysis.label)
    this.updateSuggestions(analysis.suggestions)
    
    // Dispatch custom event for other components to listen to
    this.dispatch("strengthChanged", { 
      detail: { 
        strength: analysis.strength, 
        label: analysis.label,
        isValid: analysis.strength >= 50 
      } 
    })
  }

  analyzePassword(password) {
    let strength = 0
    let label = "Enter a password"
    let colorClass = "bg-gray-300"
    let suggestions = []

    if (password.length === 0) {
      return { strength, label, colorClass, suggestions: ["Start typing to see password strength"] }
    }

    // Length scoring
    if (password.length >= 8) {
      strength += 20
    } else {
      suggestions.push(`Add ${8 - password.length} more characters`)
    }
    
    if (password.length >= 12) {
      strength += 15
    }
    
    if (password.length >= 16) {
      strength += 10
    }

    // Character variety scoring and suggestions
    const hasLowercase = /[a-z]/.test(password)
    const hasUppercase = /[A-Z]/.test(password)
    const hasNumbers = /[0-9]/.test(password)
    const hasSpecialChars = /[^a-zA-Z0-9]/.test(password)
    
    if (hasLowercase) strength += 15
    else suggestions.push("Add lowercase letters")
    
    if (hasUppercase) strength += 15
    else suggestions.push("Add uppercase letters")
    
    if (hasNumbers) strength += 15
    else suggestions.push("Add numbers")
    
    if (hasSpecialChars) strength += 10
    else suggestions.push("Add special characters (!@#$%^&*)")

    // Pattern checks
    if (this.hasSequentialNumbers(password)) {
      strength -= 10
      suggestions.push("Avoid sequential numbers (123, 789)")
    }
    
    if (this.hasRepeatingCharacters(password)) {
      strength -= 10
      suggestions.push("Avoid repeating characters (aaa, 111)")
    }
    
    if (this.hasCommonPatterns(password)) {
      strength -= 15
      suggestions.push("Avoid common patterns")
    }

    // Ensure strength is between 0 and 100
    strength = Math.max(0, Math.min(100, strength))

    // Determine label and color based on strength
    if (strength < 25) {
      label = "Very weak"
      colorClass = "bg-red-600"
    } else if (strength < 40) {
      label = "Weak"
      colorClass = "bg-red-500"
    } else if (strength < 55) {
      label = "Fair"
      colorClass = "bg-yellow-500"
    } else if (strength < 70) {
      label = "Good"
      colorClass = "bg-blue-500"
    } else if (strength < 85) {
      label = "Strong"
      colorClass = "bg-green-500"
    } else {
      label = "Very strong"
      colorClass = "bg-green-600"
      suggestions = ["Excellent password!"]
    }

    return { strength, label, colorClass, suggestions }
  }

  hasSequentialNumbers(password) {
    return /012|123|234|345|456|567|678|789|890|987|876|765|654|543|432|321|210/.test(password)
  }

  hasRepeatingCharacters(password) {
    return /(.)\1{2,}/.test(password)
  }

  hasCommonPatterns(password) {
    const commonPatterns = [
      'password', 'qwerty', 'abc123', '123456', 'admin', 'letmein',
      'welcome', 'monkey', 'dragon', 'master', 'superman'
    ]
    const lowerPassword = password.toLowerCase()
    return commonPatterns.some(pattern => lowerPassword.includes(pattern))
  }

  updateStrengthBar(strength, colorClass) {
    if (!this.hasBarTarget) return

    // Smooth animation
    this.barTarget.style.width = `${strength}%`
    
    // Remove all color classes
    const colorClasses = ['bg-red-600', 'bg-red-500', 'bg-yellow-500', 'bg-blue-500', 'bg-green-500', 'bg-green-600', 'bg-gray-300']
    colorClasses.forEach(cls => this.barTarget.classList.remove(cls))
    
    // Add new color class
    this.barTarget.classList.add(colorClass)
  }

  updateLabel(label) {
    if (!this.hasLabelTarget) return
    
    this.labelTarget.textContent = label
    
    // Add animation effect
    this.labelTarget.classList.add('animate-pulse')
    setTimeout(() => {
      this.labelTarget.classList.remove('animate-pulse')
    }, 500)
  }

  updateSuggestions(suggestions) {
    if (!this.hasSuggestionsTarget) return
    
    const html = suggestions.map(suggestion => 
      `<li class="flex items-start">
        <svg class="w-4 h-4 text-gray-400 mr-1 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
        </svg>
        <span class="text-xs">${suggestion}</span>
      </li>`
    ).join('')
    
    this.suggestionsTarget.innerHTML = html
  }

  showSuggestions() {
    if (this.hasSuggestionsTarget) {
      this.suggestionsTarget.classList.remove('hidden')
    }
  }

  hideSuggestionsDelayed() {
    // Delay hiding to allow for interaction
    setTimeout(() => {
      if (this.hasSuggestionsTarget && !this.passwordTarget.matches(':focus')) {
        this.suggestionsTarget.classList.add('hidden')
      }
    }, 200)
  }

  disconnect() {
    console.log("Password strength controller disconnected")
    if (this.hasPasswordTarget) {
      this.passwordTarget.removeEventListener("input", () => this.checkStrength())
    }
  }
}