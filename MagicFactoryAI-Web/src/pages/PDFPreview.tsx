import { useState } from 'react';
import PageHeader from '../components/PageHeader';
import Card from '../components/Card';
import Btn from '../components/Btn';
import { bookPages, libraryAssets } from '../mockData';

const ZOOMS = ['Fit Page', 'Fit Width', '50%', '100%'] as const;
type Zoom = typeof ZOOMS[number];

export default function PDFPreview() {
  const [zoom, setZoom]   = useState<Zoom>('Fit Page');
  const [idx, setIdx]     = useState(0);
  const [pages]           = useState(bookPages);

  const total    = pages.length;
  const asset    = libraryAssets.find(a => a.id === pages[idx]?.assetId);

  const previewW: Record<Zoom, number> = {
    'Fit Page': 340, 'Fit Width': 480, '50%': 280, '100%': 612,
  };

  return (
    <div>
      <PageHeader icon="📄" title="PDF Preview" subtitle="Preview your book exactly as it will be exported">
        <Btn variant="primary">📄  Export PDF</Btn>
      </PageHeader>

      {/* Toolbar */}
      <Card className="mb-4">
        <div className="flex items-center gap-4 flex-wrap">
          {/* Navigation */}
          <div className="flex items-center gap-2">
            <Btn size="sm" disabled={idx === 0} onClick={() => setIdx(i => Math.max(0, i-1))}>← Prev</Btn>
            <span className="text-sm px-3 font-medium" style={{ color: '#F8FAFC' }}>
              Page {total ? idx + 1 : 0} of {total}
            </span>
            <Btn size="sm" disabled={idx >= total - 1} onClick={() => setIdx(i => Math.min(total - 1, i+1))}>Next →</Btn>
          </div>

          <div className="w-px h-6" style={{ background: '#334155' }} />

          {/* Zoom */}
          <div className="flex items-center gap-2">
            <span className="text-xs" style={{ color: '#64748B' }}>Zoom:</span>
            {ZOOMS.map(z => (
              <button key={z} onClick={() => setZoom(z)}
                className="px-2.5 py-1 text-xs rounded border-0 cursor-pointer font-medium"
                style={{ background: zoom === z ? '#6366F1' : '#334155', color: zoom === z ? '#fff' : '#94A3B8' }}>
                {z}
              </button>
            ))}
          </div>

          <div className="flex-1" />
          <div className="text-xs px-3 py-1 rounded-lg" style={{ background: '#334155', color: '#94A3B8' }}>
            8.5 × 11 in · KDP margins
          </div>
        </div>
      </Card>

      {/* Preview area */}
      <div className="flex gap-6">
        {/* Page canvas */}
        <div className="flex-1 flex items-start justify-center overflow-auto" style={{ minHeight: 500 }}>
          {total === 0 ? (
            <div className="flex flex-col items-center justify-center h-80 gap-3" style={{ color: '#64748B' }}>
              <span className="text-5xl">📄</span>
              <span className="text-sm">No pages in the book</span>
            </div>
          ) : (
            <div
              className="flex flex-col items-center justify-center rounded-xl shadow-2xl relative transition-all"
              style={{
                width: previewW[zoom],
                height: previewW[zoom] * 1.294, // 8.5×11 aspect ratio
                background: '#FFFFFF',
                boxShadow: '0 20px 60px #00000080',
              }}
            >
              {/* White page with centred image */}
              <div
                className="rounded-xl flex items-center justify-center text-8xl"
                style={{
                  width: '70%', height: '70%',
                  background: (asset?.color ?? '#6366F1') + '11',
                }}
              >
                🖼
              </div>
              {/* Page number */}
              <div className="absolute bottom-3 left-0 right-0 text-center text-xs" style={{ color: '#9CA3AF' }}>
                {idx + 1}
              </div>
            </div>
          )}
        </div>

        {/* Page thumbnails */}
        <div className="w-28 flex flex-col gap-2 overflow-y-auto" style={{ maxHeight: 600 }}>
          {pages.map((p, i) => {
            return (
              <button
                key={p.id}
                onClick={() => setIdx(i)}
                className="w-full rounded-lg border-0 cursor-pointer p-1 transition-all"
                style={{
                  background: '#1E293B',
                  border: i === idx ? '2px solid #6366F1' : '2px solid #334155',
                }}
              >
                <div
                  className="rounded aspect-square flex items-center justify-center text-2xl"
                  style={{ background: '#FFFFFF', color: '#374151' }}
                >
                  🖼
                </div>
                <div className="text-xs mt-1 text-center" style={{ color: '#64748B' }}>
                  p.{i + 1}
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
