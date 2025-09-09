# AI Lead Generation Platform - Design Guide

## 🎨 Design System Overview

This comprehensive design guide documents the visual language, component patterns, and design principles used throughout the AI Lead Generation platform, with a focus on the Analytics dashboard design system.

---

## 🎯 Design Principles

### Core Principles
1. **Data Clarity**: Complex data presented in digestible, visual formats
2. **Progressive Disclosure**: Information revealed at the right depth at the right time
3. **Consistency**: Unified design language across all platform sections
4. **Performance**: Fast-loading, responsive interfaces that handle large datasets
5. **Accessibility**: WCAG 2.1 AA compliant, inclusive design for all users

---

## 🎨 Color System

### Primary Palette

#### Brand Colors
```css
/* Primary - Indigo/Purple Gradient */
--primary-gradient: linear-gradient(to right, #6366f1, #a855f7, #ec4899);
--primary-gradient-subtle: linear-gradient(to bottom right, #f0f9ff, #faf5ff, #fdf2f8);

/* Primary Solid Colors */
--indigo-50: #eef2ff;
--indigo-100: #e0e7ff;
--indigo-200: #c7d2fe;
--indigo-300: #a5b4fc;
--indigo-400: #818cf8;
--indigo-500: #6366f1;
--indigo-600: #4f46e5;
--indigo-700: #4338ca;
--indigo-800: #3730a3;
--indigo-900: #312e81;

/* Purple */
--purple-50: #faf5ff;
--purple-100: #f3e8ff;
--purple-200: #e9d5ff;
--purple-300: #d8b4fe;
--purple-400: #c084fc;
--purple-500: #a855f7;
--purple-600: #9333ea;
--purple-700: #7e22ce;

/* Pink */
--pink-50: #fdf2f8;
--pink-100: #fce7f3;
--pink-200: #fbcfe8;
--pink-300: #f9a8d4;
--pink-400: #f472b6;
--pink-500: #ec4899;
```

### Semantic Colors

```css
/* Success */
--success-light: #d1fae5;
--success-base: #10b981;
--success-dark: #065f46;

/* Warning */
--warning-light: #fed7aa;
--warning-base: #f59e0b;
--warning-dark: #92400e;

/* Error */
--error-light: #fee2e2;
--error-base: #ef4444;
--error-dark: #991b1b;

/* Info */
--info-light: #dbeafe;
--info-base: #3b82f6;
--info-dark: #1e40af;
```

### Neutral Colors

```css
--gray-50: #f9fafb;
--gray-100: #f3f4f6;
--gray-200: #e5e7eb;
--gray-300: #d1d5db;
--gray-400: #9ca3af;
--gray-500: #6b7280;
--gray-600: #4b5563;
--gray-700: #374151;
--gray-800: #1f2937;
--gray-900: #111827;
```

---

## 📐 Typography

### Font Stack
```css
--font-primary: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
--font-mono: 'Fira Code', 'Courier New', monospace;
```

### Type Scale
```css
/* Headings */
--text-4xl: 2.25rem;    /* 36px - Page titles */
--text-3xl: 1.875rem;   /* 30px - Section headers */
--text-2xl: 1.5rem;     /* 24px - Card headers */
--text-xl: 1.25rem;     /* 20px - Subsection headers */
--text-lg: 1.125rem;    /* 18px - Large body text */

/* Body */
--text-base: 1rem;      /* 16px - Regular body text */
--text-sm: 0.875rem;    /* 14px - Small text */
--text-xs: 0.75rem;     /* 12px - Captions, labels */

/* Font Weights */
--font-light: 300;
--font-regular: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

### Typography Classes

```html
<!-- Page Title -->
<h1 class="text-3xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
  Analytics Dashboard
</h1>

<!-- Section Header -->
<h2 class="text-xl font-semibold text-gray-900">
  Performance Metrics
</h2>

<!-- Card Header -->
<h3 class="text-lg font-semibold text-gray-900">
  Conversion Rate
</h3>

<!-- Body Text -->
<p class="text-base text-gray-600">
  Track your lead generation performance
</p>

<!-- Small Text -->
<span class="text-sm text-gray-500">
  Last updated 5 minutes ago
</span>
```

---

## 🗂️ Layout System

### Grid System
```html
<!-- Container -->
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  
  <!-- Responsive Grid -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
    <!-- Grid items -->
  </div>
  
</div>
```

### Spacing Scale
```css
--space-1: 0.25rem;  /* 4px */
--space-2: 0.5rem;   /* 8px */
--space-3: 0.75rem;  /* 12px */
--space-4: 1rem;     /* 16px */
--space-5: 1.25rem;  /* 20px */
--space-6: 1.5rem;   /* 24px */
--space-8: 2rem;     /* 32px */
--space-10: 2.5rem;  /* 40px */
--space-12: 3rem;    /* 48px */
--space-16: 4rem;    /* 64px */
```

### Breakpoints
```css
--screen-sm: 640px;   /* Mobile landscape */
--screen-md: 768px;   /* Tablet */
--screen-lg: 1024px;  /* Desktop */
--screen-xl: 1280px;  /* Large desktop */
--screen-2xl: 1536px; /* Extra large desktop */
```

---

## 🧩 Component Patterns

### Cards

#### Basic Card
```html
<div class="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
  <h3 class="text-lg font-semibold text-gray-900 mb-2">Card Title</h3>
  <p class="text-gray-600">Card content goes here</p>
</div>
```

#### Metric Card
```html
<div class="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
  <div class="flex items-center justify-between">
    <div>
      <p class="text-sm font-medium text-gray-600">Total Mentions</p>
      <p class="text-2xl font-bold text-gray-900">1,234</p>
    </div>
    <div class="p-3 bg-indigo-100 rounded-xl">
      <!-- Icon -->
      <svg class="w-6 h-6 text-indigo-600">...</svg>
    </div>
  </div>
  <div class="mt-4 flex items-center text-sm">
    <span class="text-green-600 font-medium">↑ 12%</span>
    <span class="text-gray-500 ml-2">from last period</span>
  </div>
</div>
```

#### Premium Gradient Card
```html
<div class="relative overflow-hidden bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 rounded-2xl p-6 text-white">
  <div class="relative z-10">
    <h3 class="text-xl font-bold mb-2">Premium Feature</h3>
    <p class="text-white/90">Advanced analytics and insights</p>
  </div>
  <!-- Background decoration -->
  <div class="absolute -right-10 -bottom-10 w-40 h-40 bg-white/10 rounded-full blur-2xl"></div>
</div>
```

### Navigation Tabs

```html
<div class="flex space-x-1 border-b border-gray-200">
  <a href="#" class="px-4 py-2 text-sm font-medium text-indigo-600 border-b-2 border-indigo-600 bg-indigo-50 rounded-t-lg">
    Active Tab
  </a>
  <a href="#" class="px-4 py-2 text-sm font-medium text-gray-600 hover:text-gray-800 hover:bg-gray-50 rounded-t-lg">
    Inactive Tab
  </a>
</div>
```

### Buttons

#### Primary Button
```html
<button class="px-4 py-2 bg-gradient-to-r from-indigo-600 to-purple-600 text-white font-medium rounded-lg hover:from-indigo-700 hover:to-purple-700 transition-all duration-200 shadow-sm">
  Primary Action
</button>
```

#### Secondary Button
```html
<button class="px-4 py-2 bg-white text-gray-700 font-medium rounded-lg border border-gray-300 hover:bg-gray-50 transition-colors">
  Secondary Action
</button>
```

#### Ghost Button
```html
<button class="px-4 py-2 text-indigo-600 font-medium rounded-lg hover:bg-indigo-50 transition-colors">
  Ghost Action
</button>
```

### Form Elements

#### Input Field
```html
<div>
  <label class="block text-sm font-medium text-gray-700 mb-1">
    Label
  </label>
  <input type="text" 
         class="w-full rounded-lg border-gray-300 focus:border-indigo-500 focus:ring-indigo-500" 
         placeholder="Enter value">
</div>
```

#### Select Dropdown
```html
<div>
  <label class="block text-sm font-medium text-gray-700 mb-1">
    Select Option
  </label>
  <select class="w-full rounded-lg border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
    <option>Option 1</option>
    <option>Option 2</option>
  </select>
</div>
```

### Charts Container

```html
<div class="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
  <div class="flex items-center justify-between mb-4">
    <h3 class="text-lg font-semibold text-gray-900">Chart Title</h3>
    <div class="flex space-x-2">
      <!-- Chart controls -->
    </div>
  </div>
  <div class="h-64">
    <canvas id="chart"></canvas>
  </div>
</div>
```

### Tables

```html
<div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
  <div class="px-6 py-4 border-b border-gray-200">
    <h3 class="text-lg font-semibold text-gray-900">Table Title</h3>
  </div>
  <div class="overflow-x-auto">
    <table class="min-w-full divide-y divide-gray-200">
      <thead class="bg-gray-50">
        <tr>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            Column
          </th>
        </tr>
      </thead>
      <tbody class="bg-white divide-y divide-gray-200">
        <tr class="hover:bg-gray-50">
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
            Data
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</div>
```

### Loading States

```html
<!-- Skeleton Card -->
<div class="bg-white rounded-2xl shadow-sm p-6 border border-gray-100">
  <div class="animate-pulse">
    <div class="h-4 bg-gray-200 rounded w-1/4 mb-4"></div>
    <div class="h-8 bg-gray-200 rounded w-1/2 mb-2"></div>
    <div class="h-4 bg-gray-200 rounded w-3/4"></div>
  </div>
</div>

<!-- Spinner -->
<div class="flex justify-center items-center p-8">
  <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
</div>
```

### Empty States

```html
<div class="text-center py-12">
  <svg class="mx-auto h-12 w-12 text-gray-400">...</svg>
  <h3 class="mt-2 text-sm font-medium text-gray-900">No data available</h3>
  <p class="mt-1 text-sm text-gray-500">Get started by creating your first item.</p>
  <div class="mt-6">
    <button class="...">Create Item</button>
  </div>
</div>
```

---

## 📊 Data Visualization

### Chart Color Schemes

```javascript
// Primary Chart Colors
const chartColors = {
  primary: 'rgba(99, 102, 241, 0.8)',    // Indigo
  secondary: 'rgba(168, 85, 247, 0.8)',  // Purple
  tertiary: 'rgba(236, 72, 153, 0.8)',   // Pink
  success: 'rgba(16, 185, 129, 0.8)',    // Green
  warning: 'rgba(245, 158, 11, 0.8)',    // Amber
  error: 'rgba(239, 68, 68, 0.8)',       // Red
};

// Gradient Fills
const gradients = {
  primary: {
    backgroundColor: [
      'rgba(99, 102, 241, 0.2)',
      'rgba(168, 85, 247, 0.2)',
      'rgba(236, 72, 153, 0.2)'
    ],
    borderColor: [
      'rgba(99, 102, 241, 1)',
      'rgba(168, 85, 247, 1)',
      'rgba(236, 72, 153, 1)'
    ]
  }
};
```

### Chart Configuration

```javascript
// Line Chart
const lineChartConfig = {
  type: 'line',
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false
      },
      tooltip: {
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        padding: 12,
        cornerRadius: 8,
        titleFont: {
          size: 14,
          weight: '600'
        },
        bodyFont: {
          size: 13
        }
      }
    },
    scales: {
      x: {
        grid: {
          display: false
        },
        ticks: {
          font: {
            size: 12
          },
          color: '#6B7280'
        }
      },
      y: {
        grid: {
          color: 'rgba(0, 0, 0, 0.05)'
        },
        ticks: {
          font: {
            size: 12
          },
          color: '#6B7280'
        }
      }
    }
  }
};
```

---

## 🎭 Animations & Transitions

### Hover Effects

```css
/* Card Hover */
.card-hover {
  transition: all 0.3s ease;
}
.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
}

/* Button Hover */
.button-hover {
  transition: all 0.2s ease;
}
.button-hover:hover {
  transform: scale(1.02);
}
```

### Loading Animations

```css
/* Pulse */
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}
.animate-pulse {
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

/* Spin */
@keyframes spin {
  to { transform: rotate(360deg); }
}
.animate-spin {
  animation: spin 1s linear infinite;
}
```

---

## ♿ Accessibility Guidelines

### Color Contrast
- **Normal text**: Minimum 4.5:1 contrast ratio
- **Large text**: Minimum 3:1 contrast ratio
- **Interactive elements**: Minimum 3:1 contrast ratio

### Keyboard Navigation
- All interactive elements must be keyboard accessible
- Focus states must be clearly visible
- Tab order must be logical

### ARIA Labels
```html
<!-- Icon buttons -->
<button aria-label="Close dialog">
  <svg>...</svg>
</button>

<!-- Form fields -->
<input aria-label="Search keywords" placeholder="Search...">

<!-- Loading states -->
<div role="status" aria-live="polite">
  <span class="sr-only">Loading...</span>
</div>
```

### Screen Reader Support
```html
<!-- Visually hidden but screen reader accessible -->
<span class="sr-only">Additional context for screen readers</span>

<!-- Tables -->
<table>
  <caption class="sr-only">Performance metrics for the last 30 days</caption>
  ...
</table>
```

---

## 📱 Responsive Design

### Mobile-First Approach

```html
<!-- Stack on mobile, grid on desktop -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
  ...
</div>

<!-- Hide on mobile, show on desktop -->
<div class="hidden lg:block">
  ...
</div>

<!-- Different padding for different screen sizes -->
<div class="p-4 md:p-6 lg:p-8">
  ...
</div>
```

### Touch Targets
- Minimum touch target size: 44x44px
- Adequate spacing between interactive elements
- Larger tap areas for mobile devices

---

## 🎨 Design Tokens

### CSS Variables
```css
:root {
  /* Colors */
  --color-primary: #6366f1;
  --color-secondary: #a855f7;
  --color-tertiary: #ec4899;
  
  /* Spacing */
  --spacing-unit: 0.25rem;
  
  /* Border Radius */
  --radius-sm: 0.375rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
  --radius-2xl: 1.5rem;
  
  /* Shadows */
  --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  --shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  
  /* Transitions */
  --transition-fast: 150ms;
  --transition-base: 200ms;
  --transition-slow: 300ms;
}
```

---

## 🚀 Performance Guidelines

### Image Optimization
- Use WebP format with PNG/JPEG fallbacks
- Implement lazy loading for below-the-fold images
- Use responsive images with srcset

### CSS Optimization
- Use Tailwind's PurgeCSS in production
- Minimize custom CSS
- Avoid deep nesting

### JavaScript Optimization
- Use Stimulus for lightweight interactions
- Lazy load heavy JavaScript libraries
- Implement code splitting where appropriate

---

## 🔄 Component States

### Interactive States

```css
/* Default */
.component {
  background: white;
  border: 1px solid #e5e7eb;
}

/* Hover */
.component:hover {
  background: #f9fafb;
  border-color: #d1d5db;
}

/* Focus */
.component:focus {
  outline: 2px solid #6366f1;
  outline-offset: 2px;
}

/* Active */
.component:active {
  background: #f3f4f6;
}

/* Disabled */
.component:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
```

---

## 📋 Implementation Checklist

### New Component Checklist
- [ ] Follows color system
- [ ] Uses consistent spacing
- [ ] Implements proper typography scale
- [ ] Includes all interactive states
- [ ] Is keyboard accessible
- [ ] Has proper ARIA labels
- [ ] Is responsive
- [ ] Has loading states
- [ ] Has empty states
- [ ] Has error states
- [ ] Meets contrast requirements
- [ ] Has smooth transitions
- [ ] Is performant

---

## 🎯 Design Do's and Don'ts

### Do's ✅
- Use the established color palette
- Maintain consistent spacing
- Follow the typography scale
- Implement smooth transitions
- Ensure accessibility
- Design mobile-first
- Use semantic HTML
- Provide feedback for user actions

### Don'ts ❌
- Don't create new colors without extending the system
- Don't use inline styles
- Don't ignore loading states
- Don't forget error handling
- Don't skip accessibility testing
- Don't use fixed pixel values for responsive design
- Don't override Tailwind utilities unnecessarily
- Don't forget hover/focus states

---

## 📚 Resources

### Design Tools
- **Figma**: Component library and design mockups
- **Tailwind CSS**: Utility-first CSS framework
- **Heroicons**: Icon library
- **Chart.js**: Data visualization library

### Development Resources
- **Tailwind Documentation**: https://tailwindcss.com/docs
- **WCAG Guidelines**: https://www.w3.org/WAI/WCAG21/quickref/
- **Rails UI Patterns**: https://railsui.com/
- **Stimulus Handbook**: https://stimulus.hotwired.dev/handbook/introduction

---

## 🔄 Version History

- **v1.0.0** - Initial design system documentation
- Created comprehensive guide based on Analytics dashboard implementation
- Documented color system, typography, components, and patterns

---

This design guide is a living document and should be updated as the design system evolves.