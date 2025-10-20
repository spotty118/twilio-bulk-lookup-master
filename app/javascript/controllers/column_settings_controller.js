import { Controller } from "@hotwired/stimulus"
import Sortable from 'sortablejs'

export default class extends Controller {
  static targets = ["columnList"]

  connect() {
    // Initialize drag-and-drop with SortableJS
    if (this.hasColumnListTarget) {
      this.sortable = Sortable.create(this.columnListTarget, {
        handle: '.drag-handle',
        animation: 150,
        onEnd: this.updatePositions.bind(this)
      })
    }
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  updatePositions() {
    // Update hidden position inputs after drag
    const items = this.element.querySelectorAll('.column-item')
    items.forEach((item, index) => {
      const positionInput = item.querySelector('.position-input')
      if (positionInput) {
        positionInput.value = index + 1
      }
    })
  }

  resetDefaults(event) {
    event.preventDefault()

    if (confirm('Reset all columns to default settings?')) {
      // Get CSRF token
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content ||
                       document.querySelector('[name="authenticity_token"]')?.value

      fetch('/admin/contacts/reset_column_settings', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        }
      }).then(response => {
        if (response.ok) {
          window.location.reload()
        } else {
          alert('Failed to reset columns. Please try again.')
        }
      }).catch(error => {
        console.error('Error resetting columns:', error)
        alert('Failed to reset columns. Please try again.')
      })
    }
  }
}
