import { Link, useLocation } from 'react-router-dom';
import { motion } from 'framer-motion';
import { 
  Droplets, 
  ArrowLeftRight, 
  PlusCircle, 
  Coins, 
  Vote, 
  BarChart3,
  Wallet,
  ChevronDown,
  ExternalLink
} from 'lucide-react';
import { useStore } from '../store/useStore';
import { useState } from 'react';

const navItems = [
  { path: '/', label: 'Dashboard', icon: BarChart3 },
  { path: '/swap', label: 'Swap', icon: ArrowLeftRight },
  { path: '/provide', label: 'Provide', icon: PlusCircle },
  { path: '/tokenomics', label: '$LF', icon: Coins },
  { path: '/governance', label: 'Governance', icon: Vote },
];

const chains = [
  { id: 1, name: 'Ethereum', icon: '⟠' },
  { id: 42161, name: 'Arbitrum', icon: '🔵' },
  { id: 8453, name: 'Base', icon: '🔷' },
  { id: 10, name: 'Optimism', icon: '🔴' },
  { id: 137, name: 'Polygon', icon: '🟣' },
];

export default function Navbar() {
  const location = useLocation();
  const { wallet } = useStore();
  const [showChainMenu, setShowChainMenu] = useState(false);
  
  const currentChain = chains.find(c => c.id === wallet.chainId) || chains[1];

  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 glass border-b border-white/5">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link to="/" className="flex items-center gap-3 group">
            <motion.div
              className="w-10 h-10 rounded-xl bg-flow-gradient flex items-center justify-center"
              whileHover={{ scale: 1.05, rotate: 5 }}
              whileTap={{ scale: 0.95 }}
            >
              <Droplets className="w-6 h-6 text-white" />
            </motion.div>
            <div className="hidden sm:block">
              <span className="text-xl font-bold gradient-text">Liquid Flow</span>
              <span className="text-xs text-gray-500 block -mt-1">Protocol</span>
            </div>
          </Link>

          {/* Navigation */}
          <div className="hidden md:flex items-center gap-1">
            {navItems.map((item) => {
              const isActive = location.pathname === item.path;
              const Icon = item.icon;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className="relative px-4 py-2 rounded-lg group"
                >
                  {isActive && (
                    <motion.div
                      layoutId="navbar-active"
                      className="absolute inset-0 bg-white/10 rounded-lg"
                      transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
                    />
                  )}
                  <span className={`relative flex items-center gap-2 text-sm font-medium transition-colors ${
                    isActive ? 'text-white' : 'text-gray-400 group-hover:text-white'
                  }`}>
                    <Icon className="w-4 h-4" />
                    {item.label}
                  </span>
                </Link>
              );
            })}
          </div>

          {/* Right side */}
          <div className="flex items-center gap-3">
            {/* Chain selector */}
            {wallet.isConnected && (
              <div className="relative">
                <button
                  onClick={() => setShowChainMenu(!showChainMenu)}
                  className="flex items-center gap-2 px-3 py-2 rounded-lg glass hover:bg-white/10 transition-colors"
                >
                  <span className="text-lg">{currentChain.icon}</span>
                  <span className="hidden sm:block text-sm text-gray-300">{currentChain.name}</span>
                  <ChevronDown className="w-4 h-4 text-gray-400" />
                </button>
                
                {showChainMenu && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 10 }}
                    className="absolute right-0 mt-2 w-48 py-2 glass rounded-xl shadow-xl"
                  >
                    {chains.map((chain) => (
                      <button
                        key={chain.id}
                        onClick={() => {
                          wallet.switchChain(chain.id);
                          setShowChainMenu(false);
                        }}
                        className={`w-full flex items-center gap-3 px-4 py-2 hover:bg-white/10 transition-colors ${
                          chain.id === wallet.chainId ? 'text-flow-blue' : 'text-gray-300'
                        }`}
                      >
                        <span className="text-lg">{chain.icon}</span>
                        <span className="text-sm">{chain.name}</span>
                        {chain.id === wallet.chainId && (
                          <span className="ml-auto w-2 h-2 rounded-full bg-flow-emerald" />
                        )}
                      </button>
                    ))}
                  </motion.div>
                )}
              </div>
            )}

            {/* Wallet button */}
            {wallet.isConnected ? (
              <motion.button
                onClick={wallet.disconnect}
                className="flex items-center gap-2 px-4 py-2 rounded-xl bg-flow-gradient text-white font-medium text-sm btn-glow"
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <Wallet className="w-4 h-4" />
                <span>{formatAddress(wallet.address!)}</span>
              </motion.button>
            ) : (
              <motion.button
                onClick={wallet.connect}
                className="flex items-center gap-2 px-4 py-2 rounded-xl bg-flow-gradient text-white font-medium text-sm btn-glow"
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <Wallet className="w-4 h-4" />
                <span>Connect Wallet</span>
              </motion.button>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
}
