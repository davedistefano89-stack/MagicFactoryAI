/** Mock data for all pages — no backend required */

// ── Dashboard ─────────────────────────────────────────────────────────────────
export const dashboardStats = [
  { label: 'Total Assets',    value: '1,284', icon: '🖼',  accent: '#6366F1' },
  { label: 'Generated Today', value: '47',    icon: '✨',  accent: '#EC4899' },
  { label: 'Prompts Saved',   value: '93',    icon: '💬',  accent: '#14B8A6' },
  { label: 'Books Created',   value: '12',    icon: '📚',  accent: '#F59E0B' },
  { label: 'PDFs Exported',   value: '8',     icon: '📄',  accent: '#3B82F6' },
  { label: 'KDP Packages',    value: '3',     icon: '📦',  accent: '#10B981' },
];

export const recentActivity = [
  { time: '2 min ago',   action: 'Generated "Unicorn Meadow"',      type: 'generate' },
  { time: '14 min ago',  action: 'Exported "Rainbow Animals" PDF',  type: 'export'   },
  { time: '1 hr ago',    action: 'Saved prompt "Ocean Adventure"',  type: 'prompt'   },
  { time: '2 hrs ago',   action: 'Added 12 assets to Library',      type: 'library'  },
  { time: 'Yesterday',   action: 'Created KDP package "Space Book"',type: 'kdp'      },
];

// ── Library ───────────────────────────────────────────────────────────────────
export const libraryAssets = Array.from({ length: 24 }, (_, i) => ({
  id: i + 1,
  name: [
    'Unicorn Magic', 'Dragon Fire', 'Ocean Friends', 'Space Explorer',
    'Forest Animals', 'Butterfly Garden', 'Rainbow Castle', 'Pirate Ship',
    'Jungle Adventure', 'Fairy Tale', 'Robot World', 'Dinosaur Park',
    'Mermaid Cove', 'Wizard School', 'Farm Animals', 'Arctic Animals',
    'Jungle Safari', 'Desert Oasis', 'Mountain Trek', 'Seaside Fun',
    'City Lights', 'Country Life', 'Winter Magic', 'Spring Bloom',
  ][i],
  category: ['Animals', 'Fantasy', 'Nature', 'Space', 'Adventure'][i % 5],
  color: ['#6366F1','#EC4899','#14B8A6','#F59E0B','#3B82F6','#10B981','#8B5CF6'][i % 7],
  created: `2024-0${(i % 9) + 1}-${String((i % 28) + 1).padStart(2,'0')}`,
}));

// ── AI Generator ──────────────────────────────────────────────────────────────
export const generatorStyles = ['Cute', 'Realistic', 'Cartoon', 'Watercolor', 'Sketch', 'Manga'];
export const generatorThemes = ['Animals', 'Fantasy', 'Nature', 'Space', 'Adventure', 'Ocean', 'Dinosaurs'];
export const generatorAgeGroups = ['2–4', '3–6', '4–8', '6–10', '8–12'];

// ── Prompt Studio ─────────────────────────────────────────────────────────────
export const prompts = [
  { id: 1, name: 'Cute Animals Basic',   type: 'System',    text: 'Generate a cute, child-friendly coloring page featuring {animal}. Style: simple outlines, bold lines, no shading.' },
  { id: 2, name: 'Fantasy Creatures',    type: 'User',      text: 'Create a magical {creature} in a fantasy setting. Suitable for children aged {age}.' },
  { id: 3, name: 'Ocean Adventure',      type: 'System',    text: 'Design an underwater scene with {subject}. Include coral, fish, and bubbles. Keep outlines clear.' },
  { id: 4, name: 'Space Explorer',       type: 'Negative',  text: 'A {character} exploring outer space with rockets, stars, and planets. Black and white coloring page.' },
  { id: 5, name: 'Forest Friends',       type: 'User',      text: 'Draw friendly forest animals gathered around a {location}. Fun for kids aged {age}.' },
  { id: 6, name: 'Dinosaur World',       type: 'System',    text: 'A {dinosaur_type} dinosaur in a prehistoric landscape. Simple bold lines for easy coloring.' },
];

// ── Book Builder ──────────────────────────────────────────────────────────────
export const bookPages = [
  { id: 1, title: 'Unicorn Magic',     assetId: 1 },
  { id: 2, title: 'Dragon Fire',       assetId: 2 },
  { id: 3, title: 'Ocean Friends',     assetId: 3 },
  { id: 4, title: 'Space Explorer',    assetId: 4 },
  { id: 5, title: 'Forest Animals',    assetId: 5 },
  { id: 6, title: 'Butterfly Garden',  assetId: 6 },
  { id: 7, title: 'Rainbow Castle',    assetId: 7 },
  { id: 8, title: 'Pirate Ship',       assetId: 8 },
];

export const bookProperties = {
  title:        'My Coloring Book',
  subtitle:     'A Magical Adventure',
  author:       'Magic Factory AI',
  language:     'English',
  interiorType: 'Black & White',
  paperSize:    '8.5 x 11',
  marginPreset: 'KDP',
  targetAge:    '3–6',
};

// ── KDP Wizard ────────────────────────────────────────────────────────────────
export const kdpTrimSizes = ['8.5 x 11', 'A4', '6 x 9'];
export const kdpInteriorTypes = ['Black & White', 'Premium Color'];
export const kdpPaperColors = ['White', 'Cream'];
