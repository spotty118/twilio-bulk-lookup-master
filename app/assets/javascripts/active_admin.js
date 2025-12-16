//= require active_admin/base

// ========================================
// Resizable Table Columns (Excel-like)
// ========================================
document.addEventListener('DOMContentLoaded', function () {
  initResizableColumns();
  initAnimatedCounters();
  initEntranceAnimations();
  initKeyboardShortcuts();

  // Re-init on Turbo navigation
  document.addEventListener('turbo:load', function () {
    initResizableColumns();
    initAnimatedCounters();
    initEntranceAnimations();
  });
});

function initResizableColumns() {
  const tables = document.querySelectorAll('.index_table, table.index_table');

  tables.forEach(function (table) {
    if (table.dataset.resizable) return; // Already initialized
    table.dataset.resizable = 'true';

    const headerCells = table.querySelectorAll('thead th');

    headerCells.forEach(function (th, index) {
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

      resizer.addEventListener('mousedown', function (e) {
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
        rows.forEach(function (row) {
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
      resizer.addEventListener('mouseenter', function () {
        resizer.style.background = 'rgba(99, 102, 241, 0.3)';
      });
      resizer.addEventListener('mouseleave', function () {
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
  table.querySelectorAll('thead th').forEach(function (th) {
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

    widths.forEach(function (width, index) {
      if (headers[index] && width > 0) {
        headers[index].style.width = width + 'px';
        headers[index].style.minWidth = width + 'px';
      }
    });
  } catch (e) {
    // Ignore parse errors
  }
}

// ========================================
// Animated Number Counters
// ========================================
function initAnimatedCounters() {
  const statNumbers = document.querySelectorAll('.stat-number, .stat-card .stat-number');

  statNumbers.forEach(function (el) {
    if (el.dataset.animated) return;
    el.dataset.animated = 'true';

    const text = el.textContent.trim();
    const match = text.match(/^([\d,]+)/);

    if (match) {
      const targetNum = parseInt(match[1].replace(/,/g, ''));
      const suffix = text.slice(match[0].length);

      if (targetNum > 0 && targetNum < 100000) {
        animateCounter(el, targetNum, suffix);
      }
    }
  });
}

function animateCounter(el, target, suffix) {
  const duration = 800;
  const startTime = performance.now();
  const startValue = 0;

  function update(currentTime) {
    const elapsed = currentTime - startTime;
    const progress = Math.min(elapsed / duration, 1);

    // Easing function (ease-out)
    const easeOut = 1 - Math.pow(1 - progress, 3);
    const currentValue = Math.floor(startValue + (target - startValue) * easeOut);

    el.textContent = currentValue.toLocaleString() + suffix;

    if (progress < 1) {
      requestAnimationFrame(update);
    }
  }

  requestAnimationFrame(update);
}

// ========================================
// Entrance Animations with Intersection Observer
// ========================================
function initEntranceAnimations() {
  const panels = document.querySelectorAll('.panel, .stat-card');

  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry, index) {
        if (entry.isIntersecting) {
          // Add staggered delay
          entry.target.style.animationDelay = (index * 0.1) + 's';
          entry.target.classList.add('fade-in-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.1 });

    panels.forEach(function (panel) {
      if (!panel.classList.contains('fade-in-visible')) {
        panel.style.opacity = '0';
        observer.observe(panel);
      }
    });
  }
}

// ========================================
// Keyboard Shortcuts
// ========================================
function initKeyboardShortcuts() {
  document.addEventListener('keydown', function (e) {
    // Don't trigger if typing in input
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

    // Cmd/Ctrl + K = Focus search
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      const search = document.querySelector('#q_raw_phone_number_or_formatted_phone_number_or_business_name_cont');
      if (search) {
        search.focus();
        search.select();
      }
    }

    // Cmd/Ctrl + D = Toggle dark mode
    if ((e.metaKey || e.ctrlKey) && e.key === 'd') {
      e.preventDefault();
      const toggleBtn = document.getElementById('theme-toggle-btn');
      if (toggleBtn) toggleBtn.click();
    }

    // ? = Show keyboard shortcuts (future)
    if (e.key === '?' && !e.shiftKey) {
      // Could show a shortcuts modal here
    }
  });
}

// Add CSS for fade-in-visible
const style = document.createElement('style');
style.textContent = `
  .fade-in-visible {
    animation: fadeInUp 0.5s ease-out forwards !important;
    opacity: 1 !important;
  }
  
  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
`;
document.head.appendChild(style);
