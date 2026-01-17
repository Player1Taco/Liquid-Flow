import { useState } from 'react';
import { motion } from 'framer-motion';
import { 
  Plus, 
  Minus, 
  ChevronDown, 
  Info, 
  Zap,
  Shield,
  TrendingUp
} from 'lucide-react';
import { useStore } from '../store/useStore';

const tokens = [
  { symbol: 'ETH', name: 'Ethereum', icon: '⟠', balance: '2.5' },
  { symbol: 'USDC', name: 'USD Coin', icon: '💵', balance: '5000' },
  { symbol: 'ARB', name: 'Arbitrum', icon: '🔵', balance: '1500' },
  { symbol: 'WBTC', name: 'Wrapped Bitcoin', icon: '₿', balance: '0.15' },
];

const feeTiers = [
  { value: 5, label: '0.05%', desc: 'Best for stable pairs' },
  { value: 30, label: '0.30%', desc: 'Best for most pairs' },
  { value: 100, label: '1.00%', desc: 'Best for exotic pairs' },
];

const chains = [
  { id: 42161, name: 'Arbitrum', icon: '🔵', allocation: 40 },
  { id: 8453, name: 'Base', icon: '🔷', allocation: 30 },
  { id: 1, name: 'Ethereum', icon: '⟠', allocation: 20 },
  { id: 10, name: 'Optimism', icon: '🔴', allocation: 10 },
];

export default function Provide() {
  const { wallet } = useStore();
  const [token0, setToken0] = useState(tokens[0]);
  const [token1, setToken1] = useState(tokens[1]);
  const [amount0, setAmount0] = useState('');
  const [amount1, setAmount1] = useState('');
  const [feeTier, setFeeTier] = useState(30);
  const [mode, setMode] = useState<'simple' | 'advanced'>('simple');
  const [chainAllocations, setChainAllocations] = useState(chains);

  const estimatedAPY = 12.5;
  const estimatedDailyEarnings = amount0 ? parseFloat(amount0) * 2450 * (estimatedAPY / 100 / 365) : 0;

  return (
    <div className="max-w-2xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Provide Liquidity</h1>
            <p className="text-gray-400">Earn fees from swaps across all chains</p>
          </div>
          <div className="flex items-center gap-2 bg-dark-700 rounded-xl p-1">
            <button
              onClick={() => setMode('simple')}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                mode === 'simple' ? 'bg-flow-blue text-white' : 'text-gray-400 hover:text-white'
              }`}
            >
              Simple
            </button>
            <button
              onClick={() => setMode('advanced')}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                mode === 'advanced' ? 'bg-flow-blue text-white' : 'text-gray-400 hover:text-white'
              }`}
            >
              Advanced
            </button>
          </div>
        </div>

        <div className="glass rounded-3xl p-6">
          {/* Token Selection */}
          <div className="space-y-4 mb-6">
            <div className="bg-dark-700/50 rounded-2xl p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm text-gray-400">Token 1</span>
                <span className="text-sm text-gray-500">Balance: {token0.balance}</span>
              </div>
              <div className="flex items-center gap-4">
                <input
                  type="number"
                  value={amount0}
                  onChange={(e) => {
                    setAmount0(e.target.value);
                    if (e.target.value) {
                      setAmount1((parseFloat(e.target.value) * 2450).toString());
                    } else {
                      setAmount1('');
                    }
                  }}
                  placeholder="0.0"
                  className="flex-1 bg-transparent text-2xl font-bold text-white outline-none placeholder-gray-600"
                />
                <button className="flex items-center gap-2 px-4 py-2 rounded-xl bg-dark-600 hover:bg-dark-500 transition-colors">
                  <span className="text-xl">{token0.icon}</span>
                  <span className="font-medium text-white">{token0.symbol}</span>
                  <ChevronDown className="w-4 h-4 text-gray-400" />
                </button>
              </div>
            </div>

            <div className="flex justify-center">
              <div className="w-10 h-10 rounded-xl bg-dark-700 flex items-center justify-center">
                <Plus className="w-5 h-5 text-gray-400" />
              </div>
            </div>

            <div className="bg-dark-700/50 rounded-2xl p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm text-gray-400">Token 2</span>
                <span className="text-sm text-gray-500">Balance: {token1.balance}</span>
              </div>
              <div className="flex items-center gap-4">
                <input
                  type="number"
                  value={amount1}
                  onChange={(e) => setAmount1(e.target.value)}
                  placeholder="0.0"
                  className="flex-1 bg-transparent text-2xl font-bold text-white outline-none placeholder-gray-600"
                />
                <button className="flex items-center gap-2 px-4 py-2 rounded-xl bg-dark-600 hover:bg-dark-500 transition-colors">
                  <span className="text-xl">{token1.icon}</span>
                  <span className="font-medium text-white">{token1.symbol}</span>
                  <ChevronDown className="w-4 h-4 text-gray-400" />
                </button>
              </div>
            </div>
          </div>

          {/* Fee Tier Selection */}
          <div className="mb-6">
            <label className="text-sm text-gray-400 mb-3 block">Fee Tier</label>
            <div className="grid grid-cols-3 gap-3">
              {feeTiers.map((tier) => (
                <button
                  key={tier.value}
                  onClick={() => setFeeTier(tier.value)}
                  className={`p-4 rounded-xl text-center transition-all ${
                    feeTier === tier.value
                      ? 'bg-flow-blue/20 border-2 border-flow-blue'
                      : 'bg-dark-700/50 border-2 border-transparent hover:border-white/10'
                  }`}
                >
                  <p className={`text-lg font-bold ${feeTier === tier.value ? 'text-white' : 'text-gray-300'}`}>
                    {tier.label}
                  </p>
                  <p className="text-xs text-gray-500 mt-1">{tier.desc}</p>
                </button>
              ))}
            </div>
          </div>

          {/* Advanced: Chain Allocation */}
          {mode === 'advanced' && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              className="mb-6"
            >
              <label className="text-sm text-gray-400 mb-3 block">Chain Allocation</label>
              <div className="space-y-3">
                {chainAllocations.map((chain, index) => (
                  <div key={chain.id} className="flex items-center gap-4">
                    <div className="flex items-center gap-2 w-32">
                      <span className="text-lg">{chain.icon}</span>
                      <span className="text-sm text-gray-300">{chain.name}</span>
                    </div>
                    <div className="flex-1">
                      <input
                        type="range"
                        min="0"
                        max="100"
                        value={chain.allocation}
                        onChange={(e) => {
                          const newAllocations = [...chainAllocations];
                          newAllocations[index].allocation = parseInt(e.target.value);
                          setChainAllocations(newAllocations);
                        }}
                        className="w-full h-2 bg-dark-600 rounded-lg appearance-none cursor-pointer"
                      />
                    </div>
                    <span className="text-sm text-white w-12 text-right">{chain.allocation}%</span>
                  </div>
                ))}
              </div>
            </motion.div>
          )}

          {/* Estimated Returns */}
          {amount0 && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="bg-gradient-to-r from-flow-blue/10 to-flow-purple/10 rounded-2xl p-4 mb-6"
            >
              <div className="flex items-center gap-2 mb-3">
                <TrendingUp className="w-5 h-5 text-flow-emerald" />
                <span className="font-medium text-white">Estimated Returns</span>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-gray-400">APY</p>
                  <p className="text-2xl font-bold text-flow-emerald">{estimatedAPY}%</p>
                </div>
                <div>
                  <p className="text-sm text-gray-400">Daily Earnings</p>
                  <p className="text-2xl font-bold text-white">${estimatedDailyEarnings.toFixed(2)}</p>
                </div>
              </div>
              <div className="flex items-start gap-2 mt-3 text-xs text-gray-500">
                <Info className="w-4 h-4 flex-shrink-0 mt-0.5" />
                <span>Estimates based on current volume. Actual returns may vary. Your liquidity will be available across all selected chains simultaneously.</span>
              </div>
            </motion.div>
          )}

          {/* Benefits */}
          <div className="grid grid-cols-3 gap-3 mb-6">
            <div className="bg-dark-700/30 rounded-xl p-3 text-center">
              <Zap className="w-5 h-5 text-flow-blue mx-auto mb-2" />
              <p className="text-xs text-gray-400">Capital Efficient</p>
            </div>
            <div className="bg-dark-700/30 rounded-xl p-3 text-center">
              <Shield className="w-5 h-5 text-flow-purple mx-auto mb-2" />
              <p className="text-xs text-gray-400">MEV Protected</p>
            </div>
            <div className="bg-dark-700/30 rounded-xl p-3 text-center">
              <TrendingUp className="w-5 h-5 text-flow-emerald mx-auto mb-2" />
              <p className="text-xs text-gray-400">Earn $LF Rewards</p>
            </div>
          </div>

          {/* Action Button */}
          {wallet.isConnected ? (
            <motion.button
              className={`w-full py-4 rounded-2xl font-semibold text-lg transition-all ${
                amount0 && amount1
                  ? 'bg-flow-gradient text-white btn-glow'
                  : 'bg-dark-600 text-gray-500 cursor-not-allowed'
              }`}
              whileHover={amount0 && amount1 ? { scale: 1.02 } : {}}
              whileTap={amount0 && amount1 ? { scale: 0.98 } : {}}
              disabled={!amount0 || !amount1}
            >
              {amount0 && amount1 ? 'Ship Strategy' : 'Enter amounts'}
            </motion.button>
          ) : (
            <motion.button
              onClick={wallet.connect}
              className="w-full py-4 rounded-2xl bg-flow-gradient text-white font-semibold text-lg btn-glow"
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
            >
              Connect Wallet
            </motion.button>
          )}
        </div>
      </motion.div>
    </div>
  );
}
