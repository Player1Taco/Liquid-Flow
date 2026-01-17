import { Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Swap from './pages/Swap';
import Provide from './pages/Provide';
import Tokenomics from './pages/Tokenomics';
import Governance from './pages/Governance';
import Analytics from './pages/Analytics';

function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/swap" element={<Swap />} />
        <Route path="/provide" element={<Provide />} />
        <Route path="/tokenomics" element={<Tokenomics />} />
        <Route path="/governance" element={<Governance />} />
        <Route path="/analytics" element={<Analytics />} />
      </Routes>
    </Layout>
  );
}

export default App;
