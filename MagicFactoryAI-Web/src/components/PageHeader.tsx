interface PageHeaderProps {
  title: string;
  subtitle?: string;
  icon?: string;
  children?: React.ReactNode;
}

export default function PageHeader({ title, subtitle, icon, children }: PageHeaderProps) {
  return (
    <div className="flex items-start justify-between mb-6">
      <div>
        <h1 className="text-2xl font-bold flex items-center gap-3" style={{ color: '#F8FAFC' }}>
          {icon && <span>{icon}</span>}
          {title}
        </h1>
        {subtitle && (
          <p className="text-sm mt-1" style={{ color: '#64748B' }}>{subtitle}</p>
        )}
      </div>
      {children && <div className="flex items-center gap-2">{children}</div>}
    </div>
  );
}
