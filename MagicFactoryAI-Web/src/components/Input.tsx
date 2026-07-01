interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
}

export default function Input({ label, className = '', ...rest }: InputProps) {
  return (
    <div className="flex flex-col gap-1">
      {label && (
        <label className="text-xs font-medium" style={{ color: '#64748B' }}>{label}</label>
      )}
      <input
        className={`rounded-lg px-3 py-2 text-sm outline-none transition-colors ${className}`}
        style={{
          background: '#334155',
          border: '1px solid #475569',
          color: '#F8FAFC',
        }}
        {...rest}
      />
    </div>
  );
}
