import StatCard from '../components/StatCard';
import PageHeader from '../components/PageHeader';
import Card from '../components/Card';
import { dashboardStats, recentActivity } from '../mockData';

const activityIcons: Record<string, string> = {
  generate: '✨', export: '📄', prompt: '💬', library: '🖼', kdp: '📦',
};

export default function Dashboard() {
  return (
    <div>
      <PageHeader
        icon="📊"
        title="Dashboard"
        subtitle="Welcome back — here's your Magic Factory overview"
      />

      {/* Stat grid */}
      <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4 mb-8">
        {dashboardStats.map(s => (
          <StatCard key={s.label} label={s.label} value={s.value} icon={s.icon} accent={s.accent} />
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Activity */}
        <Card className="lg:col-span-2">
          <h2 className="text-base font-semibold mb-4" style={{ color: '#F8FAFC' }}>
            Recent Activity
          </h2>
          <div className="flex flex-col gap-3">
            {recentActivity.map((a, i) => (
              <div key={i} className="flex items-center gap-3 py-2" style={{ borderBottom: i < recentActivity.length - 1 ? '1px solid #334155' : 'none' }}>
                <span className="text-xl">{activityIcons[a.type]}</span>
                <div className="flex-1">
                  <div className="text-sm" style={{ color: '#F8FAFC' }}>{a.action}</div>
                  <div className="text-xs mt-0.5" style={{ color: '#64748B' }}>{a.time}</div>
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Quick Actions */}
        <Card>
          <h2 className="text-base font-semibold mb-4" style={{ color: '#F8FAFC' }}>
            Quick Actions
          </h2>
          <div className="flex flex-col gap-2">
            {[
              { label: 'Generate New Assets', icon: '✨', color: '#6366F1' },
              { label: 'Open Book Builder',   icon: '📚', color: '#EC4899' },
              { label: 'Preview PDF',         icon: '📄', color: '#14B8A6' },
              { label: 'KDP Export',          icon: '📦', color: '#F59E0B' },
              { label: 'Browse Library',      icon: '🖼', color: '#10B981' },
            ].map(a => (
              <button
                key={a.label}
                className="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium w-full text-left transition-colors cursor-pointer border-0"
                style={{ background: '#334155', color: '#F8FAFC' }}
                onMouseEnter={e => (e.currentTarget.style.background = '#475569')}
                onMouseLeave={e => (e.currentTarget.style.background = '#334155')}
              >
                <span className="text-lg">{a.icon}</span>
                {a.label}
              </button>
            ))}
          </div>
        </Card>
      </div>

      {/* Project Banner */}
      <div
        className="mt-6 rounded-xl2 p-6 flex items-center justify-between"
        style={{ background: 'linear-gradient(135deg,#6366F1 0%,#8B5CF6 100%)' }}
      >
        <div>
          <div className="text-lg font-bold text-white">Magic Colors Adventure</div>
          <div className="text-sm mt-1 text-white/80">
            1,284 assets · 12 books · 3 KDP packages ready
          </div>
        </div>
        <div className="text-4xl">🎨</div>
      </div>
    </div>
  );
}
