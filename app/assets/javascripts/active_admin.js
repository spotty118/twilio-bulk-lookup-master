//= require active_admin/base

// ========================================
// Resizable Table Columns (Excel-like)
// ========================================
document.addEventListener('DOMContentLoaded', function() {
  initResizableColumns();
  
  // Re-init on Turbo navigation
  document.addEventListener('turbo:load', initResizableColumns);
});

function initResizableColumns() {
  const tables = document.querySelectorAll('.index_table, table.index_table');
  
  tables.forEach(function(table) {
    if (table.dataset.resizable) return; // Already initialized
    table.dataset.resizable = 'true';
    
    const headerCells = table.querySelectorAll('thead th');
    
    headerCells.forEach(function(th, index) {
      // Skip last column (usually actions)
      if (index === headerCells.length - 1) return;
      
      // Create resize handle
      const resizer = document.createElement('div');
      resizer.className = 'col-resizer';
      resizer.style.cssText = `
        position: absolute;
        right: 0;
        top: 0;
        bottom: 0;
        width: 6px;
        cursor: col-resize;
        background: transparent;
        z-index: 10;
      `;
      
      // Make th position relative for handle positioning
      th.style.position = 'relative';
      th.appendChild(resizer);
      
      // Drag state
      let startX, startWidth;
      
      resizer.addEventListener('mousedown', function(e) {
        e.preventDefault();
        startX = e.pageX;
        startWidth = th.offsetWidth;
        
        // Add active state
        resizer.style.background = '#6366f1';
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
      });
      
      function onMouseMove(e) {
        const diff = e.pageX - startX;
        const newWidth = Math.max(50, startWidth + diff);
        th.style.width = newWidth + 'px';
        th.style.minWidth = newWidth + 'px';
        
        // Also set column width on all td cells in this column
        const rows = table.querySelectorAll('tbody tr');
        rows.forEach(function(row) {
          const cell = row.cells[index];
          if (cell) {
            cell.style.width = newWidth + 'px';
            cell.style.minWidth = newWidth + 'px';
          }
        });
      }
      
      function onMouseUp() {
        resizer.style.background = 'transparent';
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
        
        // Save column widths to localStorage
        saveColumnWidths(table);
      }
      
      // Hover effect
      resizer.addEventListener('mouseenter', function() {
        resizer.style.background = 'rgba(99, 102, 241, 0.3)';
      });
      resizer.addEventListener('mouseleave', function() {
        if (document.body.style.cursor !== 'col-resize') {
          resizer.style.background = 'transparent';
        }
      });
    });
    
    // Restore saved column widths
    restoreColumnWidths(table);
  });
}

function getTableKey(table) {
  // Generate unique key based on page path and column count
  return 'colWidths_' + window.location.pathname + '_' + table.querySelectorAll('thead th').length;
}

function saveColumnWidths(table) {
  const widths = [];
  table.querySelectorAll('thead th').forEach(function(th) {
    widths.push(th.offsetWidth);
  });
  localStorage.setItem(getTableKey(table), JSON.stringify(widths));
}

function restoreColumnWidths(table) {
  const saved = localStorage.getItem(getTableKey(table));
  if (!saved) return;
  
  try {
    const widths = JSON.parse(saved);
    const headers = table.querySelectorAll('thead th');
    
    widths.forEach(function(width, index) {
      if (headers[index] && width > 0) {
        headers[index].style.width = width + 'px';
        headers[index].style.minWidth = width + 'px';
      }
    });
  } catch (e) {
    // Ignore parse errors
  }
}
