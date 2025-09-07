import { Controller } from "@hotwired/stimulus"

// Keyword Wizard Controller for step-by-step keyword creation
export default class extends Controller {
  static targets = [
    "form", "stepContent", "step", "stepIndicator", "currentStepDisplay",
    "prevButton", "nextButton", "submitButton",
    "keywordInput", "keywordValidation", "validIcon", "invalidIcon", "keywordFeedback",
    "suggestions", "suggestionsList", "typeCheck", "typeTooltip",
    "platformCheck", "platformSummary", "activeToggle", "activeToggleIndicator",
    "notificationCheck", "priorityCheck", "analysisPreview",
    "competitionScore", "competitionBar", "volumeScore", "volumeBar",
    "opportunityScore", "opportunityBar", "analysisNote",
    "reviewKeyword", "reviewType", "reviewStatus", "reviewPlatforms",
    "reviewNotifications", "reviewPriority", "reviewNotes",
    "expectedMentions", "expectedLeads", "expectedOpportunities"
  ]
  
  static values = { 
    currentStep: { type: Number, default: 1 },
    totalSteps: { type: Number, default: 4 }
  }

  connect() {
    console.log("Keyword wizard controller connected")
    this.updateStepDisplay()
    this.initializeForm()
  }

  // Initialize form state
  initializeForm() {
    this.updateNavigationButtons()
    this.initializeActiveToggle()
    this.updateTypeSelection()
    this.updatePlatformSelection()
    this.updateNotificationFrequency()
    this.updatePrioritySelection()
  }

  // Step Navigation
  nextStep() {
    if (this.currentStepValue < this.totalStepsValue) {
      if (this.validateCurrentStep()) {
        this.currentStepValue++
        this.updateStepDisplay()
        this.updateNavigationButtons()
        this.updateReviewData()
        this.scrollToTop()
      }
    }
  }

  previousStep() {
    if (this.currentStepValue > 1) {
      this.currentStepValue--
      this.updateStepDisplay()
      this.updateNavigationButtons()
      this.scrollToTop()
    }
  }

  // Update step display
  updateStepDisplay() {
    // Update step indicators
    this.stepTargets.forEach((step, index) => {
      const stepNumber = index + 1
      const stepElement = step.querySelector('span')
      const stepLabel = step.querySelector('span:last-child')
      
      if (stepNumber < this.currentStepValue) {
        // Completed step
        step.classList.remove('text-gray-500')
        step.classList.add('text-indigo-600')
        stepElement.classList.remove('bg-gray-100', 'text-gray-500')
        stepElement.classList.add('bg-indigo-600', 'text-white')
        if (stepLabel) {
          stepLabel.classList.remove('text-gray-500')
          stepLabel.classList.add('text-indigo-600')
        }
      } else if (stepNumber === this.currentStepValue) {
        // Current step
        step.classList.remove('text-gray-500')
        step.classList.add('text-indigo-600')
        stepElement.classList.remove('bg-gray-100', 'text-gray-500')
        stepElement.classList.add('bg-indigo-600', 'text-white')
        if (stepLabel) {
          stepLabel.classList.remove('text-gray-500')
          stepLabel.classList.add('text-indigo-600')
        }
      } else {
        // Future step
        step.classList.remove('text-indigo-600')
        step.classList.add('text-gray-500')
        stepElement.classList.remove('bg-indigo-600', 'text-white')
        stepElement.classList.add('bg-gray-100', 'text-gray-500')
        if (stepLabel) {
          stepLabel.classList.remove('text-indigo-600')
          stepLabel.classList.add('text-gray-500')
        }
      }
    })

    // Show/hide step content
    this.stepContentTargets.forEach((content, index) => {
      const stepNumber = index + 1
      if (stepNumber === this.currentStepValue) {
        content.classList.remove('hidden')
      } else {
        content.classList.add('hidden')
      }
    })

    // Update step indicators in header and navigation
    if (this.hasStepIndicatorTarget) {
      this.stepIndicatorTarget.textContent = this.currentStepValue
    }
    if (this.hasCurrentStepDisplayTarget) {
      this.currentStepDisplayTarget.textContent = this.currentStepValue
    }
  }

  // Update navigation buttons
  updateNavigationButtons() {
    // Previous button
    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.disabled = this.currentStepValue === 1
    }

    // Next/Submit button
    if (this.hasNextButtonTarget && this.hasSubmitButtonTarget) {
      if (this.currentStepValue === this.totalStepsValue) {
        this.nextButtonTarget.classList.add('hidden')
        this.submitButtonTarget.classList.remove('hidden')
      } else {
        this.nextButtonTarget.classList.remove('hidden')
        this.submitButtonTarget.classList.add('hidden')
      }
    }
  }

  // Validate current step
  validateCurrentStep() {
    switch (this.currentStepValue) {
      case 1:
        return this.validateKeywordStep()
      case 2:
        return this.validatePlatformStep()
      case 3:
        return this.validateSettingsStep()
      case 4:
        return true // Review step doesn't need validation
      default:
        return true
    }
  }

  validateKeywordStep() {
    const keyword = this.keywordInputTarget.value.trim()
    if (!keyword) {
      this.showKeywordError("Please enter a keyword")
      return false
    }
    if (keyword.length < 3) {
      this.showKeywordError("Keyword must be at least 3 characters long")
      return false
    }
    this.showKeywordSuccess("Keyword looks good!")
    return true
  }

  validatePlatformStep() {
    const selectedPlatforms = this.getSelectedPlatforms()
    if (selectedPlatforms.length === 0) {
      this.showError("Please select at least one platform")
      return false
    }
    return true
  }

  validateSettingsStep() {
    // Settings step is optional, always valid
    return true
  }

  // Keyword validation and analysis
  validateKeyword() {
    const keyword = this.keywordInputTarget.value.trim()
    
    if (keyword.length === 0) {
      this.hideKeywordValidation()
      return
    }

    if (keyword.length < 3) {
      this.showKeywordError("Too short")
      return
    }

    if (keyword.length > 100) {
      this.showKeywordError("Too long")
      return
    }

    this.showKeywordSuccess("Valid keyword")
    this.generateSuggestions(keyword)
  }

  analyzeKeyword() {
    const keyword = this.keywordInputTarget.value.trim()
    if (keyword.length < 3) return

    // Simulate keyword analysis
    this.updateAnalysisPreview(keyword)
  }

  updateAnalysisPreview(keyword) {
    // Simulate analysis based on keyword characteristics
    const wordCount = keyword.split(' ').length
    const length = keyword.length
    
    // Mock competition score (0-100)
    const competition = Math.min(Math.max(30 + (wordCount * 10) - (length * 0.5), 10), 90)
    
    // Mock volume score (0-100)
    const volume = Math.min(Math.max(50 - (wordCount * 5) + (length * 0.3), 10), 85)
    
    // Mock opportunity score (inverse of competition)
    const opportunity = Math.min(Math.max(100 - competition + (volume * 0.2), 20), 95)

    this.updateAnalysisMetric('competition', competition, 'Competition Level')
    this.updateAnalysisMetric('volume', volume, 'Search Volume')
    this.updateAnalysisMetric('opportunity', opportunity, 'Opportunity Score')

    if (this.hasAnalysisNoteTarget) {
      let note = "Good keyword potential"
      if (competition > 70) note = "High competition - consider more specific terms"
      else if (volume < 30) note = "Low volume - consider broader terms"
      else if (opportunity > 80) note = "Excellent opportunity!"
      
      this.analysisNoteTarget.textContent = note
    }
  }

  updateAnalysisMetric(type, score, label) {
    const scoreTarget = this[`${type}ScoreTarget`]
    const barTarget = this[`${type}BarTarget`]
    
    if (scoreTarget) {
      scoreTarget.textContent = Math.round(score)
    }
    
    if (barTarget) {
      barTarget.style.width = `${score}%`
    }
  }

  generateSuggestions(keyword) {
    // Mock keyword suggestions
    const suggestions = [
      `${keyword} services`,
      `${keyword} consultant`,
      `${keyword} expert`,
      `${keyword} help`,
      `${keyword} solution`
    ].filter(s => s !== keyword)

    this.displaySuggestions(suggestions.slice(0, 3))
  }

  displaySuggestions(suggestions) {
    if (!this.hasSuggestionsTarget || !this.hasSuggestionsListTarget) return

    if (suggestions.length === 0) {
      this.suggestionsTarget.classList.add('hidden')
      return
    }

    const suggestionsHTML = suggestions.map(suggestion => `
      <button type="button" 
              class="inline-flex items-center px-3 py-1.5 rounded-full text-sm bg-indigo-100 text-indigo-700 hover:bg-indigo-200 transition-colors duration-200"
              data-action="click->keyword-wizard#applySuggestion"
              data-suggestion="${suggestion}">
        ${suggestion}
      </button>
    `).join('')

    this.suggestionsListTarget.innerHTML = suggestionsHTML
    this.suggestionsTarget.classList.remove('hidden')
  }

  applySuggestion(event) {
    const suggestion = event.currentTarget.dataset.suggestion
    this.keywordInputTarget.value = suggestion
    this.validateKeyword()
    this.analyzeKeyword()
  }

  // Platform selection
  updatePlatformSelection() {
    const selectedPlatforms = this.getSelectedPlatforms()
    this.updatePlatformSummary(selectedPlatforms)
    this.updatePlatformChecks()
  }

  getSelectedPlatforms() {
    const checkboxes = this.element.querySelectorAll('input[name="keyword[platforms][]"]:checked')
    return Array.from(checkboxes).map(cb => cb.value)
  }

  updatePlatformSummary(platforms) {
    if (!this.hasPlatformSummaryTarget) return

    if (platforms.length === 0) {
      this.platformSummaryTarget.innerHTML = '<p class="text-gray-600">Select at least one platform to monitor your keyword</p>'
      return
    }

    const platformNames = platforms.map(p => p.charAt(0).toUpperCase() + p.slice(1)).join(', ')
    this.platformSummaryTarget.innerHTML = `
      <div class="flex items-center space-x-2">
        <svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
        </svg>
        <span class="text-gray-900">Monitoring on: <strong>${platformNames}</strong></span>
      </div>
      <p class="text-sm text-gray-600 mt-2">Your keyword will be tracked across ${platforms.length} platform${platforms.length > 1 ? 's' : ''}</p>
    `
  }

  updatePlatformChecks() {
    const checkboxes = this.element.querySelectorAll('input[name="keyword[platforms][]"]')
    checkboxes.forEach(checkbox => {
      const label = checkbox.closest('label')
      const checkIcon = label.querySelector('[data-keyword-wizard-target="platformCheck"]')
      
      if (checkbox.checked) {
        label.classList.add('border-indigo-500', 'bg-indigo-50')
        if (checkIcon) checkIcon.classList.remove('opacity-0')
      } else {
        label.classList.remove('border-indigo-500', 'bg-indigo-50')
        if (checkIcon) checkIcon.classList.add('opacity-0')
      }
    })
  }

  // Active toggle
  initializeActiveToggle() {
    const checkbox = this.element.querySelector('input[name="keyword[active]"]')
    if (checkbox && this.hasActiveToggleTarget) {
      this.updateActiveToggleDisplay(checkbox.checked)
    }
  }

  toggleActive() {
    const checkbox = this.element.querySelector('input[name="keyword[active]"]')
    if (checkbox) {
      checkbox.checked = !checkbox.checked
      this.updateActiveToggleDisplay(checkbox.checked)
    }
  }

  updateActiveToggleDisplay(isActive) {
    if (!this.hasActiveToggleTarget || !this.hasActiveToggleIndicatorTarget) return

    if (isActive) {
      this.activeToggleTarget.classList.remove('bg-gray-200')
      this.activeToggleTarget.classList.add('bg-indigo-600')
      this.activeToggleTarget.setAttribute('aria-checked', 'true')
      this.activeToggleIndicatorTarget.classList.remove('translate-x-0')
      this.activeToggleIndicatorTarget.classList.add('translate-x-5')
    } else {
      this.activeToggleTarget.classList.remove('bg-indigo-600')
      this.activeToggleTarget.classList.add('bg-gray-200')
      this.activeToggleTarget.setAttribute('aria-checked', 'false')
      this.activeToggleIndicatorTarget.classList.remove('translate-x-5')
      this.activeToggleIndicatorTarget.classList.add('translate-x-0')
    }
  }

  // Form field updates
  updateTypeSelection() {
    this.updateRadioSelection('type', this.typeCheckTargets)
  }

  updateNotificationFrequency() {
    this.updateRadioSelection('notification_frequency', this.notificationCheckTargets)
  }

  updatePrioritySelection() {
    this.updateRadioSelection('priority', this.priorityCheckTargets)
  }

  updateRadioSelection(fieldName, checkTargets) {
    const radios = this.element.querySelectorAll(`input[name="keyword[${fieldName}]"]`)
    radios.forEach((radio, index) => {
      const label = radio.closest('label')
      const checkIcon = checkTargets[index]
      
      if (radio.checked) {
        label.classList.add('border-indigo-500', 'bg-indigo-50')
        if (checkIcon) checkIcon.classList.remove('opacity-0')
      } else {
        label.classList.remove('border-indigo-500', 'bg-indigo-50')
        if (checkIcon) checkIcon.classList.add('opacity-0')
      }
    })
  }

  // Review step data update
  updateReviewData() {
    if (this.currentStepValue !== 4) return

    // Update keyword details
    if (this.hasReviewKeywordTarget) {
      this.reviewKeywordTarget.textContent = this.keywordInputTarget.value || '-'
    }

    // Update type
    if (this.hasReviewTypeTarget) {
      const selectedType = this.element.querySelector('input[name="keyword[type]"]:checked')
      this.reviewTypeTarget.textContent = selectedType ? selectedType.nextElementSibling.textContent : '-'
    }

    // Update status
    if (this.hasReviewStatusTarget) {
      const isActive = this.element.querySelector('input[name="keyword[active]"]').checked
      this.reviewStatusTarget.innerHTML = isActive 
        ? '<span class="bg-green-100 text-green-800">Active</span>'
        : '<span class="bg-gray-100 text-gray-800">Inactive</span>'
    }

    // Update platforms
    if (this.hasReviewPlatformsTarget) {
      const platforms = this.getSelectedPlatforms()
      const platformBadges = platforms.map(platform => 
        `<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">${platform.charAt(0).toUpperCase() + platform.slice(1)}</span>`
      ).join('')
      this.reviewPlatformsTarget.innerHTML = platformBadges || '<span class="text-gray-500">None selected</span>'
    }

    // Update notifications
    if (this.hasReviewNotificationsTarget) {
      const selectedNotification = this.element.querySelector('input[name="keyword[notification_frequency]"]:checked')
      this.reviewNotificationsTarget.textContent = selectedNotification ? selectedNotification.nextElementSibling.textContent : '-'
    }

    // Update priority
    if (this.hasReviewPriorityTarget) {
      const selectedPriority = this.element.querySelector('input[name="keyword[priority]"]:checked')
      this.reviewPriorityTarget.textContent = selectedPriority ? selectedPriority.nextElementSibling.textContent : '-'
    }

    // Update notes
    if (this.hasReviewNotesTarget) {
      const notes = this.element.querySelector('textarea[name="keyword[notes]"]').value.trim()
      this.reviewNotesTarget.textContent = notes || 'None'
    }

    // Update expected results
    this.updateExpectedResults()
  }

  updateExpectedResults() {
    const platforms = this.getSelectedPlatforms()
    const keyword = this.keywordInputTarget.value.trim()
    
    // Mock calculations based on platforms and keyword
    const baseMentions = platforms.length * 5
    const mentions = Math.max(baseMentions + Math.floor(Math.random() * 10), 1)
    const leads = Math.max(Math.floor(mentions * 0.2), 1)
    const opportunities = Math.max(Math.floor(leads * 0.4), 1)

    if (this.hasExpectedMentionsTarget) {
      this.expectedMentionsTarget.textContent = `~${mentions}`
    }
    if (this.hasExpectedLeadsTarget) {
      this.expectedLeadsTarget.textContent = `~${leads}-${leads + 2}`
    }
    if (this.hasExpectedOpportunitiesTarget) {
      this.expectedOpportunitiesTarget.textContent = `~${opportunities}-${opportunities + 1}`
    }
  }

  // Bulk import
  showBulkImport() {
    // This would open a modal for bulk import
    console.log("Bulk import functionality would be implemented here")
  }

  // Form submission
  handleSubmit(event) {
    if (!this.validateCurrentStep()) {
      event.preventDefault()
      return false
    }
    
    // Show loading state
    this.showSubmitLoading()
  }

  showSubmitLoading() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Creating Keyword...
      `
    }
  }

  // Utility methods
  showKeywordError(message) {
    this.showKeywordValidation(message, 'error')
  }

  showKeywordSuccess(message) {
    this.showKeywordValidation(message, 'success')
  }

  showKeywordValidation(message, type) {
    if (!this.hasKeywordFeedbackTarget) return

    const isError = type === 'error'
    this.keywordFeedbackTarget.textContent = message
    this.keywordFeedbackTarget.className = `mt-2 text-sm ${isError ? 'text-red-600' : 'text-green-600'}`

    if (this.hasValidIconTarget && this.hasInvalidIconTarget) {
      if (isError) {
        this.validIconTarget.classList.add('hidden')
        this.invalidIconTarget.classList.remove('hidden')
      } else {
        this.invalidIconTarget.classList.add('hidden')
        this.validIconTarget.classList.remove('hidden')
      }
    }
  }

  hideKeywordValidation() {
    if (this.hasKeywordFeedbackTarget) {
      this.keywordFeedbackTarget.textContent = ''
    }
    if (this.hasValidIconTarget && this.hasInvalidIconTarget) {
      this.validIconTarget.classList.add('hidden')
      this.invalidIconTarget.classList.add('hidden')
    }
  }

  showError(message) {
    // This would show a toast or alert
    console.error(message)
  }

  scrollToTop() {
    this.element.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
}
