// Theme Toggle Controller
// Premium dark/light mode switching with animated transitions

document.addEventListener('turbo:load', function () {
    initThemeToggle();
});

document.addEventListener('DOMContentLoaded', function () {
    initThemeToggle();
});

function initThemeToggle() {
    // Check for saved theme preference, system preference, or default to 'light'
    const savedTheme = localStorage.getItem('theme');
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const currentTheme = savedTheme || (systemPrefersDark ? 'dark' : 'light');

    document.documentElement.setAttribute('data-theme', currentTheme);

    // Create toggle button if it doesn't exist
    if (!document.querySelector('.theme-toggle')) {
        createThemeToggle();
    }

    // Update button icon
    updateToggleIcon(currentTheme);

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
        if (!localStorage.getItem('theme')) {
            const newTheme = e.matches ? 'dark' : 'light';
            document.documentElement.setAttribute('data-theme', newTheme);
            updateToggleIcon(newTheme);
        }
    });
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
    const btn = document.getElementById('theme-toggle-btn');

    // Add animation class
    btn.classList.add('switching');

    // Update DOM
    document.documentElement.setAttribute('data-theme', newTheme);

    // Save preference
    localStorage.setItem('theme', newTheme);

    // Update icon with slight delay for smooth transition
    setTimeout(() => {
        updateToggleIcon(newTheme);
    }, 150);

    // Remove animation class after animation completes
    setTimeout(() => {
        btn.classList.remove('switching');
    }, 500);
}

function updateToggleIcon(theme) {
    const icon = document.getElementById('theme-icon');
    if (icon) {
        icon.textContent = theme === 'dark' ? '☀️' : '🌙';
    }
}
