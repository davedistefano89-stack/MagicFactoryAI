import { useState } from 'react';
import PageHeader from '../components/PageHeader';
import Card from '../components/Card';
import Btn from '../components/Btn';
import Input from '../components/Input';
import Select from '../components/Select';
import { prompts } from '../mockData';

type Prompt = typeof prompts[0];

export default function PromptStudio() {
  const [selected, setSelected] = useState<Prompt | null>(prompts[0]);
  const [search, setSearch]     = useState('');
  const [editText, setEditText] = useState(prompts[0].text);

  const filtered = prompts.filter(p =>
    p.name.toLowerCase().includes(search.toLowerCase())
  );

  const typeColor: Record<string,string> = {
    System:   '#6366F1',
    User:     '#10B981',
    Negative: '#EF4444',
  };

  return (
    <div>
      <PageHeader icon="💬" title="Prompt Studio" subtitle="Create and manage your AI prompts">
        <Btn variant="primary" size="sm">+ New Prompt</Btn>
      </PageHeader>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-[calc(100vh-180px)]">
        {/* Left — Prompt list */}
        <Card className="flex flex-col overflow-hidden">
          <Input
            placeholder="Search prompts…"
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="mb-3"
          />
          <div className="flex-1 overflow-y-auto flex flex-col gap-2">
            {filtered.map(p => (
              <button
                key={p.id}
                onClick={() => { setSelected(p); setEditText(p.text); }}
                className="w-full text-left px-3 py-3 rounded-lg transition-colors border-0 cursor-pointer"
                style={{
                  background: selected?.id === p.id ? '#6366F115' : 'transparent',
                  border: selected?.id === p.id ? '1px solid #6366F150' : '1px solid transparent',
                  color: '#F8FAFC',
                }}
              >
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm font-medium truncate">{p.name}</span>
                  <span
                    className="text-xs px-2 py-0.5 rounded-full"
                    style={{ background: typeColor[p.type] + '22', color: typeColor[p.type] }}
                  >
                    {p.type}
                  </span>
                </div>
                <div className="text-xs truncate" style={{ color: '#64748B' }}>{p.text}</div>
              </button>
            ))}
          </div>
        </Card>

        {/* Right — Editor */}
        <Card className="lg:col-span-2 flex flex-col">
          {selected ? (
            <>
              <div className="flex items-center justify-between mb-4">
                <div className="flex flex-col gap-1">
                  <Input label="Name" defaultValue={selected.name} className="w-64" />
                </div>
                <Select label="Type" options={['System','User','Negative']} value={selected.type} />
              </div>
              <label className="text-xs font-medium mb-1 block" style={{ color: '#64748B' }}>
                Prompt Text
              </label>
              <textarea
                value={editText}
                onChange={e => setEditText(e.target.value)}
                rows={8}
                className="w-full rounded-lg px-3 py-2 text-sm resize-none outline-none flex-1"
                style={{ background: '#334155', border: '1px solid #475569', color: '#F8FAFC', minHeight: '160px' }}
              />
              <div className="flex gap-2 mt-4">
                <Btn variant="primary">Save Prompt</Btn>
                <Btn>Duplicate</Btn>
                <Btn variant="danger" size="sm" className="ml-auto">Delete</Btn>
              </div>

              {/* Variables hint */}
              <div className="mt-4 p-3 rounded-lg" style={{ background: '#6366F115', border: '1px solid #6366F130' }}>
                <div className="text-xs font-semibold mb-1" style={{ color: '#818CF8' }}>Variables detected</div>
                {Array.from(editText.matchAll(/\{(\w+)\}/g)).map((m, i) => (
                  <span key={i} className="inline-block text-xs px-2 py-0.5 rounded-full mr-1 mb-1"
                        style={{ background: '#6366F130', color: '#818CF8' }}>{m[0]}</span>
                ))}
              </div>
            </>
          ) : (
            <div className="flex items-center justify-center h-full text-center" style={{ color: '#64748B' }}>
              <div>
                <div className="text-4xl mb-3">💬</div>
                <div>Select a prompt to edit</div>
              </div>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
