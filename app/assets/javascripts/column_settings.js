// Column Settings - Vanilla JavaScript for Asset Pipeline
(function() {
  'use strict';

  // Wait for DOM to be ready
  document.addEventListener('DOMContentLoaded', function() {
    const columnSettingsContainer = document.getElementById('column-settings-container');

    if (!columnSettingsContainer) {
      return; // Not on column settings page
    }

    const columnList = document.getElementById('column-list');
    let sortable = null;

    // Initialize SortableJS for drag-and-drop
    if (typeof Sortable !== 'undefined' && columnList) {
      sortable = Sortable.create(columnList, {
        handle: '.drag-handle',
        animation: 150,
        onEnd: updatePositions
      });
    }

    // Update position inputs after drag
    function updatePositions() {
      const items = columnList.querySelectorAll('.column-item');
      items.forEach(function(item, index) {
        const positionInput = item.querySelector('.position-input');
        if (positionInput) {
          positionInput.value = index + 1;
        }
      });
    }

    // Handle reset to defaults
    const resetButton = columnSettingsContainer.querySelector('[data-action="reset"]');
    if (resetButton) {
      resetButton.addEventListener('click', function(event) {
        event.preventDefault();

        if (confirm('Reset all columns to default settings?')) {
          // Get CSRF token
          const csrfToken = document.querySelector('[name="csrf-token"]')?.content ||
                           document.querySelector('[name="authenticity_token"]')?.value;

          fetch('/admin/contacts/reset_column_settings', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': csrfToken
            }
          }).then(function(response) {
            if (response.ok) {
              window.location.reload();
            } else {
              alert('Failed to reset columns. Please try again.');
            }
          }).catch(function(error) {
            console.error('Error resetting columns:', error);
            alert('Failed to reset columns. Please try again.');
          });
        }
      });
    }

    // Handle checkbox changes for visibility
    const checkboxes = columnSettingsContainer.querySelectorAll('.visibility-checkbox');
    checkboxes.forEach(function(checkbox) {
      checkbox.addEventListener('change', function() {
        // Could add visual feedback here
        const columnItem = this.closest('.column-item');
        if (columnItem) {
          columnItem.style.opacity = this.checked ? '1' : '0.6';
        }
      });
    });

    console.log('Column settings initialized');
  });
})();
