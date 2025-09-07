import { Controller } from "@hotwired/stimulus"

// Integration Form Controller for enhanced UX and platform-specific guidance
export default class extends Controller {
  static targets = ["helpSection", "platformInstructions"]

  connect() {
    console.log("Integration form controller connected")
    this.initializePlatformHelp()
  }

  // Handle platform selection changes
  platformChanged(event) {
    const platform = event.target.value
    this.updatePlatformInstructions(platform)
    this.updateProviderSuggestion(platform)
  }

  // Update platform-specific instructions
  updatePlatformInstructions(platform) {
    if (!this.hasPlatformInstructionsTarget) return

    const instructions = this.getPlatformInstructions(platform)
    this.platformInstructionsTarget.innerHTML = instructions
  }

  // Get platform-specific setup instructions
  getPlatformInstructions(platform) {
    const instructions = {
      twitter: `
        <div class="space-y-3">
          <h5 class="font-semibold text-blue-900">Twitter API Setup:</h5>
          <ol class="list-decimal list-inside space-y-2 text-sm">
            <li>Go to <a href="https://developer.twitter.com" target="_blank" class="text-indigo-600 hover:text-indigo-800 underline">Twitter Developer Portal</a></li>
            <li>Create a new app or use an existing one</li>
            <li>Generate API Key and Secret from the "Keys and tokens" tab</li>
            <li>Set up OAuth 2.0 if you need user authentication</li>
            <li>Note: Twitter API v2 requires elevated access for some endpoints</li>
          </ol>
          <div class="mt-3 p-3 bg-blue-100 rounded-lg">
            <p class="text-xs text-blue-800"><strong>Tip:</strong> Use "twitter_api_v2" as your provider for the latest API version.</p>
          </div>
        </div>
      `,
      linkedin: `
        <div class="space-y-3">
          <h5 class="font-semibold text-blue-900">LinkedIn API Setup:</h5>
          <ol class="list-decimal list-inside space-y-2 text-sm">
            <li>Visit <a href="https://www.linkedin.com/developers" target="_blank" class="text-indigo-600 hover:text-indigo-800 underline">LinkedIn Developers</a></li>
            <li>Create a new app in your LinkedIn Developer account</li>
            <li>Request access to the Marketing Developer Platform</li>
            <li>Get your Client ID and Client Secret from app settings</li>
            <li>Configure OAuth 2.0 redirect URLs</li>
          </ol>
          <div class="mt-3 p-3 bg-blue-100 rounded-lg">
            <p class="text-xs text-blue-800"><strong>Note:</strong> LinkedIn API access requires approval and may take several days.</p>
          </div>
        </div>
      `,
      reddit: `
        <div class="space-y-3">
          <h5 class="font-semibold text-blue-900">Reddit API Setup:</h5>
          <ol class="list-decimal list-inside space-y-2 text-sm">
            <li>Go to <a href="https://www.reddit.com/prefs/apps" target="_blank" class="text-indigo-600 hover:text-indigo-800 underline">Reddit App Preferences</a></li>
            <li>Click "Create App" or "Create Another App"</li>
            <li>Choose "script" for personal use or "web app" for production</li>
            <li>Note your Client ID (under the app name) and Client Secret</li>
            <li>Reddit uses OAuth 2.0 for authentication</li>
          </ol>
          <div class="mt-3 p-3 bg-orange-100 rounded-lg">
            <p class="text-xs text-orange-800"><strong>Rate Limits:</strong> Reddit has strict rate limits (60 requests per minute).</p>
          </div>
        </div>
      `,
      facebook: `
        <div class="space-y-3">
          <h5 class="font-semibold text-blue-900">Facebook API Setup:</h5>
          <ol class="list-decimal list-inside space-y-2 text-sm">
            <li>Visit <a href="https://developers.facebook.com" target="_blank" class="text-indigo-600 hover:text-indigo-800 underline">Facebook for Developers</a></li>
            <li>Create a new app or use an existing one</li>
            <li>Add the "Facebook Login" product to your app</li>
            <li>Get your App ID and App Secret from app settings</li>
            <li>Configure OAuth redirect URIs and permissions</li>
          </ol>
          <div class="mt-3 p-3 bg-blue-100 rounded-lg">
            <p class="text-xs text-blue-800"><strong>Review:</strong> Facebook apps require review for advanced permissions.</p>
          </div>
        </div>
      `,
      instagram: `
        <div class="space-y-3">
          <h5 class="font-semibold text-blue-900">Instagram API Setup:</h5>
          <ol class="list-decimal list-inside space-y-2 text-sm">
            <li>Use Facebook Developer Console (Instagram is owned by Meta)</li>
            <li>Create a Facebook app and add Instagram Basic Display</li>
            <li>Configure Instagram Basic Display product</li>
            <li>Get your Instagram App ID and App Secret</li>
            <li>Set up OAuth and webhook endpoints</li>
          </ol>
          <div class="mt-3 p-3 bg-purple-100 rounded-lg">
            <p class="text-xs text-purple-800"><strong>Note:</strong> Instagram API has limited public content access.</p>
          </div>
        </div>
      `,
      slack: `
        <div class="space-y-3">
          <h5 class="font-semibold text-blue-900">Slack API Setup:</h5>
          <ol class="list-decimal list-inside space-y-2 text-sm">
            <li>Go to <a href="https://api.slack.com/apps" target="_blank" class="text-indigo-600 hover:text-indigo-800 underline">Slack API Apps</a></li>
            <li>Create a new Slack app from scratch</li>
            <li>Configure OAuth & Permissions with required scopes</li>
            <li>Install the app to your workspace</li>
            <li>Copy the Bot User OAuth Token</li>
          </ol>
          <div class="mt-3 p-3 bg-green-100 rounded-lg">
            <p class="text-xs text-green-800"><strong>Scopes:</strong> You'll need channels:read and chat:write at minimum.</p>
          </div>
        </div>
      `,
      discord: `
        <div class="space-y-3">
          <h5 class="font-semibold text-blue-900">Discord API Setup:</h5>
          <ol class="list-decimal list-inside space-y-2 text-sm">
            <li>Visit <a href="https://discord.com/developers/applications" target="_blank" class="text-indigo-600 hover:text-indigo-800 underline">Discord Developer Portal</a></li>
            <li>Create a new application</li>
            <li>Go to the "Bot" section and create a bot</li>
            <li>Copy the bot token (this is your API key)</li>
            <li>Configure bot permissions and invite to servers</li>
          </ol>
          <div class="mt-3 p-3 bg-indigo-100 rounded-lg">
            <p class="text-xs text-indigo-800"><strong>Permissions:</strong> Bot needs "Read Messages" and "Send Messages" permissions.</p>
          </div>
        </div>
      `
    }

    return instructions[platform] || `
      <p class="text-sm text-blue-800">
        Select a platform above to see specific setup instructions and API requirements.
        Each platform has different authentication methods and setup procedures.
      </p>
    `
  }

  // Update provider suggestion based on platform
  updateProviderSuggestion(platform) {
    const providerField = document.querySelector('input[name="integration[provider]"]')
    if (!providerField) return

    const suggestions = {
      twitter: 'twitter_api_v2',
      linkedin: 'linkedin_api',
      reddit: 'reddit_api',
      facebook: 'facebook_graph_api',
      instagram: 'instagram_basic_display',
      slack: 'slack_web_api',
      discord: 'discord_bot_api'
    }

    if (suggestions[platform]) {
      providerField.value = suggestions[platform]
      providerField.classList.add('bg-yellow-50', 'border-yellow-300')
      
      // Remove highlight after a few seconds
      setTimeout(() => {
        providerField.classList.remove('bg-yellow-50', 'border-yellow-300')
      }, 3000)
    }
  }

  // Initialize platform help on page load
  initializePlatformHelp() {
    const platformSelect = document.querySelector('select[name="integration[platform_name]"]')
    if (platformSelect && platformSelect.value) {
      this.updatePlatformInstructions(platformSelect.value)
    }
  }

  // Test connection functionality
  async testConnection(event) {
    event.preventDefault()
    
    const button = event.target
    const originalText = button.innerHTML
    
    // Show loading state
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin w-5 h-5 mr-2" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Testing Connection...
    `

    try {
      // Collect form data
      const formData = new FormData(this.element)
      
      // Make test request (you'll need to implement this endpoint)
      const response = await fetch('/integrations/test_connection', {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        }
      })

      const result = await response.json()

      if (result.success) {
        this.showTestResult('success', 'Connection successful! Your credentials are working correctly.')
      } else {
        this.showTestResult('error', result.error || 'Connection failed. Please check your credentials.')
      }
    } catch (error) {
      this.showTestResult('error', 'Network error. Please try again.')
    } finally {
      // Restore button
      button.disabled = false
      button.innerHTML = originalText
    }
  }

  // Show test connection result
  showTestResult(type, message) {
    // Remove existing alerts
    const existingAlert = document.querySelector('.test-connection-alert')
    if (existingAlert) {
      existingAlert.remove()
    }

    const alertClass = type === 'success' ? 'bg-green-50 border-green-200 text-green-800' : 'bg-red-50 border-red-200 text-red-800'
    const iconPath = type === 'success' 
      ? 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z'
      : 'M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z'

    const alert = document.createElement('div')
    alert.className = `test-connection-alert p-4 mb-6 rounded-lg border ${alertClass}`
    alert.innerHTML = `
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${iconPath}"></path>
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm font-medium">${message}</p>
        </div>
      </div>
    `

    // Insert before the form actions
    const formActions = document.querySelector('.bg-white.rounded-2xl.shadow-xl:last-child')
    if (formActions) {
      formActions.parentNode.insertBefore(alert, formActions)
    }

    // Auto-remove after 5 seconds
    setTimeout(() => {
      alert.remove()
    }, 5000)
  }

  // Form validation
  validateForm(event) {
    const requiredFields = this.element.querySelectorAll('[required]')
    let isValid = true

    requiredFields.forEach(field => {
      if (!field.value.trim()) {
        this.showFieldError(field, 'This field is required')
        isValid = false
      } else {
        this.clearFieldError(field)
      }
    })

    if (!isValid) {
      event.preventDefault()
      this.showFormError('Please fill in all required fields before submitting.')
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
    // Implementation similar to showTestResult but for form errors
    this.showTestResult('error', message)
  }

  // Cleanup
  disconnect() {
    console.log("Integration form controller disconnected")
  }
}
