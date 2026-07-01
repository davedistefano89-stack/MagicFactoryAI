interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  options: string[];
}

export default function Select({ label, options, className = '', ...rest }: SelectProps) {
  return (
    <div className="flex flex-col gap-1">
      {label && (
        <label className="text-xs font-medium" style={{ color: '#64748B' }}>{label}</label>
      )}
      <select
        className={`rounded-lg px-3 py-2 text-sm outline-none cursor-pointer ${className}`}
        style={{
          background: '#334155',
          border: '1px solid #475569',
          color: '#F8FAFC',
        }}
        {...rest}
      >
        {options.map(o => <option key={o}>{o}</option>)}
      </select>
    </div>
  );
}
