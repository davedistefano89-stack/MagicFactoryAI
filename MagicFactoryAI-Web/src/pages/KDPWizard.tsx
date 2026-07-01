import { useState } from 'react';
import PageHeader from '../components/PageHeader';
import Card from '../components/Card';
import Btn from '../components/Btn';
import Select from '../components/Select';
import { kdpTrimSizes, kdpInteriorTypes, kdpPaperColors, bookPages, bookProperties } from '../mockData';

type Step = 1 | 2 | 3;

interface Check { icon: '✅' | '⚠️'; message: string; }

const getChecks = (pages: typeof bookPages, hasCover: boolean): Check[] => [
  pages.length > 0
    ? { icon: '✅', message: `Content pages: ${pages.length} page(s)` }
    : { icon: '⚠️', message: 'No content pages found in the book.' },
  hasCover
    ? { icon: '✅', message: 'Cover image is present.' }
    : { icon: '⚠️', message: 'No cover image selected in the Cover Builder.' },
  { icon: '✅', message: 'All content images found on disk.' },
  pages.length + (hasCover ? 1 : 0) >= 24
    ? { icon: '✅', message: `Total page count (${pages.length + (hasCover ? 1 : 0)}) meets KDP minimum.` }
    : { icon: '⚠️', message: `Total page count (${pages.length + (hasCover ? 1 : 0)}) is below the KDP minimum of 24 pages.` },
];

export default function KDPWizard() {
  const [step, setStep]         = useState<Step>(1);
  const [trimSize, setTrimSize] = useState(bookProperties.paperSize);
  const [interior, setInterior] = useState(bookProperties.interiorType);
  const [bleed, setBleed]       = useState(false);
  const [paperColor, setPaper]  = useState('White');
  const [exported, setExported] = useState(false);

  const hasCover = true; // mock — always has cover
  const checks   = getChecks(bookPages, hasCover);
  const warnings = checks.filter(c => c.icon === '⚠️').length;
  const total    = bookPages.length + (hasCover ? 1 : 0);
  const estSize  = `${(total * 1.2).toFixed(1)} MB`;

  const STEP_LABELS: Record<Step, string> = {
    1: 'Book Information',
    2: 'Validation',
    3: 'Summary',
  };

  return (
    <div style={{ maxWidth: 680 }}>
      <PageHeader icon="📦" title="KDP Export Wizard" subtitle="Prepare your book for Amazon KDP publishing" />

      {/* Step indicator */}
      <div className="flex items-center gap-2 mb-6">
        {([1, 2, 3] as Step[]).map((s, i) => (
          <div key={s} className="flex items-center gap-2">
            <div
              className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold"
              style={{
                background: step >= s ? '#6366F1' : '#334155',
                color: step >= s ? '#fff' : '#64748B',
              }}
            >
              {step > s ? '✓' : s}
            </div>
            <span className="text-sm" style={{ color: step === s ? '#F8FAFC' : '#64748B' }}>
              {STEP_LABELS[s]}
            </span>
            {i < 2 && <div className="w-12 h-0.5 mx-1" style={{ background: step > s ? '#6366F1' : '#334155' }} />}
          </div>
        ))}
        <span className="ml-auto text-xs" style={{ color: '#64748B' }}>Step {step} of 3</span>
      </div>

      {/* Step content */}
      <Card className="mb-6">
        {step === 1 && (
          <div className="flex flex-col gap-5">
            <div>
              <h3 className="text-base font-semibold mb-1" style={{ color: '#F8FAFC' }}>Step 1 — Book Information</h3>
              <p className="text-sm" style={{ color: '#64748B' }}>Review and confirm KDP printing parameters.</p>
            </div>
            <Select label="Trim Size"     options={kdpTrimSizes}     value={trimSize} onChange={e => setTrimSize(e.target.value)} />
            <Select label="Interior Type" options={kdpInteriorTypes} value={interior} onChange={e => setInterior(e.target.value)} />
            <div>
              <label className="text-xs font-medium block mb-1" style={{ color: '#64748B' }}>Bleed</label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={bleed} onChange={e => setBleed(e.target.checked)} className="w-4 h-4 accent-indigo-500" />
                <span className="text-sm" style={{ color: '#F8FAFC' }}>Include 0.125″ bleed</span>
              </label>
            </div>
            <Select label="Paper Color"   options={kdpPaperColors}   value={paperColor} onChange={e => setPaper(e.target.value)} />
          </div>
        )}

        {step === 2 && (
          <div>
            <h3 className="text-base font-semibold mb-1" style={{ color: '#F8FAFC' }}>Step 2 — Validation</h3>
            <p className="text-sm mb-4" style={{ color: '#64748B' }}>Warnings are shown for reference only — export is never blocked.</p>
            <div className="flex flex-col gap-3">
              {checks.map((c, i) => (
                <div key={i} className="flex items-start gap-3 px-3 py-2 rounded-lg" style={{ background: '#334155' }}>
                  <span className="text-lg">{c.icon}</span>
                  <span className="text-sm" style={{ color: '#F8FAFC' }}>{c.message}</span>
                </div>
              ))}
            </div>
            {warnings > 0 && (
              <div className="mt-4 px-3 py-2 rounded-lg text-xs" style={{ background: '#F59E0B22', color: '#F59E0B', border: '1px solid #F59E0B40' }}>
                {warnings} warning(s) — you can still proceed with export.
              </div>
            )}
          </div>
        )}

        {step === 3 && (
          <div>
            <h3 className="text-base font-semibold mb-1" style={{ color: '#F8FAFC' }}>Step 3 — Summary</h3>
            <p className="text-sm mb-4" style={{ color: '#64748B' }}>Review the export settings then click Export.</p>
            <div className="flex flex-col gap-2">
              {[
                ['Total Pages',    String(total)],
                ['Cover',          hasCover ? 'Yes' : 'No'],
                ['Trim Size',      trimSize],
                ['Interior Type',  interior],
                ['Bleed',          bleed ? '0.125″ bleed' : 'No bleed'],
                ['Paper Color',    paperColor],
                ['Est. PDF Size',  estSize],
              ].map(([label, value]) => (
                <div key={label} className="flex items-center gap-4 px-3 py-2 rounded-lg" style={{ background: '#334155' }}>
                  <span className="text-xs w-32 flex-shrink-0" style={{ color: '#64748B' }}>{label}</span>
                  <span className="text-sm font-medium" style={{ color: '#F8FAFC' }}>{value}</span>
                </div>
              ))}
            </div>

            {exported && (
              <div className="mt-4 p-3 rounded-lg" style={{ background: '#10B98122', border: '1px solid #10B98140' }}>
                <div className="text-sm font-semibold" style={{ color: '#10B981' }}>✅ Publishing package created!</div>
                <div className="text-xs mt-1" style={{ color: '#94A3B8' }}>
                  Book.pdf · Cover.pdf · manifest.json · preview.jpg
                </div>
              </div>
            )}
          </div>
        )}
      </Card>

      {/* Buttons */}
      <div className="flex items-center gap-3">
        <Btn variant="ghost" onClick={() => { setStep(1); setExported(false); }}>Cancel</Btn>
        <div className="flex-1" />
        {step > 1 && <Btn onClick={() => setStep(s => (s - 1) as Step)}>← Back</Btn>}
        {step < 3 && <Btn variant="primary" onClick={() => setStep(s => (s + 1) as Step)}>Next →</Btn>}
        {step === 3 && (
          <Btn variant="primary" onClick={() => setExported(true)}>
            📦  Export Package
          </Btn>
        )}
      </div>
    </div>
  );
}
