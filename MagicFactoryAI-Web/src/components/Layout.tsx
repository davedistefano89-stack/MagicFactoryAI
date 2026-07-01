import Sidebar from './Sidebar';

interface LayoutProps { children: React.ReactNode; }

export default function Layout({ children }: LayoutProps) {
  return (
    <div className="flex h-screen overflow-hidden" style={{ background: '#0F172A' }}>
      <Sidebar />
      <main className="flex-1 overflow-y-auto p-8">
        {children}
      </main>
    </div>
  );
}
