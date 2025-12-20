// Contacts channel for live table updates
(function() {
  function initContactsChannel() {
    // Only run on contacts index page
    if (!document.querySelector('body.admin_contacts.index')) {
      return;
    }

    // Wait for App.cable to be available
    if (typeof App === 'undefined' || typeof App.cable === 'undefined') {
      setTimeout(initContactsChannel, 100);
      return;
    }

    // Don't create duplicate subscriptions
    if (App.contacts) {
      return;
    }

    App.contacts = App.cable.subscriptions.create("ContactsChannel", {
    connected: function() {
      console.log("Connected to ContactsChannel");
    },

    disconnected: function() {
      console.log("Disconnected from ContactsChannel");
    },

    received: function(data) {
      if (data.action === 'update') {
        this.updateContactRow(data);
      }
    },

    updateContactRow: function(data) {
      // Find the row for this contact
      var row = document.querySelector('tr[id="contact_' + data.contact_id + '"]');
      if (!row) {
        // Try finding by data attribute
        row = document.querySelector('tr[data-contact-id="' + data.contact_id + '"]');
      }
      if (!row) {
        // Try finding the row by looking at the ID cell
        var rows = document.querySelectorAll('table.index_table tbody tr');
        rows.forEach(function(r) {
          var idCell = r.querySelector('td.col-id a');
          if (idCell && idCell.textContent.trim() === String(data.contact_id)) {
            row = r;
          }
        });
      }

      if (!row) {
        console.log("Contact row not found for ID:", data.contact_id);
        return;
      }

      // Add highlight animation
      row.classList.add('contact-updated');
      setTimeout(function() {
        row.classList.remove('contact-updated');
      }, 2000);

      // Update Status column
      var statusCell = row.querySelector('td.col-status');
      if (statusCell && data.status) {
        statusCell.innerHTML = '<span class="status_tag ' + data.status_class + '">' + data.status + '</span>';
      }

      // Update Type column
      var typeCell = row.querySelector('td.col-type');
      if (typeCell) {
        if (data.device_type) {
          typeCell.innerHTML = '<span class="status_tag">' + data.device_type + '</span>';
        } else {
          typeCell.innerHTML = '<span class="empty">-</span>';
        }
      }

      // Update Line Status (RPV) column
      var lineStatusCell = row.querySelector('td.col-line_status');
      if (lineStatusCell) {
        if (data.rpv_status) {
          var rpvClass = data.rpv_status_class || 'warning';
          var rpvLabel = data.rpv_status.charAt(0).toUpperCase() + data.rpv_status.slice(1);
          lineStatusCell.innerHTML = '<span class="status_tag ' + rpvClass + '">' + rpvLabel + '</span>';
        } else {
          lineStatusCell.innerHTML = '<span class="empty">-</span>';
        }
      }

      // Update Carrier column
      var carrierCell = row.querySelector('td.col-carrier');
      if (carrierCell) {
        if (data.carrier_name) {
          carrierCell.textContent = data.carrier_name;
        } else {
          carrierCell.innerHTML = '<span class="empty">-</span>';
        }
      }

      // Update Risk column
      var riskCell = row.querySelector('td.col-risk');
      if (riskCell) {
        if (data.risk_level) {
          var riskClass = data.risk_class || 'warning';
          var riskLabel = data.risk_level === 'high' ? 'High' : (data.risk_level === 'medium' ? 'Med' : 'Low');
          riskCell.innerHTML = '<span class="status_tag ' + riskClass + '">' + riskLabel + '</span>';
        } else {
          riskCell.innerHTML = '<span class="empty">-</span>';
        }
      }

      // Update Contact column (shows business name)
      var businessCell = row.querySelector('td.col-contact');
      if (businessCell) {
        if (data.is_business && data.business_name) {
          businessCell.innerHTML = '<span class="status_tag ok">B</span> ' + data.business_name;
        } else if (data.is_business) {
          businessCell.innerHTML = '<span class="status_tag ok">B</span>';
        } else {
          businessCell.innerHTML = '<span class="empty">-</span>';
        }
      }

      console.log("Updated contact row:", data.contact_id, "status:", data.status);
    }
  });
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initContactsChannel);
  } else {
    initContactsChannel();
  }
})();
