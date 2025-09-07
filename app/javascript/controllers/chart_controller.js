import { Controller } from "@hotwired/stimulus"

// Chart controller for data visualization using CSS-based charts
export default class extends Controller {
  static targets = ["container"]
  static values = { 
    type: String,
    data: Object,
    options: Object
  }

  connect() {
    this.renderChart()
  }

  dataValueChanged() {
    this.renderChart()
  }

  renderChart() {
    if (!this.hasContainerTarget || !this.dataValue) return

    switch (this.typeValue) {
      case 'line':
        this.renderLineChart()
        break
      case 'bar':
        this.renderBarChart()
        break
      case 'donut':
        this.renderDonutChart()
        break
      case 'area':
        this.renderAreaChart()
        break
      default:
        this.renderLineChart()
    }
  }

  renderLineChart() {
    const data = this.dataValue
    if (!data.datasets || !data.labels) return

    const maxValue = Math.max(...data.datasets[0].data)
    const minValue = Math.min(...data.datasets[0].data)
    const range = maxValue - minValue || 1

    // Create SVG-based line chart
    const svgHTML = `
      <div class="relative h-64 w-full">
        <svg class="w-full h-full" viewBox="0 0 400 200" preserveAspectRatio="none">
          <!-- Grid lines -->
          <defs>
            <pattern id="grid" width="40" height="20" patternUnits="userSpaceOnUse">
              <path d="M 40 0 L 0 0 0 20" fill="none" stroke="#f3f4f6" stroke-width="1"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />
          
          <!-- Data line -->
          <polyline
            fill="none"
            stroke="url(#gradient)"
            stroke-width="3"
            stroke-linecap="round"
            stroke-linejoin="round"
            points="${this.generateLinePoints(data.datasets[0].data, maxValue, minValue)}"
          />
          
          <!-- Data points -->
          ${this.generateDataPoints(data.datasets[0].data, maxValue, minValue)}
          
          <!-- Gradient definition -->
          <defs>
            <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" style="stop-color:#6366f1;stop-opacity:1" />
              <stop offset="100%" style="stop-color:#8b5cf6;stop-opacity:1" />
            </linearGradient>
          </defs>
        </svg>
        
        <!-- Y-axis labels -->
        <div class="absolute left-0 top-0 h-full flex flex-col justify-between text-xs text-gray-500 -ml-8">
          <span>${maxValue}</span>
          <span>${Math.round((maxValue + minValue) / 2)}</span>
          <span>${minValue}</span>
        </div>
        
        <!-- X-axis labels -->
        <div class="absolute bottom-0 left-0 w-full flex justify-between text-xs text-gray-500 mt-2">
          ${data.labels.map(label => `<span class="transform -rotate-45 origin-top-left">${label}</span>`).join('')}
        </div>
      </div>
    `

    this.containerTarget.innerHTML = svgHTML
  }

  renderBarChart() {
    const data = this.dataValue
    if (!data.datasets || !data.labels) return

    const maxValue = Math.max(...data.datasets[0].data)
    const colors = ['bg-blue-500', 'bg-indigo-500', 'bg-purple-500', 'bg-pink-500', 'bg-red-500']

    const barsHTML = data.labels.map((label, index) => {
      const value = data.datasets[0].data[index]
      const height = (value / maxValue) * 100
      const color = colors[index % colors.length]

      return `
        <div class="flex flex-col items-center space-y-2">
          <div class="relative w-12 h-32 bg-gray-200 rounded-t-lg overflow-hidden">
            <div class="${color} absolute bottom-0 w-full transition-all duration-1000 ease-out rounded-t-lg" 
                 style="height: ${height}%"
                 data-value="${value}">
            </div>
          </div>
          <span class="text-xs text-gray-600 text-center">${label}</span>
          <span class="text-xs font-semibold text-gray-900">${value}</span>
        </div>
      `
    }).join('')

    this.containerTarget.innerHTML = `
      <div class="flex items-end justify-center space-x-4 h-64 p-4">
        ${barsHTML}
      </div>
    `
  }

  renderDonutChart() {
    const data = this.dataValue
    if (!data.datasets || !data.labels) return

    const total = data.datasets[0].data.reduce((sum, value) => sum + value, 0)
    const colors = ['#6366f1', '#8b5cf6', '#ec4899', '#ef4444', '#f59e0b']
    
    let cumulativePercentage = 0
    const segments = data.labels.map((label, index) => {
      const value = data.datasets[0].data[index]
      const percentage = (value / total) * 100
      const startAngle = cumulativePercentage * 3.6 // Convert to degrees
      const endAngle = (cumulativePercentage + percentage) * 3.6
      
      cumulativePercentage += percentage

      return {
        label,
        value,
        percentage: percentage.toFixed(1),
        color: colors[index % colors.length],
        startAngle,
        endAngle
      }
    })

    const segmentsHTML = segments.map((segment, index) => `
      <div class="flex items-center space-x-3 py-2">
        <div class="w-4 h-4 rounded-full" style="background-color: ${segment.color}"></div>
        <div class="flex-1">
          <div class="flex justify-between">
            <span class="text-sm font-medium text-gray-900">${segment.label}</span>
            <span class="text-sm text-gray-500">${segment.percentage}%</span>
          </div>
          <span class="text-xs text-gray-500">${segment.value} items</span>
        </div>
      </div>
    `).join('')

    this.containerTarget.innerHTML = `
      <div class="flex items-center space-x-8">
        <div class="relative w-32 h-32">
          <svg class="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="40" fill="none" stroke="#f3f4f6" stroke-width="8"/>
            ${this.generateDonutSegments(segments)}
          </svg>
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="text-center">
              <div class="text-lg font-bold text-gray-900">${total}</div>
              <div class="text-xs text-gray-500">Total</div>
            </div>
          </div>
        </div>
        <div class="flex-1 space-y-1">
          ${segmentsHTML}
        </div>
      </div>
    `
  }

  renderAreaChart() {
    const data = this.dataValue
    if (!data.datasets || !data.labels) return

    const maxValue = Math.max(...data.datasets[0].data)
    const minValue = Math.min(...data.datasets[0].data)

    const svgHTML = `
      <div class="relative h-64 w-full">
        <svg class="w-full h-full" viewBox="0 0 400 200" preserveAspectRatio="none">
          <!-- Grid -->
          <defs>
            <pattern id="areaGrid" width="40" height="20" patternUnits="userSpaceOnUse">
              <path d="M 40 0 L 0 0 0 20" fill="none" stroke="#f3f4f6" stroke-width="1"/>
            </pattern>
            <linearGradient id="areaGradient" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" style="stop-color:#6366f1;stop-opacity:0.3" />
              <stop offset="100%" style="stop-color:#6366f1;stop-opacity:0.05" />
            </linearGradient>
          </defs>
          <rect width="100%" height="100%" fill="url(#areaGrid)" />
          
          <!-- Area fill -->
          <polygon
            fill="url(#areaGradient)"
            points="${this.generateAreaPoints(data.datasets[0].data, maxValue, minValue)}"
          />
          
          <!-- Line -->
          <polyline
            fill="none"
            stroke="#6366f1"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            points="${this.generateLinePoints(data.datasets[0].data, maxValue, minValue)}"
          />
        </svg>
        
        <!-- Labels -->
        <div class="absolute bottom-0 left-0 w-full flex justify-between text-xs text-gray-500 mt-2">
          ${data.labels.map(label => `<span>${label}</span>`).join('')}
        </div>
      </div>
    `

    this.containerTarget.innerHTML = svgHTML
  }

  // Helper methods
  generateLinePoints(data, maxValue, minValue) {
    const range = maxValue - minValue || 1
    const width = 400
    const height = 200
    const stepX = width / (data.length - 1)

    return data.map((value, index) => {
      const x = index * stepX
      const y = height - ((value - minValue) / range) * height
      return `${x},${y}`
    }).join(' ')
  }

  generateAreaPoints(data, maxValue, minValue) {
    const linePoints = this.generateLinePoints(data, maxValue, minValue)
    const firstPoint = linePoints.split(' ')[0].split(',')
    const lastPoint = linePoints.split(' ').pop().split(',')
    
    return `${firstPoint[0]},200 ${linePoints} ${lastPoint[0]},200`
  }

  generateDataPoints(data, maxValue, minValue) {
    const range = maxValue - minValue || 1
    const width = 400
    const height = 200
    const stepX = width / (data.length - 1)

    return data.map((value, index) => {
      const x = index * stepX
      const y = height - ((value - minValue) / range) * height
      return `<circle cx="${x}" cy="${y}" r="4" fill="#6366f1" stroke="white" stroke-width="2"/>`
    }).join('')
  }

  generateDonutSegments(segments) {
    const radius = 40
    const circumference = 2 * Math.PI * radius
    let cumulativePercentage = 0

    return segments.map(segment => {
      const strokeDasharray = `${(segment.percentage / 100) * circumference} ${circumference}`
      const strokeDashoffset = -cumulativePercentage / 100 * circumference
      cumulativePercentage += parseFloat(segment.percentage)

      return `
        <circle 
          cx="50" 
          cy="50" 
          r="${radius}" 
          fill="none" 
          stroke="${segment.color}" 
          stroke-width="8"
          stroke-dasharray="${strokeDasharray}"
          stroke-dashoffset="${strokeDashoffset}"
          class="transition-all duration-1000 ease-out"
        />
      `
    }).join('')
  }

  // Update chart with new data
  updateData(newData) {
    this.dataValue = newData
    this.renderChart()
  }

  // Animate chart entrance
  animateIn() {
    const elements = this.containerTarget.querySelectorAll('[data-animate]')
    elements.forEach((el, index) => {
      setTimeout(() => {
        el.style.opacity = '1'
        el.style.transform = 'translateY(0)'
      }, index * 100)
    })
  }
}
