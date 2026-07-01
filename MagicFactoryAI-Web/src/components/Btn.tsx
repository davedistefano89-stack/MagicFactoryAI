interface BtnProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'ghost' | 'danger';
  size?: 'sm' | 'md';
}

export default function Btn({ variant = 'ghost', size = 'md', className = '', children, ...rest }: BtnProps) {
  const base = 'inline-flex items-center justify-center gap-2 rounded-lg font-medium transition-colors cursor-pointer border-0 outline-none';
  const sizes = { sm: 'px-3 py-1.5 text-xs h-8', md: 'px-4 py-2 text-sm h-9' };
  const variants = {
    primary: 'bg-primary text-white hover:bg-primary-dark',
    ghost:   'bg-transparent text-text-secondary border border-border hover:bg-surface-light hover:text-text-primary',
    danger:  'bg-error text-white hover:opacity-80',
  };
  return (
    <button className={`${base} ${sizes[size]} ${variants[variant]} ${className}`} {...rest}>
      {children}
    </button>
  );
}
