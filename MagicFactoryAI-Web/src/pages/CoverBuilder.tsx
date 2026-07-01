import { useState } from 'react';
import PageHeader from '../components/PageHeader';
import Card from '../components/Card';
import Btn from '../components/Btn';
import Input from '../components/Input';
import { libraryAssets, bookProperties } from '../mockData';

export default function CoverBuilder() {
  const [title, setTitle]       = useState(bookProperties.title);
  const [subtitle, setSubtitle] = useState(bookProperties.subtitle);
  const [author, setAuthor]     = useState(bookProperties.author);
  const [coverIdx, setCoverIdx] = useState(0);

  const coverAsset = libraryAssets[coverIdx];

  return (
    <div>
      <PageHeader icon="🎨" title="Cover Builder" subtitle="Design your book cover with live preview" />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6" style={{ minHeight: 'calc(100vh - 200px)' }}>
        {/* Form */}
        <Card className="flex flex-col gap-4">
          <h3 className="text-sm font-semibold" style={{ color: '#F8FAFC' }}>Cover Details</h3>
          <Input label="Title"    value={title}    onChange={e => setTitle(e.target.value)}    placeholder="Enter book title…" />
          <Input label="Subtitle" value={subtitle} onChange={e => setSubtitle(e.target.value)} placeholder="Enter subtitle…" />
          <Input label="Author"   value={author}   onChange={e => setAuthor(e.target.value)}   placeholder="Enter author name…" />

          <div>
            <label className="text-xs font-medium block mb-1" style={{ color: '#64748B' }}>Cover Image</label>
            <select
              value={coverIdx}
              onChange={e => setCoverIdx(Number(e.target.value))}
              className="w-full rounded-lg px-3 py-2 text-sm outline-none cursor-pointer"
              style={{ background: '#334155', border: '1px solid #475569', color: '#F8FAFC' }}
            >
              {libraryAssets.slice(0, 12).map((a, i) => (
                <option key={a.id} value={i}>{a.name}</option>
              ))}
            </select>
          </div>

          <div className="mt-auto flex flex-col gap-2">
            <Btn variant="primary" className="w-full">Apply to Book</Btn>
            <Btn className="w-full">Reset</Btn>
          </div>
        </Card>

        {/* Live Preview */}
        <Card className="lg:col-span-2 flex flex-col items-center justify-center" style={{ minHeight: 500 }}>
          <h3 className="text-sm font-semibold mb-6 self-start" style={{ color: '#F8FAFC' }}>
            Front Cover Preview
          </h3>

          {/* Cover card */}
          <div
            className="rounded-2xl flex flex-col items-center justify-between p-8 shadow-2xl transition-all"
            style={{
              width: 280,
              height: 380,
              background: `linear-gradient(135deg, ${coverAsset.color}33 0%, ${coverAsset.color}11 100%)`,
              border: `2px solid ${coverAsset.color}50`,
            }}
          >
            {/* Image placeholder */}
            <div
              className="rounded-xl flex items-center justify-center text-7xl"
              style={{ width: 180, height: 200, background: coverAsset.color + '22' }}
            >
              🖼
            </div>

            {/* Text strip */}
            <div className="text-center w-full">
              <div className="font-bold text-base leading-tight" style={{ color: '#F8FAFC' }}>
                {title || 'My Coloring Book'}
              </div>
              {subtitle && (
                <div className="text-xs mt-1" style={{ color: '#94A3B8' }}>{subtitle}</div>
              )}
              {author && (
                <div className="text-xs mt-2 font-medium" style={{ color: '#64748B' }}>by {author}</div>
              )}
            </div>
          </div>

          {/* Asset badge */}
          <div className="mt-4 flex items-center gap-2">
            <div className="w-6 h-6 rounded flex items-center justify-center text-sm"
                 style={{ background: coverAsset.color + '22' }}>🖼</div>
            <span className="text-xs" style={{ color: '#94A3B8' }}>{coverAsset.name}</span>
            <span className="text-xs px-2 py-0.5 rounded-full"
                  style={{ background: coverAsset.color + '22', color: coverAsset.color }}>
              {coverAsset.category}
            </span>
          </div>
        </Card>
      </div>
    </div>
  );
}
