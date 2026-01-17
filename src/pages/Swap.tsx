import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  ArrowDownUp, 
  Settings, 
  ChevronDown, 
  Zap, 
  Shield, 
  Clock,
  AlertCircle,
  Check
} from 'lucide-react';
import { useStore } from '../store/useStore';

const tokens = [
  { symbol: 'ETH', name: 'Ethereum', icon: '⟠', balance: '2.5' },
  { symbol: 'USDC', name: 'USD Coin', icon: '💵', balance: '5000' },
  { symbol: 'ARB', name: 'Arbitrum', icon: '🔵', balance: '1500' },
  { symbol: 'WBTC', name: 'Wrapped Bitcoin', icon: '₿', balance: '0.15' },
];

const chains = [
  { id: 42161, name: 'Arbitrum', icon: '🔵' },
  { id: 8453, name: 'Base', icon: '🔷' },
  { id: 1, name: 'Ethereum', icon: '⟠' },
  { id: 10, name: 'Optimism', icon: '🔴' },
];

const mevOptions = [
  { id: 'none', label: 'No Protection', desc: 'Fastest execution', icon: Zap },
  { id: 'basic', label: 'Basic', desc: 'Commit-reveal', icon: Shield },
  { id: 'protected', label: 'Protected', desc: 'Private mempool', icon: Shield },
  { id: 'maximum', label: 'Maximum', desc: 'MEV-Share rebates', icon: Shield },
];

export default function Swap() {
  const { wallet } = useStore();
  const [fromToken, setFromToken] = useState(tokens[0]);
  const [toToken, setToToken] = useState(tokens[1]);
  const [fromChain, setFromChain] = useState(chains[0]);
  const [toChain, setToChain] = useState(chains[1]);
  const [fromAmount, setFromAmount] = useState('');
  const [mevProtection, setMevProtection] = useState('protected');
  const [allowPartialFill, setAllowPartialFill] = useState(true);
  const [showSettings, setShowSettings] = useState(false);
  const [showTokenSelect, setShowTokenSelect] = useState<'from' | 'to' | null>(null);

  const toAmount = fromAmount ? (parseFloat(fromAmount) * 2450).toFixed(2) : '';

  const handleSwapTokens = () => {
    const tempToken = fromToken;
    setFromToken(toToken);
    setToToken(tempToken);
    const tempChain = fromChain;
    setFromChain(toChain);
    setToChain(tempChain);
  };

  return (
    <div className="max-w-lg mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="glass rounded-3xl p-6"
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-bold text-white">Swap</h1>
          <button
            onClick={() => setShowSettings(!showSettings)}
            className={`p-2 rounded-xl transition-colors ${showSettings ? 'bg-flow-blue/20 text-flow-blue' : 'hover:bg-white/10 text-gray-400'}`}
          >
            <Settings className="w-5 h-5" />
          </button>
        </div>

        {/* Settings Panel */}
        <AnimatePresence>
          {showSettings && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="overflow-hidden mb-6"
            >
              <div className="bg-dark-700/50 rounded-2xl p-4 space-y-4">
                <div>
                  <label className="text-sm text-gray-400 mb-2 block">MEV Protection</label>
                  <div className="grid grid-cols-2 gap-2">
                    {mevOptions.map((option) => (
                      <button
                        key={option.id}
                        onClick={() => setMevProtection(option.id)}
                        className={`p-3 rounded-xl text-left transition-all ${
                          mevProtection === option.id
                            ? 'bg-flow-blue/20 border border-flow-blue'
                            : 'bg-dark-600/50 border border-transparent hover:border-white/10'
                        }`}
                      >
                        <div className="flex items-center gap-2 mb-1">
                          <option.icon className={`w-4 h-4 ${mevProtection === option.id ? 'text-flow-blue' : 'text-gray-400'}`} />
                          <span className={`text-sm font-medium ${mevProtection === option.id ? 'text-white' : 'text-gray-300'}`}>
                            {option.label}
                          </span>
                        </div>
                        <p className="text-xs text-gray-500">{option.desc}</p>
                      </button>
                    ))}
                  </div>
                </div>
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-300">Allow Partial Fill</p>
                    <p className="text-xs text-gray-500">Accept best available if full fill unavailable</p>
                  </div>
                  <button
                    onClick={() => setAllowPartialFill(!allowPartialFill)}
                    className={`w-12 h-6 rounded-full transition-colors ${allowPartialFill ? 'bg-flow-blue' : 'bg-dark-500'}`}
                  >
                    <motion.div
                      className="w-5 h-5 bg-white rounded-full shadow-lg"
                      animate={{ x: allowPartialFill ? 26 : 2 }}
                    />
                  </button>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* From Input */}
        <div className="bg-dark-700/50 rounded-2xl p-4 mb-2">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">From</span>
            <div className="flex items-center gap-2">
              <button className="flex items-center gap-1 text-sm text-gray-400 hover:text-white transition-colors">
                <span>{fromChain.icon}</span>
                <span>{fromChain.name}</span>
                <ChevronDown className="w-3 h-3" />
              </button>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <input
              type="number"
              value={fromAmount}
              onChange={(e) => setFromAmount(e.target.value)}
              placeholder="0.0"
              className="flex-1 bg-transparent text-3xl font-bold text-white outline-none placeholder-gray-600"
            />
            <button
              onClick={() => setShowTokenSelect('from')}
              className="flex items-center gap-2 px-4 py-2 rounded-xl bg-dark-600 hover:bg-dark-500 transition-colors"
            >
              <span className="text-xl">{fromToken.icon}</span>
              <span className="font-medium text-white">{fromToken.symbol}</span>
              <ChevronDown className="w-4 h-4 text-gray-400" />
            </button>
          </div>
          <div className="flex items-center justify-between mt-2">
            <span className="text-sm text-gray-500">
              {fromAmount ? `~$${(parseFloat(fromAmount) * 2450).toLocaleString()}` : ''}
            </span>
            <button className="text-sm text-flow-blue hover:text-flow-purple transition-colors">
              Balance: {fromToken.balance} {fromToken.symbol}
            </button>
          </div>
        </div>

        {/* Swap Button */}
        <div className="flex justify-center -my-3 relative z-10">
          <motion.button
            onClick={handleSwapTokens}
            className="w-12 h-12 rounded-xl bg-dark-700 border border-dark-500 flex items-center justify-center hover:bg-dark-600 transition-colors"
            whileHover={{ scale: 1.1, rotate: 180 }}
            whileTap={{ scale: 0.9 }}
          >
            <ArrowDownUp className="w-5 h-5 text-gray-400" />
          </motion.button>
        </div>

        {/* To Input */}
        <div className="bg-dark-700/50 rounded-2xl p-4 mt-2">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">To</span>
            <div className="flex items-center gap-2">
              <button className="flex items-center gap-1 text-sm text-gray-400 hover:text-white transition-colors">
                <span>{toChain.icon}</span>
                <span>{toChain.name}</span>
                <ChevronDown className="w-3 h-3" />
              </button>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <input
              type="text"
              value={toAmount}
              readOnly
              placeholder="0.0"
              className="flex-1 bg-transparent text-3xl font-bold text-white outline-none placeholder-gray-600"
            />
            <button
              onClick={() => setShowTokenSelect('to')}
              className="flex items-center gap-2 px-4 py-2 rounded-xl bg-dark-600 hover:bg-dark-500 transition-colors"
            >
              <span className="text-xl">{toToken.icon}</span>
              <span className="font-medium text-white">{toToken.symbol}</span>
              <ChevronDown className="w-4 h-4 text-gray-400" />
            </button>
          </div>
          <div className="flex items-center justify-between mt-2">
            <span className="text-sm text-gray-500">
              {toAmount ? `~$${parseFloat(toAmount).toLocaleString()}` : ''}
            </span>
            <span className="text-sm text-gray-500">
              Balance: {toToken.balance} {toToken.symbol}
            </span>
          </div>
        </div>

        {/* Route Info */}
        {fromAmount && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            className="mt-4 bg-dark-700/30 rounded-xl p-4"
          >
            <div className="flex items-center justify-between text-sm mb-2">
              <span className="text-gray-400">Rate</span>
              <span className="text-white">1 {fromToken.symbol} = 2,450 {toToken.symbol}</span>
            </div>
            <div className="flex items-center justify-between text-sm mb-2">
              <span className="text-gray-400">Price Impact</span>
              <span className="text-flow-emerald">{'<'}0.01%</span>
            </div>
            <div className="flex items-center justify-between text-sm mb-2">
              <span className="text-gray-400">Est. Time</span>
              <div className="flex items-center gap-1 text-white">
                <Clock className="w-3 h-3" />
                <span>~2 min</span>
              </div>
            </div>
            {fromChain.id !== toChain.id && (
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Bridge</span>
                <span className="text-flow-blue">deBridge (recommended)</span>
              </div>
            )}
          </motion.div>
        )}

        {/* Swap Button */}
        {wallet.isConnected ? (
          <motion.button
            className={`w-full mt-6 py-4 rounded-2xl font-semibold text-lg transition-all ${
              fromAmount
                ? 'bg-flow-gradient text-white btn-glow'
                : 'bg-dark-600 text-gray-500 cursor-not-allowed'
            }`}
            whileHover={fromAmount ? { scale: 1.02 } : {}}
            whileTap={fromAmount ? { scale: 0.98 } : {}}
            disabled={!fromAmount}
          >
            {fromAmount ? 'Swap' : 'Enter an amount'}
          </motion.button>
        ) : (
          <motion.button
            onClick={wallet.connect}
            className="w-full mt-6 py-4 rounded-2xl bg-flow-gradient text-white font-semibold text-lg btn-glow"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            Connect Wallet
          </motion.button>
        )}

        {/* Batch Info */}
        <div className="mt-4 flex items-center justify-center gap-2 text-sm text-gray-500">
          <div className="w-2 h-2 rounded-full bg-flow-emerald pulse-live" />
          <span>Next batch settles in 45s</span>
        </div>
      </motion.div>
    </div>
  );
}
