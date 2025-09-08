import { Controller } from "@hotwired/stimulus"

// Premium Dashboard controller for managing real-time updates and interactions
export default class extends Controller {
  static targets = [
    "lastUpdated", "totalLeads", "conversionRate", "activeKeywords",
    "activeIntegrations", "leadsChart", "conversionFunnel", "recentLeads",
    "keywordPerformance", "integrationStatus", "refreshText"
  ]

  static values = {
    userId: Number,
    refreshInterval: { type: Number, default: 300000 }, // 5 minutes
    autoRefresh: { type: Boolean, default: true }
  }

  connect() {
    console.log("Premium Dashboard controller connected")
    this.initializePremiumFeatures()
    this.animateInitialLoad()
    this.loadInitialData()
    this.setupTooltips()
    this.setupCounterAnimations()

    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
  }

  disconnect() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
    this.cleanupTooltips()
  }

  // Initialize premium dashboard features
  initializePremiumFeatures() {
    // Add premium loading states
    this.addPremiumLoadingStates()

    // Setup intersection observer for animations
    this.setupIntersectionObserver()

    // Initialize real-time status indicator
    this.updateRealTimeStatus()

    // Setup keyboard shortcuts
    this.setupKeyboardShortcuts()
  }

  // Setup tooltips for metric cards
  setupTooltips() {
    const tooltipElements = this.element.querySelectorAll('[data-tooltip]')
    tooltipElements.forEach(element => {
      element.addEventListener('mouseenter', this.showTooltip.bind(this))
      element.addEventListener('mouseleave', this.hideTooltip.bind(this))
    })
  }

  // Cleanup tooltips
  cleanupTooltips() {
    const tooltipElements = this.element.querySelectorAll('[data-tooltip]')
    tooltipElements.forEach(element => {
      element.removeEventListener('mouseenter', this.showTooltip.bind(this))
      element.removeEventListener('mouseleave', this.hideTooltip.bind(this))
    })
  }

  // Show tooltip
  showTooltip(event) {
    const element = event.currentTarget
    const tooltip = element.getAttribute('data-tooltip')

    if (!tooltip) return

    // Create tooltip element if it doesn't exist
    if (!element.querySelector('.premium-tooltip')) {
      const tooltipEl = document.createElement('div')
      tooltipEl.className = 'premium-tooltip absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 bg-gray-900 text-white text-sm rounded-lg opacity-0 transition-opacity duration-200 pointer-events-none z-50'
      tooltipEl.textContent = tooltip
      element.appendChild(tooltipEl)

      // Animate in
      setTimeout(() => {
        tooltipEl.classList.remove('opacity-0')
        tooltipEl.classList.add('opacity-100')
      }, 10)
    }
  }

  // Hide tooltip
  hideTooltip(event) {
    const element = event.currentTarget
    const tooltip = element.querySelector('.premium-tooltip')

    if (tooltip) {
      tooltip.classList.remove('opacity-100')
      tooltip.classList.add('opacity-0')

      setTimeout(() => {
        tooltip.remove()
      }, 200)
    }
  }

  // Animate initial dashboard load
  animateInitialLoad() {
    // Add stagger animation to metric cards
    const metricCards = this.element.querySelectorAll('.metric-card')
    metricCards.forEach((card, index) => {
      card.style.opacity = '0'
      card.style.transform = 'translateY(20px)'
      setTimeout(() => {
        card.style.transition = 'all 0.5s ease-out'
        card.style.opacity = '1'
        card.style.transform = 'translateY(0)'
      }, index * 100)
    })

    // Add fade-in animation to widgets
    const widgets = this.element.querySelectorAll('.widget-card')
    widgets.forEach((widget, index) => {
      widget.style.opacity = '0'
      widget.style.transform = 'translateY(30px)'
      setTimeout(() => {
        widget.style.transition = 'all 0.6s ease-out'
        widget.style.opacity = '1'
        widget.style.transform = 'translateY(0)'
      }, 200 + index * 150)
    })
  }

  disconnect() {
    this.stopAutoRefresh()
    this.cleanupTooltips()
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }
  }

  // Setup counter animations for metric cards
  setupCounterAnimations() {
    const counterElements = this.element.querySelectorAll('.counter-animate')
    counterElements.forEach(element => {
      this.animateCounter(element)
    })
  }

  // Animate counter from 0 to target value
  animateCounter(element) {
    const targetValue = parseInt(element.textContent.replace(/,/g, '')) || 0
    const duration = 1500 // 1.5 seconds
    const startTime = performance.now()

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)

      // Easing function for smooth animation
      const easeOutQuart = 1 - Math.pow(1 - progress, 4)
      const currentValue = Math.floor(targetValue * easeOutQuart)

      element.textContent = this.formatNumber(currentValue)

      if (progress < 1) {
        requestAnimationFrame(animate)
      } else {
        element.textContent = this.formatNumber(targetValue)
      }
    }

    requestAnimationFrame(animate)
  }

  // Format number with commas
  formatNumber(num) {
    return num.toLocaleString()
  }

  // Setup intersection observer for scroll animations
  setupIntersectionObserver() {
    if (!window.IntersectionObserver) return

    this.intersectionObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('animate-fade-in-up')
          this.intersectionObserver.unobserve(entry.target)
        }
      })
    }, {
      threshold: 0.1,
      rootMargin: '0px 0px -50px 0px'
    })

    // Observe metric cards and widgets
    const observeElements = this.element.querySelectorAll('.premium-metric-card, .premium-widget-card')
    observeElements.forEach(element => {
      this.intersectionObserver.observe(element)
    })
  }

  // Update real-time status indicator
  updateRealTimeStatus() {
    const statusIndicator = this.element.querySelector('.animate-pulse')
    if (statusIndicator) {
      // Simulate real-time activity
      setInterval(() => {
        statusIndicator.classList.remove('animate-pulse')
        setTimeout(() => {
          statusIndicator.classList.add('animate-pulse')
        }, 100)
      }, 3000)
    }
  }

  // Setup keyboard shortcuts
  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (event) => {
      // Ctrl/Cmd + R for refresh
      if ((event.ctrlKey || event.metaKey) && event.key === 'r') {
        event.preventDefault()
        this.refreshData()
      }

      // Escape to close any open modals/dropdowns
      if (event.key === 'Escape') {
        this.closeAllDropdowns()
      }
    })
  }

  // Close all open dropdowns
  closeAllDropdowns() {
    const dropdowns = this.element.querySelectorAll('[data-controller="dropdown"]')
    dropdowns.forEach(dropdown => {
      const controller = this.application.getControllerForElementAndIdentifier(dropdown, 'dropdown')
      if (controller && controller.close) {
        controller.close()
      }
    })
  }

  // Add premium loading states
  addPremiumLoadingStates() {
    const widgets = this.element.querySelectorAll('.premium-widget-card')
    widgets.forEach(widget => {
      widget.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
    })
  }

  // Manual refresh triggered by user
  refreshData() {
    this.showPremiumLoadingState()
    this.updateRefreshButtonState('loading')

    this.fetchDashboardData()
      .then(data => this.updateDashboard(data))
      .catch(error => this.handleError(error))
      .finally(() => {
        this.hidePremiumLoadingState()
        this.updateRefreshButtonState('idle')
      })
  }

  // Update refresh button state with premium animations
  updateRefreshButtonState(state) {
    if (!this.hasRefreshTextTarget) return

    const refreshButton = this.refreshTextTarget.closest('button')
    const icon = refreshButton.querySelector('svg')

    switch (state) {
      case 'loading':
        this.refreshTextTarget.textContent = 'Refreshing...'
        if (icon) {
          icon.classList.add('icon-spin')
        }
        refreshButton.disabled = true
        refreshButton.classList.add('opacity-75', 'cursor-not-allowed')
        break
      case 'idle':
        this.refreshTextTarget.textContent = 'Refresh'
        if (icon) {
          icon.classList.remove('icon-spin')
        }
        refreshButton.disabled = false
        refreshButton.classList.remove('opacity-75', 'cursor-not-allowed')
        break
      case 'success':
        this.refreshTextTarget.textContent = 'Updated!'
        setTimeout(() => {
          this.updateRefreshButtonState('idle')
        }, 2000)
        break
    }
  }

  // Premium loading state with enhanced animations
  showPremiumLoadingState() {
    // Add loading indicators to widgets
    const widgets = this.element.querySelectorAll('.premium-widget-card')
    widgets.forEach(widget => {
      widget.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
      widget.style.opacity = '0.7'
      widget.style.transform = 'scale(0.98)'

      // Add shimmer effect
      const content = widget.querySelector('.premium-widget-content')
      if (content) {
        content.classList.add('shimmer')
      }
    })

    // Add loading to metric cards
    const metricCards = this.element.querySelectorAll('.premium-metric-card')
    metricCards.forEach(card => {
      card.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
      card.style.opacity = '0.7'
      card.style.transform = 'scale(0.98)'
    })
  }

  // Hide premium loading state
  hidePremiumLoadingState() {
    // Remove loading indicators from widgets
    const widgets = this.element.querySelectorAll('.premium-widget-card')
    widgets.forEach(widget => {
      widget.style.opacity = '1'
      widget.style.transform = 'scale(1)'

      // Remove shimmer effect
      const content = widget.querySelector('.premium-widget-content')
      if (content) {
        content.classList.remove('shimmer')
      }
    })

    // Remove loading from metric cards
    const metricCards = this.element.querySelectorAll('.premium-metric-card')
    metricCards.forEach(card => {
      card.style.opacity = '1'
      card.style.transform = 'scale(1)'
    })

    // Update success state
    this.updateRefreshButtonState('success')

    // Re-animate counters
    this.setupCounterAnimations()
  }

  // Load initial dashboard data
  loadInitialData() {
    this.renderRecentLeads()
    this.renderKeywordPerformance()
    this.renderIntegrationStatus()
    this.renderConversionFunnel()
    this.initializeChart()
  }

  // Start automatic refresh
  startAutoRefresh() {
    this.refreshTimer = setInterval(() => {
      this.fetchDashboardData()
        .then(data => this.updateDashboard(data))
        .catch(error => console.error("Auto-refresh failed:", error))
    }, this.refreshIntervalValue)
  }

  // Stop automatic refresh
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  // Fetch dashboard data from server
  async fetchDashboardData() {
    const response = await fetch('/dashboard/widgets', {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    return await response.json()
  }

  // Update dashboard with new data
  updateDashboard(data) {
    this.updateLastUpdated()
    
    if (data.recent_leads) {
      this.renderRecentLeads(data.recent_leads)
    }
    
    if (data.keyword_performance) {
      this.renderKeywordPerformance(data.keyword_performance)
    }
    
    if (data.integration_status) {
      this.renderIntegrationStatus(data.integration_status)
    }
    
    if (data.conversion_metrics) {
      this.updateMetrics(data.conversion_metrics)
    }
  }

  // Update the last updated timestamp
  updateLastUpdated() {
    if (this.hasLastUpdatedTarget) {
      const now = new Date()
      this.lastUpdatedTarget.textContent = now.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit'
      })
    }
  }

  // Render recent leads widget
  renderRecentLeads(leads = []) {
    if (!this.hasRecentLeadsTarget) return

    if (leads.length === 0) {
      this.recentLeadsTarget.innerHTML = `
        <div class="p-6 text-center text-gray-500">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
          </svg>
          <p class="mt-2">No recent leads</p>
        </div>
      `
      return
    }

    const leadsHTML = leads.map(lead => `
      <div class="px-6 py-4 hover:bg-gray-50 transition-colors duration-150">
        <div class="flex items-center justify-between">
          <div class="flex-1">
            <p class="text-sm font-medium text-gray-900">${this.escapeHtml(lead.title || 'New Lead')}</p>
            <p class="text-sm text-gray-500">${this.escapeHtml(lead.keyword || 'Unknown keyword')}</p>
          </div>
          <div class="flex items-center space-x-2">
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${this.getStatusBadgeClass(lead.status)}">
              ${this.escapeHtml(lead.status || 'new')}
            </span>
            <span class="text-xs text-gray-400">${this.formatTimeAgo(lead.created_at)}</span>
          </div>
        </div>
      </div>
    `).join('')

    this.recentLeadsTarget.innerHTML = leadsHTML
  }

  // Render keyword performance widget
  renderKeywordPerformance(keywords = []) {
    if (!this.hasKeywordPerformanceTarget) return

    if (keywords.length === 0) {
      this.keywordPerformanceTarget.innerHTML = `
        <div class="text-center text-gray-500">
          <p>No keywords tracked yet</p>
        </div>
      `
      return
    }

    const keywordsHTML = keywords.map(keyword => `
      <div class="flex items-center justify-between py-3">
        <div class="flex-1">
          <p class="text-sm font-medium text-gray-900">${this.escapeHtml(keyword.term)}</p>
          <p class="text-xs text-gray-500">${keyword.mentions_count} mentions</p>
        </div>
        <div class="text-right">
          <p class="text-sm font-semibold text-gray-900">${keyword.conversion_rate}%</p>
          <p class="text-xs text-gray-500">${keyword.leads_count} leads</p>
        </div>
      </div>
    `).join('')

    this.keywordPerformanceTarget.innerHTML = keywordsHTML
  }

  // Render integration status widget
  renderIntegrationStatus(integrations = []) {
    if (!this.hasIntegrationStatusTarget) return

    if (integrations.length === 0) {
      this.integrationStatusTarget.innerHTML = `
        <div class="text-center text-gray-500">
          <p>No integrations configured</p>
        </div>
      `
      return
    }

    const integrationsHTML = integrations.map(integration => `
      <div class="flex items-center justify-between py-3">
        <div class="flex items-center">
          <div class="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center mr-3">
            ${this.getPlatformIcon(integration.platform)}
          </div>
          <div>
            <p class="text-sm font-medium text-gray-900">${this.escapeHtml(integration.platform)}</p>
            <p class="text-xs text-gray-500">Health: ${integration.health_score}%</p>
          </div>
        </div>
        <div class="flex items-center">
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${integration.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
            ${integration.status}
          </span>
        </div>
      </div>
    `).join('')

    this.integrationStatusTarget.innerHTML = integrationsHTML
  }

  // Render conversion funnel
  renderConversionFunnel(data = null) {
    if (!this.hasConversionFunnelTarget) return

    // Default funnel data if none provided
    const funnelData = data || {
      mentions: 150,
      qualified: 45,
      contacted: 30,
      converted: 12
    }

    const stages = [
      { name: 'Mentions', count: funnelData.mentions, color: 'bg-blue-500' },
      { name: 'Qualified Leads', count: funnelData.qualified, color: 'bg-indigo-500' },
      { name: 'Contacted', count: funnelData.contacted, color: 'bg-purple-500' },
      { name: 'Converted', count: funnelData.converted, color: 'bg-green-500' }
    ]

    const maxCount = Math.max(...stages.map(s => s.count))

    const funnelHTML = stages.map((stage, index) => {
      const percentage = maxCount > 0 ? (stage.count / maxCount * 100) : 0
      const conversionRate = index > 0 ? ((stage.count / stages[index - 1].count) * 100).toFixed(1) : 100

      return `
        <div class="flex items-center space-x-4">
          <div class="flex-1">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-gray-900">${stage.name}</span>
              <span class="text-sm text-gray-500">${stage.count}</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-3">
              <div class="${stage.color} h-3 rounded-full transition-all duration-500" style="width: ${percentage}%"></div>
            </div>
            ${index > 0 ? `<p class="text-xs text-gray-500 mt-1">${conversionRate}% conversion</p>` : ''}
          </div>
        </div>
      `
    }).join('')

    this.conversionFunnelTarget.innerHTML = funnelHTML
  }

  // Initialize chart placeholder
  initializeChart() {
    if (!this.hasLeadsChartTarget) return
    
    // This would integrate with a charting library like Chart.js or D3
    // For now, we'll show a placeholder
    this.leadsChartTarget.innerHTML = `
      <div class="h-64 flex items-center justify-center bg-gradient-to-r from-indigo-50 to-purple-50 rounded-lg">
        <div class="text-center">
          <div class="w-16 h-16 bg-indigo-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
            </svg>
          </div>
          <p class="text-lg font-semibold text-gray-900">Lead Analytics Chart</p>
          <p class="text-sm text-gray-500">Interactive chart will be implemented here</p>
        </div>
      </div>
    `
  }

  // Update key metrics with animation
  updateMetrics(metrics) {
    if (this.hasTotalLeadsTarget && metrics.total_leads !== undefined) {
      this.animateCounter(this.totalLeadsTarget, metrics.total_leads)
    }

    if (this.hasConversionRateTarget && metrics.conversion_rate !== undefined) {
      this.animateCounter(this.conversionRateTarget, metrics.conversion_rate, '%')
    }
  }

  // Animate counter from current value to new value
  animateCounter(element, targetValue, suffix = '') {
    const currentValue = parseInt(element.textContent) || 0
    const increment = (targetValue - currentValue) / 30
    let current = currentValue

    const timer = setInterval(() => {
      current += increment
      if ((increment > 0 && current >= targetValue) || (increment < 0 && current <= targetValue)) {
        current = targetValue
        clearInterval(timer)
      }
      element.textContent = Math.round(current) + suffix
    }, 50)

    // Add bounce animation
    element.style.transform = 'scale(1.1)'
    setTimeout(() => {
      element.style.transform = 'scale(1)'
    }, 200)
  }

  // Show loading state with animations
  showLoadingState() {
    // Add loading indicators to widgets
    const widgets = [this.recentLeadsTarget, this.keywordPerformanceTarget, this.integrationStatusTarget]
    widgets.forEach(widget => {
      if (widget) {
        widget.style.transition = 'all 0.3s ease-in-out'
        widget.style.opacity = '0.6'
        widget.style.pointerEvents = 'none'
        widget.style.transform = 'scale(0.98)'

        // Add shimmer effect
        widget.classList.add('shimmer')
      }
    })

    // Show loading spinner on refresh button
    const refreshBtn = this.element.querySelector('[data-action*="refreshData"]')
    if (refreshBtn) {
      const icon = refreshBtn.querySelector('svg')
      if (icon) {
        icon.classList.add('icon-spin')
      }
    }
  }

  // Hide loading state with animations
  hideLoadingState() {
    const widgets = [this.recentLeadsTarget, this.keywordPerformanceTarget, this.integrationStatusTarget]
    widgets.forEach(widget => {
      if (widget) {
        widget.style.transition = 'all 0.3s ease-in-out'
        widget.style.opacity = '1'
        widget.style.pointerEvents = 'auto'
        widget.style.transform = 'scale(1)'

        // Remove shimmer effect
        widget.classList.remove('shimmer')
      }
    })

    // Remove loading spinner from refresh button
    const refreshBtn = this.element.querySelector('[data-action*="refreshData"]')
    if (refreshBtn) {
      const icon = refreshBtn.querySelector('svg')
      if (icon) {
        icon.classList.remove('icon-spin')
      }
    }
  }

  // Handle errors
  handleError(error) {
    console.error("Dashboard error:", error)
    // Could show a toast notification here
  }

  // Utility methods
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  getStatusBadgeClass(status) {
    const classes = {
      'new': 'bg-blue-100 text-blue-800',
      'contacted': 'bg-yellow-100 text-yellow-800',
      'converted': 'bg-green-100 text-green-800',
      'rejected': 'bg-red-100 text-red-800'
    }
    return classes[status] || 'bg-gray-100 text-gray-800'
  }

  formatTimeAgo(dateString) {
    const date = new Date(dateString)
    const now = new Date()
    const diffInHours = Math.floor((now - date) / (1000 * 60 * 60))
    
    if (diffInHours < 1) return 'Just now'
    if (diffInHours < 24) return `${diffInHours}h ago`
    
    const diffInDays = Math.floor(diffInHours / 24)
    return `${diffInDays}d ago`
  }

  getPlatformIcon(platform) {
    const icons = {
      'twitter': '<svg class="w-4 h-4 text-blue-500" fill="currentColor" viewBox="0 0 24 24"><path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/></svg>',
      'linkedin': '<svg class="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 24 24"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>',
      'reddit': '<svg class="w-4 h-4 text-orange-500" fill="currentColor" viewBox="0 0 24 24"><path d="M12 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0zm5.01 4.744c.688 0 1.25.561 1.25 1.249a1.25 1.25 0 0 1-2.498.056l-2.597-.547-.8 3.747c1.824.07 3.48.632 4.674 1.488.308-.309.73-.491 1.207-.491.968 0 1.754.786 1.754 1.754 0 .716-.435 1.333-1.01 1.614a3.111 3.111 0 0 1 .042.52c0 2.694-3.13 4.87-7.004 4.87-3.874 0-7.004-2.176-7.004-4.87 0-.183.015-.366.043-.534A1.748 1.748 0 0 1 4.028 12c0-.968.786-1.754 1.754-1.754.463 0 .898.196 1.207.49 1.207-.883 2.878-1.43 4.744-1.487l.885-4.182a.342.342 0 0 1 .14-.197.35.35 0 0 1 .238-.042l2.906.617a1.214 1.214 0 0 1 1.108-.701zM9.25 12C8.561 12 8 12.562 8 13.25c0 .687.561 1.248 1.25 1.248.687 0 1.248-.561 1.248-1.249 0-.688-.561-1.249-1.249-1.249zm5.5 0c-.687 0-1.248.561-1.248 1.25 0 .687.561 1.248 1.249 1.248.688 0 1.249-.561 1.249-1.249 0-.687-.562-1.249-1.25-1.249zm-5.466 3.99a.327.327 0 0 0-.231.094.33.33 0 0 0 0 .463c.842.842 2.484.913 2.961.913.477 0 2.105-.056 2.961-.913a.361.361 0 0 0 .029-.463.33.33 0 0 0-.464 0c-.547.533-1.684.73-2.512.73-.828 0-1.979-.196-2.512-.73a.326.326 0 0 0-.232-.095z"/></svg>'
    }
    return icons[platform.toLowerCase()] || '<svg class="w-4 h-4 text-gray-500" fill="currentColor" viewBox="0 0 24 24"><path d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"></path></svg>'
  }
}
