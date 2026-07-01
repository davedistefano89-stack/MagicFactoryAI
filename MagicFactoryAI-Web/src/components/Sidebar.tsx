import { NavLink, useLocation } from 'react-router-dom';

const NAV_ITEMS = [
  { id: 'dashboard',     label: 'Dashboard',      icon: '📊', path: '/'              },
  { id: 'ai-generator',  label: 'AI Generator',   icon: '✨', path: '/ai-generator'  },
  { id: 'prompt-studio', label: 'Prompt Studio',  icon: '💬', path: '/prompt-studio' },
  { id: 'library',       label: 'Library PRO',    icon: '🖼', path: '/library'       },
  { id: 'book-builder',  label: 'Book Builder',   icon: '📚', path: '/book-builder'  },
  { id: 'cover-builder', label: 'Cover Builder',  icon: '🎨', path: '/cover-builder' },
  { id: 'pdf-preview',   label: 'PDF Preview',    icon: '📄', path: '/pdf-preview'   },
  { id: 'kdp-wizard',    label: 'KDP Wizard',     icon: '📦', path: '/kdp-wizard'    },
];

export default function Sidebar() {
  const location = useLocation();

  return (
    <aside
      className="flex flex-col h-full w-64 flex-shrink-0"
      style={{ background: '#1A1F35', borderRight: '1px solid #334155' }}
    >
      {/* Brand */}
      <div className="px-5 pt-6 pb-2">
        <div className="text-xl font-bold" style={{ color: '#F8FAFC' }}>
          🎨 Magic Factory AI
        </div>
        <div className="text-xs mt-1" style={{ color: '#64748B' }}>
          Magic Colors Adventure
        </div>
      </div>

      {/* Divider */}
      <div className="mx-5 my-4" style={{ height: 1, background: '#334155' }} />

      {/* Nav */}
      <nav className="flex flex-col gap-1 px-3 flex-1 overflow-y-auto">
        {NAV_ITEMS.map(item => {
          const active = location.pathname === item.path;
          return (
            <NavLink
              key={item.id}
              to={item.path}
              className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors no-underline"
              style={{
                background:  active ? '#6366F1' : 'transparent',
                color:       active ? '#FFFFFF' : '#94A3B8',
              }}
              onMouseEnter={e => { if (!active) (e.currentTarget as HTMLElement).style.background = '#2A3050'; }}
              onMouseLeave={e => { if (!active) (e.currentTarget as HTMLElement).style.background = 'transparent'; }}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </NavLink>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="px-5 py-4 text-center text-xs" style={{ color: '#64748B' }}>
        v1.0.0
      </div>
    </aside>
  );
}
