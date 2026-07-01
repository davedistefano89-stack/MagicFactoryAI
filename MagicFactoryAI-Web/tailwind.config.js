/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Brand
        primary:   '#6366F1',
        'primary-light': '#818CF8',
        'primary-dark':  '#4F46E5',
        secondary: '#EC4899',
        accent:    '#14B8A6',
        warning:   '#F59E0B',
        success:   '#10B981',
        error:     '#EF4444',
        info:      '#3B82F6',
        // Surfaces
        bg:            '#0F172A',
        surface:       '#1E293B',
        'surface-light':  '#334155',
        'surface-hover':  '#475569',
        // Sidebar
        sidebar:       '#1A1F35',
        'sidebar-active': '#6366F1',
        'sidebar-hover':  '#2A3050',
        // Text
        'text-primary':   '#F8FAFC',
        'text-secondary': '#94A3B8',
        'text-muted':     '#64748B',
        // Borders
        border:        '#334155',
        'border-light':   '#475569',
      },
      borderRadius: { xl2: '12px' },
    },
  },
  plugins: [],
}

