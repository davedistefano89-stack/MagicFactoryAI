import { useState } from 'react';
import PageHeader from '../components/PageHeader';
import Card from '../components/Card';
import Btn from '../components/Btn';
import Select from '../components/Select';
import { generatorStyles, generatorThemes, generatorAgeGroups } from '../mockData';

const mockPreviews = [
  { color: '#6366F1', label: 'Unicorn Magic' },
  { color: '#EC4899', label: 'Dragon Fire'   },
  { color: '#14B8A6', label: 'Ocean Friends' },
  { color: '#F59E0B', label: 'Space Explorer'},
];

export default function AIGenerator() {
  const [prompt, setPrompt]       = useState('A cute baby elephant wearing a party hat, simple coloring page style');
  const [style, setStyle]         = useState('Cute');
  const [theme, setTheme]         = useState('Animals');
  const [age, setAge]             = useState('3–6');
  const [count, setCount]         = useState('4');
  const [generating, setGenerating] = useState(false);
  const [progress, setProgress]   = useState(0);
  const [done, setDone]           = useState(false);

  const handleGenerate = () => {
    setGenerating(true); setDone(false); setProgress(0);
    const interval = setInterval(() => {
      setProgress(p => {
        if (p >= 100) { clearInterval(interval); setGenerating(false); setDone(true); return 100; }
        return p + 5;
      });
    }, 150);
  };

  return (
    <div>
      <PageHeader icon="✨" title="AI Generator" subtitle="Generate coloring pages with AI" />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left — Settings */}
        <div className="flex flex-col gap-4">
          <Card>
            <h3 className="text-sm font-semibold mb-3" style={{ color: '#F8FAFC' }}>Prompt</h3>
            <textarea
              value={prompt}
              onChange={e => setPrompt(e.target.value)}
              rows={4}
              className="w-full rounded-lg px-3 py-2 text-sm resize-none outline-none"
              style={{ background: '#334155', border: '1px solid #475569', color: '#F8FAFC' }}
            />
          </Card>

          <Card>
            <h3 className="text-sm font-semibold mb-3" style={{ color: '#F8FAFC' }}>Settings</h3>
            <div className="flex flex-col gap-3">
              <Select label="Style"     options={generatorStyles}    value={style}  onChange={e => setStyle(e.target.value)} />
              <Select label="Theme"     options={generatorThemes}    value={theme}  onChange={e => setTheme(e.target.value)} />
              <Select label="Age Group" options={generatorAgeGroups} value={age}    onChange={e => setAge(e.target.value)} />
              <Select label="Count"     options={['1','2','4','8','12','16']} value={count} onChange={e => setCount(e.target.value)} />
            </div>
          </Card>

          {generating && (
            <Card>
              <div className="text-xs mb-2" style={{ color: '#94A3B8' }}>Generating… {progress}%</div>
              <div className="w-full rounded-full h-2" style={{ background: '#334155' }}>
                <div className="h-2 rounded-full transition-all" style={{ width: `${progress}%`, background: '#6366F1' }} />
              </div>
            </Card>
          )}

          <Btn variant="primary" className="w-full" onClick={handleGenerate} disabled={generating}>
            {generating ? 'Generating…' : '✨  Generate'}
          </Btn>
        </div>

        {/* Right — Preview grid */}
        <div className="lg:col-span-2">
          <Card className="h-full">
            <h3 className="text-sm font-semibold mb-4" style={{ color: '#F8FAFC' }}>
              {done ? 'Generated Results' : 'Preview'}
            </h3>
            {done ? (
              <div className="grid grid-cols-2 gap-4">
                {mockPreviews.map((p, i) => (
                  <div key={i} className="rounded-xl overflow-hidden relative group cursor-pointer">
                    <div className="aspect-square flex items-center justify-center text-6xl"
                         style={{ background: p.color + '22', border: `2px solid ${p.color}40` }}>
                      🖼
                    </div>
                    <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
                      <Btn size="sm" variant="primary">Add to Library</Btn>
                    </div>
                    <div className="mt-1 text-xs text-center" style={{ color: '#94A3B8' }}>{p.label}</div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center h-64 gap-3" style={{ color: '#64748B' }}>
                <span className="text-5xl">✨</span>
                <span className="text-sm">Configure settings and click Generate</span>
              </div>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}
