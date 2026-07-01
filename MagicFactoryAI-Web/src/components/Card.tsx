interface CardProps {
  children: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
}

export default function Card({ children, className = '', style }: CardProps) {
  return (
    <div
      className={`rounded-xl2 p-5 ${className}`}
      style={{ background: '#1E293B', border: '1px solid #334155', ...style }}
    >
      {children}
    </div>
  );
}
