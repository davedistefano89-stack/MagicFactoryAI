import { useState } from 'react';
import PageHeader from '../components/PageHeader';
import Card from '../components/Card';
import Btn from '../components/Btn';
import Input from '../components/Input';
import { libraryAssets } from '../mockData';

const CATEGORIES = ['All', 'Animals', 'Fantasy', 'Nature', 'Space', 'Adventure'];
const VIEWS = ['Grid', 'List'] as const;

export default function LibraryPro() {
  const [category, setCategory]   = useState('All');
  const [view, setView]           = useState<'Grid' | 'List'>('Grid');
  const [search, setSearch]       = useState('');
  const [selected, setSelected]   = useState<number | null>(null);

  const filtered = libraryAssets.filter(a =>
    (category === 'All' || a.category === category) &&
    a.name.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div>
      <PageHeader icon="🖼" title="Library PRO" subtitle={`${libraryAssets.length} assets in your collection`}>
        <Btn variant="primary" size="sm">+ Import Assets</Btn>
      </PageHeader>

      {/* Toolbar */}
      <div className="flex items-center gap-3 mb-5 flex-wrap">
        <Input
          placeholder="Search assets…"
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="w-56"
        />
        <div className="flex gap-1">
          {CATEGORIES.map(c => (
            <button
              key={c}
              onClick={() => setCategory(c)}
              className="px-3 py-1.5 text-xs rounded-lg font-medium transition-colors border-0 cursor-pointer"
              style={{
                background: category === c ? '#6366F1' : '#334155',
                color:      category === c ? '#fff'    : '#94A3B8',
              }}
            >
              {c}
            </button>
          ))}
        </div>
        <div className="ml-auto flex gap-1">
          {VIEWS.map(v => (
            <button
              key={v}
              onClick={() => setView(v)}
              className="px-3 py-1.5 text-xs rounded-lg font-medium border-0 cursor-pointer"
              style={{ background: view === v ? '#6366F1' : '#334155', color: view === v ? '#fff' : '#94A3B8' }}
            >
              {v === 'Grid' ? '⊞' : '≡'} {v}
            </button>
          ))}
        </div>
      </div>

      {/* Asset grid / list */}
      {view === 'Grid' ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 xl:grid-cols-6 gap-4">
          {filtered.map(asset => (
            <div
              key={asset.id}
              onClick={() => setSelected(selected === asset.id ? null : asset.id)}
              className="rounded-xl overflow-hidden cursor-pointer transition-transform hover:scale-105"
              style={{
                border: selected === asset.id ? `2px solid #6366F1` : '2px solid transparent',
                background: '#1E293B',
              }}
            >
              <div
                className="aspect-square flex items-center justify-center text-4xl"
                style={{ background: asset.color + '22' }}
              >
                🖼
              </div>
              <div className="p-2">
                <div className="text-xs font-medium truncate" style={{ color: '#F8FAFC' }}>{asset.name}</div>
                <div className="text-xs mt-0.5" style={{ color: '#64748B' }}>{asset.category}</div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <Card>
          <table className="w-full text-sm">
            <thead>
              <tr style={{ borderBottom: '1px solid #334155' }}>
                {['Name', 'Category', 'Created', 'Actions'].map(h => (
                  <th key={h} className="py-2 px-3 text-left font-medium" style={{ color: '#64748B' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map(asset => (
                <tr key={asset.id} style={{ borderBottom: '1px solid #334155' }}>
                  <td className="py-2 px-3 flex items-center gap-2">
                    <div className="w-8 h-8 rounded-lg flex items-center justify-center text-lg"
                         style={{ background: asset.color + '22' }}>🖼</div>
                    <span style={{ color: '#F8FAFC' }}>{asset.name}</span>
                  </td>
                  <td className="py-2 px-3">
                    <span className="text-xs px-2 py-0.5 rounded-full"
                          style={{ background: asset.color + '22', color: asset.color }}>
                      {asset.category}
                    </span>
                  </td>
                  <td className="py-2 px-3" style={{ color: '#64748B' }}>{asset.created}</td>
                  <td className="py-2 px-3">
                    <div className="flex gap-1">
                      <Btn size="sm">View</Btn>
                      <Btn size="sm">Add to Book</Btn>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}
    </div>
  );
}
