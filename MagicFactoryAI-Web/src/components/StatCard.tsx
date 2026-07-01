interface StatCardProps {
  label: string;
  value: string;
  icon: string;
  accent: string;
}

export default function StatCard({ label, value, icon, accent }: StatCardProps) {
  return (
    <div
      className="rounded-xl2 p-5 flex flex-col gap-1 min-h-[110px]"
      style={{
        background: '#1E293B',
        border: '1px solid #334155',
        borderLeft: `4px solid ${accent}`,
      }}
    >
      <span className="text-xs font-medium" style={{ color: '#94A3B8' }}>
        {icon}  {label}
      </span>
      <span className="text-4xl font-bold mt-1" style={{ color: accent }}>
        {value}
      </span>
    </div>
  );
}
