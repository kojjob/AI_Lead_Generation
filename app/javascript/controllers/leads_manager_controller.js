import { Controller } from "@hotwired/stimulus"

// Leads Manager Controller for bulk operations and interactive functionality
export default class extends Controller {
  static targets = [
    "bulkActions", "selectedCount", "selectedIds", "bulkActionSelect", "bulkActionButton",
    "selectAllCheckbox", "leadCheckbox"
  ]

  connect() {
    console.log("Leads manager controller connected")
    this.selectedLeads = new Set()
    this.updateBulkActionsVisibility()
  }

  // Toggle select all checkbox
  toggleSelectAll(event) {
    const isChecked = event.target.checked
    
    this.leadCheckboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
      const leadId = checkbox.value
      
      if (isChecked) {
        this.selectedLeads.add(leadId)
      } else {
        this.selectedLeads.delete(leadId)
      }
    })
    
    this.updateBulkActions()
  }

  // Toggle individual lead selection
  toggleSelect(event) {
    const leadId = event.target.value
    const isChecked = event.target.checked
    
    if (isChecked) {
      this.selectedLeads.add(leadId)
    } else {
      this.selectedLeads.delete(leadId)
    }
    
    this.updateSelectAllState()
    this.updateBulkActions()
  }

  // Update select all checkbox state based on individual selections
  updateSelectAllState() {
    if (!this.hasSelectAllCheckboxTarget) return
    
    const totalCheckboxes = this.leadCheckboxTargets.length
    const selectedCount = this.selectedLeads.size
    
    if (selectedCount === 0) {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = false
    } else if (selectedCount === totalCheckboxes) {
      this.selectAllCheckboxTarget.checked = true
      this.selectAllCheckboxTarget.indeterminate = false
    } else {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = true
    }
  }

  // Update bulk actions UI
  updateBulkActions() {
    const selectedCount = this.selectedLeads.size
    
    // Update selected count display
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = selectedCount
    }
    
    // Update hidden field with selected IDs
    if (this.hasSelectedIdsTarget) {
      this.selectedIdsTarget.value = Array.from(this.selectedLeads).join(',')
    }
    
    // Update bulk actions visibility and button state
    this.updateBulkActionsVisibility()
    this.updateBulkActionButton()
  }

  // Show/hide bulk actions bar
  updateBulkActionsVisibility() {
    if (!this.hasBulkActionsTarget) return
    
    const selectedCount = this.selectedLeads.size
    
    if (selectedCount > 0) {
      this.bulkActionsTarget.style.display = 'block'
      this.animateIn(this.bulkActionsTarget)
    } else {
      this.animateOut(this.bulkActionsTarget)
    }
  }

  // Update bulk action button state
  updateBulkActionButton() {
    if (!this.hasBulkActionButtonTarget || !this.hasBulkActionSelectTarget) return
    
    const selectedCount = this.selectedLeads.size
    const hasAction = this.bulkActionSelectTarget.value !== ''
    
    this.bulkActionButtonTarget.disabled = selectedCount === 0 || !hasAction
  }

  // Handle bulk action selection change
  bulkActionChanged() {
    this.updateBulkActionButton()
  }

  // Clear all selections
  clearSelections() {
    this.selectedLeads.clear()
    
    // Uncheck all checkboxes
    this.leadCheckboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    
    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = false
    }
    
    this.updateBulkActions()
  }

  // Quick actions for individual leads
  qualifyLead(event) {
    const leadId = event.params.leadId
    this.performQuickAction(leadId, 'qualify')
  }

  contactLead(event) {
    const leadId = event.params.leadId
    this.performQuickAction(leadId, 'contact')
  }

  convertLead(event) {
    const leadId = event.params.leadId
    this.performQuickAction(leadId, 'convert')
  }

  // Perform quick action on individual lead
  performQuickAction(leadId, action) {
    const row = document.querySelector(`tr[data-lead-id="${leadId}"]`)
    if (!row) return
    
    // Add loading state
    this.addLoadingState(row)
    
    // Create form and submit
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = `/leads/${leadId}/${action}`
    
    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      const csrfInput = document.createElement('input')
      csrfInput.type = 'hidden'
      csrfInput.name = 'authenticity_token'
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)
    }
    
    document.body.appendChild(form)
    form.submit()
  }

  // Add loading state to table row
  addLoadingState(row) {
    row.style.opacity = '0.6'
    row.style.pointerEvents = 'none'
    
    // Add spinner to actions cell
    const actionsCell = row.querySelector('td:last-child')
    if (actionsCell) {
      const spinner = document.createElement('div')
      spinner.className = 'inline-flex items-center'
      spinner.innerHTML = `
        <svg class="animate-spin h-4 w-4 text-indigo-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      `
      actionsCell.appendChild(spinner)
    }
  }

  // Filter management
  applyFilters() {
    // This would be handled by form submission
    console.log("Applying filters...")
  }

  clearFilters() {
    // Clear all filter inputs
    const filterForm = this.element.querySelector('form')
    if (filterForm) {
      const inputs = filterForm.querySelectorAll('input[type="text"], select')
      inputs.forEach(input => {
        if (input.type === 'text') {
          input.value = ''
        } else if (input.tagName === 'SELECT') {
          input.selectedIndex = 0
        }
      })
      
      // Submit form to apply cleared filters
      filterForm.submit()
    }
  }

  // Search functionality
  performSearch(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      const form = event.target.closest('form')
      if (form) {
        form.submit()
      }
    }
  }

  // Export functionality
  exportLeads(format = 'csv') {
    const selectedIds = Array.from(this.selectedLeads)
    let exportUrl = `/leads/export.${format}`
    
    if (selectedIds.length > 0) {
      const params = new URLSearchParams()
      selectedIds.forEach(id => params.append('lead_ids[]', id))
      exportUrl += `?${params.toString()}`
    }
    
    window.location.href = exportUrl
  }

  // Animation helpers
  animateIn(element) {
    element.style.opacity = '0'
    element.style.transform = 'translateY(-10px)'
    element.style.transition = 'all 0.3s ease-out'
    
    requestAnimationFrame(() => {
      element.style.opacity = '1'
      element.style.transform = 'translateY(0)'
    })
  }

  animateOut(element) {
    element.style.transition = 'all 0.3s ease-in'
    element.style.opacity = '0'
    element.style.transform = 'translateY(-10px)'
    
    setTimeout(() => {
      element.style.display = 'none'
    }, 300)
  }

  // Keyboard shortcuts
  handleKeydown(event) {
    // Ctrl/Cmd + A to select all
    if ((event.ctrlKey || event.metaKey) && event.key === 'a') {
      event.preventDefault()
      if (this.hasSelectAllCheckboxTarget) {
        this.selectAllCheckboxTarget.checked = true
        this.toggleSelectAll({ target: this.selectAllCheckboxTarget })
      }
    }
    
    // Escape to clear selections
    if (event.key === 'Escape') {
      this.clearSelections()
    }
  }

  // Real-time updates (if using ActionCable)
  handleLeadUpdate(data) {
    const leadId = data.lead_id
    const row = document.querySelector(`tr[data-lead-id="${leadId}"]`)
    
    if (row && data.status) {
      // Update status badge
      const statusCell = row.querySelector('td:nth-child(4) span')
      if (statusCell) {
        statusCell.textContent = data.status.humanize()
        statusCell.className = `inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-${data.status_color}-100 text-${data.status_color}-800`
      }
    }
  }

  // Cleanup
  disconnect() {
    console.log("Leads manager controller disconnected")
    this.selectedLeads.clear()
  }
}
