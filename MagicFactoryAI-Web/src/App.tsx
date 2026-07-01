import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard   from './pages/Dashboard';
import AIGenerator from './pages/AIGenerator';
import PromptStudio from './pages/PromptStudio';
import LibraryPro  from './pages/LibraryPro';
import BookBuilder  from './pages/BookBuilder';
import CoverBuilder from './pages/CoverBuilder';
import PDFPreview   from './pages/PDFPreview';
import KDPWizard    from './pages/KDPWizard';

export default function App() {
  return (
    <BrowserRouter>
      <Layout>
        <Routes>
          <Route path="/"              element={<Dashboard />}   />
          <Route path="/ai-generator"  element={<AIGenerator />} />
          <Route path="/prompt-studio" element={<PromptStudio />}/>
          <Route path="/library"       element={<LibraryPro />}  />
          <Route path="/book-builder"  element={<BookBuilder />} />
          <Route path="/cover-builder" element={<CoverBuilder />}/>
          <Route path="/pdf-preview"   element={<PDFPreview />}  />
          <Route path="/kdp-wizard"    element={<KDPWizard />}   />
        </Routes>
      </Layout>
    </BrowserRouter>
  );
}
