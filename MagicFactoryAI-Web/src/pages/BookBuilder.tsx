import { useState } from 'react';
import PageHeader from '../components/PageHeader';
import Card from '../components/Card';
import Btn from '../components/Btn';
import Input from '../components/Input';
import Select from '../components/Select';
import { bookPages, bookProperties, libraryAssets } from '../mockData';

type Page = typeof bookPages[0];
type Mode = 'editor' | 'preview';

export default function BookBuilder() {
  const [mode, setMode]           = useState<Mode>('editor');
  const [pages, setPages]         = useState<Page[]>(bookPages);
  const [propsOpen, setPropsOpen] = useState(true);
  const [previewIdx, setPreviewIdx] = useState(0);
  const [props, setProps]         = useState(bookProperties);
  const [activeTab, setActiveTab] = useState<'pages' | 'cover'>('pages');

  const addPage = () => {
    const next = { id: pages.length + 1, title: `Page ${pages.length + 1}`, assetId: (pages.length % 8) + 1 };
    setPages([...pages, next]);
  };
  const removePage = (id: number) => setPages(pages.filter(p => p.id !== id));

  const currentAsset = libraryAssets.find(a => a.id === pages[previewIdx]?.assetId);

  return (
    <div>
      <PageHeader icon="📚" title="Book Builder" subtitle="Arrange pages and build your coloring book" />

      {/* Inner tabs */}
      <div className="flex gap-1 mb-4">
        {(['pages', 'cover'] as const).map(t => (
          <button key={t} onClick={() => setActiveTab(t)}
            className="px-5 py-2 rounded-lg text-sm font-medium border-0 cursor-pointer transition-colors"
            style={{ background: activeTab === t ? '#6366F1' : '#334155', color: activeTab === t ? '#fff' : '#94A3B8' }}>
            {t === 'pages' ? '📄  Book Pages' : '🎨  Cover'}
          </button>
        ))}
      </div>

      {activeTab === 'pages' && (
        <>
          {/* Book Properties (collapsible) */}
          <Card className="mb-4">
            <button
              className="w-full flex items-center justify-between text-left border-0 bg-transparent cursor-pointer"
              onClick={() => setPropsOpen(!propsOpen)}
            >
              <span className="text-sm font-semibold" style={{ color: '#F8FAFC' }}>📖 Book Properties</span>
              <span style={{ color: '#94A3B8' }}>{propsOpen ? '▼' : '▶'}</span>
            </button>
            {propsOpen && (
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
                <Input label="Book Title"  value={props.title}        onChange={e => setProps({...props, title: e.target.value})} />
                <Input label="Subtitle"   value={props.subtitle}     onChange={e => setProps({...props, subtitle: e.target.value})} />
                <Input label="Author"     value={props.author}       onChange={e => setProps({...props, author: e.target.value})} />
                <Input label="Language"   value={props.language}     onChange={e => setProps({...props, language: e.target.value})} />
                <Select label="Interior Type" options={['Black & White','Premium Color']}
                        value={props.interiorType} onChange={e => setProps({...props, interiorType: e.target.value})} />
                <Select label="Paper Size"    options={['8.5 x 11','A4','6 x 9']}
                        value={props.paperSize}    onChange={e => setProps({...props, paperSize: e.target.value})} />
                <Select label="Margin Preset" options={['Standard','KDP']}
                        value={props.marginPreset} onChange={e => setProps({...props, marginPreset: e.target.value})} />
                <Input label="Target Age" value={props.targetAge}    onChange={e => setProps({...props, targetAge: e.target.value})} />
                <div className="flex flex-col gap-1">
                  <label className="text-xs font-medium" style={{ color: '#64748B' }}>Number of Pages</label>
                  <div className="rounded-lg px-3 py-2 text-sm font-semibold" style={{ background: '#334155', color: '#F8FAFC' }}>
                    {pages.length}
                  </div>
                </div>
              </div>
            )}
          </Card>

          {/* Mode toggle + toolbar */}
          <div className="flex items-center gap-2 mb-4 flex-wrap">
            <Btn variant={mode === 'editor' ? 'primary' : 'ghost'} size="sm" onClick={() => setMode('editor')}>✏️  Book Editor</Btn>
            <Btn variant={mode === 'preview' ? 'primary' : 'ghost'} size="sm" onClick={() => setMode('preview')}>👁  Live Preview</Btn>
            <div className="flex-1" />
            <Btn size="sm">💾  Save Book</Btn>
            <Btn size="sm">📂  Open Book</Btn>
            <Btn size="sm">📄  Export PDF</Btn>
            <Btn size="sm">🔍  Preview PDF</Btn>
            <Btn size="sm">📦  KDP Export</Btn>
          </div>

          {mode === 'editor' ? (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Asset pool */}
              <Card>
                <div className="flex items-center justify-between mb-3">
                  <span className="text-sm font-semibold" style={{ color: '#F8FAFC' }}>Asset Library</span>
                  <span className="text-xs" style={{ color: '#64748B' }}>Drag to add</span>
                </div>
                <div className="grid grid-cols-3 gap-3">
                  {libraryAssets.slice(0, 12).map(a => (
                    <div key={a.id}
                         onClick={() => setPages([...pages, { id: pages.length + 1, title: a.name, assetId: a.id }])}
                         className="rounded-lg aspect-square flex items-center justify-center text-3xl cursor-pointer transition-transform hover:scale-105"
                         style={{ background: a.color + '22', border: `1px solid ${a.color}40` }}
                         title={`Add "${a.name}"`}>
                      🖼
                    </div>
                  ))}
                </div>
              </Card>

              {/* Page list */}
              <Card>
                <div className="flex items-center justify-between mb-3">
                  <span className="text-sm font-semibold" style={{ color: '#F8FAFC' }}>Book Pages ({pages.length})</span>
                  <Btn size="sm" variant="primary" onClick={addPage}>+ Add Page</Btn>
                </div>
                {pages.length === 0 ? (
                  <div className="flex items-center justify-center h-40 text-sm" style={{ color: '#64748B' }}>
                    No pages yet — add assets from the library
                  </div>
                ) : (
                  <div className="flex flex-col gap-2 max-h-96 overflow-y-auto">
                    {pages.map((p, i) => (
                      <div key={p.id} className="flex items-center gap-3 px-3 py-2 rounded-lg" style={{ background: '#334155' }}>
                        <span className="text-xs w-6 text-center font-mono" style={{ color: '#64748B' }}>{i + 1}</span>
                        <div className="w-8 h-8 rounded flex items-center justify-center text-lg"
                             style={{ background: (libraryAssets.find(a=>a.id===p.assetId)?.color ?? '#6366F1') + '22' }}>🖼</div>
                        <span className="flex-1 text-sm truncate" style={{ color: '#F8FAFC' }}>{p.title}</span>
                        <button onClick={() => removePage(p.id)} className="text-xs px-2 py-1 rounded border-0 cursor-pointer" style={{ background: '#EF444422', color: '#EF4444' }}>✕</button>
                      </div>
                    ))}
                  </div>
                )}
              </Card>
            </div>
          ) : (
            /* Live Preview */
            <Card>
              <div className="flex items-center justify-between mb-4">
                <Btn size="sm" disabled={previewIdx === 0} onClick={() => setPreviewIdx(i => Math.max(0, i-1))}>← Previous</Btn>
                <span className="text-sm font-semibold" style={{ color: '#F8FAFC' }}>
                  Page {pages.length ? previewIdx + 1 : 0} of {pages.length}
                </span>
                <Btn size="sm" disabled={previewIdx >= pages.length - 1} onClick={() => setPreviewIdx(i => Math.min(pages.length - 1, i+1))}>Next →</Btn>
              </div>
              {pages.length ? (
                <div className="flex items-center justify-center" style={{ minHeight: 400 }}>
                  <div className="rounded-xl flex items-center justify-center text-8xl"
                       style={{ width: 320, height: 400, background: (currentAsset?.color ?? '#6366F1') + '22',
                                border: `2px solid ${currentAsset?.color ?? '#6366F1'}40` }}>
                    🖼
                  </div>
                </div>
              ) : (
                <div className="flex items-center justify-center h-48 text-sm" style={{ color: '#64748B' }}>No pages to preview</div>
              )}
            </Card>
          )}
        </>
      )}

      {activeTab === 'cover' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <Card>
            <h3 className="text-sm font-semibold mb-4" style={{ color: '#F8FAFC' }}>Cover Details</h3>
            <div className="flex flex-col gap-3">
              <Input label="Title"    defaultValue={props.title}    />
              <Input label="Subtitle" defaultValue={props.subtitle} />
              <Input label="Author"   defaultValue={props.author}   />
              <Select label="Cover Image" options={['None', ...libraryAssets.slice(0,8).map(a => a.name)]} />
            </div>
          </Card>
          <Card className="lg:col-span-2 flex items-center justify-center" style={{ minHeight: 400 }}>
            <div className="flex flex-col items-center justify-center rounded-xl w-64 h-80 relative"
                 style={{ background: 'linear-gradient(135deg,#6366F122,#EC489922)', border: '2px solid #6366F140' }}>
              <div className="text-6xl mb-4">🖼</div>
              <div className="text-center px-4">
                <div className="font-bold text-lg" style={{ color: '#F8FAFC' }}>{props.title}</div>
                <div className="text-sm mt-1" style={{ color: '#94A3B8' }}>{props.subtitle}</div>
                <div className="text-xs mt-2" style={{ color: '#64748B' }}>{props.author}</div>
              </div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
