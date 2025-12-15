// Theme Toggle Controller
document.addEventListener('turbo:load', function () {
    initThemeToggle();
});

document.addEventListener('DOMContentLoaded', function () {
    initThemeToggle();
});

function initThemeToggle() {
    // Check for saved theme preference or default to 'light'
    const currentTheme = localStorage.getItem('theme') || 'light';
    document.documentElement.setAttribute('data-theme', currentTheme);

    // Create toggle button if it doesn't exist
    if (!document.querySelector('.theme-toggle')) {
        createThemeToggle();
    }

    // Update button icon
    updateToggleIcon(currentTheme);
}

function createThemeToggle() {
    const toggle = document.createElement('div');
    toggle.className = 'theme-toggle';
    toggle.innerHTML = `
    <button id="theme-toggle-btn" aria-label="Toggle dark mode" title="Toggle dark/light mode">
      <span id="theme-icon">🌙</span>
    </button>
  `;

    document.body.appendChild(toggle);

    // Add click handler
    document.getElementById('theme-toggle-btn').addEventListener('click', toggleTheme);
}

function toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

    // Update DOM
    document.documentElement.setAttribute('data-theme', newTheme);

    // Save preference
    localStorage.setItem('theme', newTheme);

    // Update icon
    updateToggleIcon(newTheme);

    // Add animation class
    const btn = document.getElementById('theme-toggle-btn');
    btn.style.transform = 'rotate(360deg)';
    setTimeout(() => {
        btn.style.transform = '';
    }, 300);
}

function updateToggleIcon(theme) {
    const icon = document.getElementById('theme-icon');
    if (icon) {
        icon.textContent = theme === 'dark' ? '☀️' : '🌙';
    }
}
