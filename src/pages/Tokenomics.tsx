import { useState } from 'react';
import { motion } from 'framer-motion';
import { 
  Flame, 
  Lock, 
  Vote, 
  Gift, 
  ArrowRight,
  AlertTriangle,
  Clock,
  TrendingUp
} from 'lucide-react';
import { useStore } from '../store/useStore';

const lockDurations = [
  { years: 1, multiplier: 0.25, boost: '1.25x' },
  { years: 2, multiplier: 0.50, boost: '1.50x' },
  { years: 3, multiplier: 0.75, boost: '2.00x' },
  { years: 4, multiplier: 1.00, boost: '2.50x' },
];

export default function Tokenomics() {
  const { wallet, token } = useStore();
  const [activeTab, setActiveTab] = useState<'burn' | 'lock' | 'claim'>('burn');
  const [burnAmount, setBurnAmount] = useState('');
  const [lockAmount, setLockAmount] = useState('');
  const [lockDuration, setLockDuration] = useState(4);

  const selectedDuration = lockDurations.find(d => d.years === lockDuration)!;
  const expectedVebLF = lockAmount ? parseFloat(lockAmount) * selectedDuration.multiplier : 0;

  if (!wallet.isConnected) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="text-center"
        >
          <h2 className="text-2xl font-bold text-white mb-4">Connect Wallet</h2>
          <p className="text-gray-400 mb-6">Connect your wallet to manage $LF tokens</p>
          <motion.button
            onClick={wallet.connect}
            className="px-6 py-3 rounded-xl bg-flow-gradient text-white font-medium btn-glow"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            Connect Wallet
          </motion.button>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">$LF Tokenomics</h1>
          <p className="text-gray-400">Burn, lock, and earn with the Liquid Flow token</p>
        </div>

        {/* Token Balances */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="glass rounded-2xl p-6"
          >
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 rounded-xl bg-flow-blue/20 flex items-center justify-center">
                <span className="text-2xl">🪙</span>
              </div>
              <div>
                <p className="text-sm text-gray-400">$LF Balance</p>
                <p className="text-2xl font-bold text-white">{parseFloat(token.lfBalance).toLocaleString()}</p>
              </div>
            </div>
            <p className="text-xs text-gray-500">Liquid, tradeable tokens</p>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
            className="glass rounded-2xl p-6"
          >
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 rounded-xl bg-flow-purple/20 flex items-center justify-center">
                <Flame className="w-6 h-6 text-flow-purple" />
              </div>
              <div>
                <p className="text-sm text-gray-400">$bLF Balance</p>
                <p className="text-2xl font-bold text-white">{parseFloat(token.blfBalance).toLocaleString()}</p>
              </div>
            </div>
            <p className="text-xs text-gray-500">Burned, committed tokens</p>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
            className="glass rounded-2xl p-6"
          >
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 rounded-xl bg-flow-pink/20 flex items-center justify-center">
                <Vote className="w-6 h-6 text-flow-pink" />
              </div>
              <div>
                <p className="text-sm text-gray-400">$vebLF Balance</p>
                <p className="text-2xl font-bold text-white">{parseFloat(token.veblfBalance).toLocaleString()}</p>
              </div>
            </div>
            <p className="text-xs text-gray-500">Voting power & fee share</p>
          </motion.div>
        </div>

        {/* Token Flow Diagram */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="glass rounded-2xl p-6 mb-8"
        >
          <h2 className="text-lg font-semibold text-white mb-4">Token Flow</h2>
          <div className="flex items-center justify-center gap-4 flex-wrap">
            <div className="text-center">
              <div className="w-16 h-16 rounded-2xl bg-flow-blue/20 flex items-center justify-center mx-auto mb-2">
                <span className="text-2xl">🪙</span>
              </div>
              <p className="text-sm font-medium text-white">$LF</p>
              <p className="text-xs text-gray-500">Liquid</p>
            </div>
            <div className="flex flex-col items-center">
              <ArrowRight className="w-6 h-6 text-gray-500" />
              <span className="text-xs text-flow-purple mt-1">Burn</span>
            </div>
            <div className="text-center">
              <div className="w-16 h-16 rounded-2xl bg-flow-purple/20 flex items-center justify-center mx-auto mb-2">
                <Flame className="w-8 h-8 text-flow-purple" />
              </div>
              <p className="text-sm font-medium text-white">$bLF</p>
              <p className="text-xs text-gray-500">Burned</p>
            </div>
            <div className="flex flex-col items-center">
              <ArrowRight className="w-6 h-6 text-gray-500" />
              <span className="text-xs text-flow-pink mt-1">Lock</span>
            </div>
            <div className="text-center">
              <div className="w-16 h-16 rounded-2xl bg-flow-pink/20 flex items-center justify-center mx-auto mb-2">
                <Vote className="w-8 h-8 text-flow-pink" />
              </div>
              <p className="text-sm font-medium text-white">$vebLF</p>
              <p className="text-xs text-gray-500">Vote-Escrowed</p>
            </div>
          </div>
        </motion.div>

        {/* Tabs */}
        <div className="flex gap-2 mb-6">
          {[
            { id: 'burn', label: 'Burn LF', icon: Flame },
            { id: 'lock', label: 'Lock bLF', icon: Lock },
            { id: 'claim', label: 'Claim Rewards', icon: Gift },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl transition-colors ${
                activeTab === tab.id
                  ? 'bg-flow-gradient text-white'
                  : 'bg-dark-700 text-gray-400 hover:text-white'
              }`}
            >
              <tab.icon className="w-4 h-4" />
              <span>{tab.label}</span>
            </button>
          ))}
        </div>

        {/* Tab Content */}
        <motion.div
          key={activeTab}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="glass rounded-2xl p-6"
        >
          {activeTab === 'burn' && (
            <div>
              <h3 className="text-xl font-semibold text-white mb-4">Burn $LF → $bLF</h3>
              <div className="bg-amber-500/10 border border-amber-500/20 rounded-xl p-4 mb-6">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="text-amber-500 font-medium">Irreversible Action</p>
                    <p className="text-sm text-amber-500/70">Burning $LF is permanent. You will receive $bLF which cannot be converted back to $LF.</p>
                  </div>
                </div>
              </div>
              <div className="bg-dark-700/50 rounded-xl p-4 mb-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm text-gray-400">Amount to Burn</span>
                  <button 
                    onClick={() => setBurnAmount(token.lfBalance)}
                    className="text-sm text-flow-blue hover:text-flow-purple"
                  >
                    Max: {parseFloat(token.lfBalance).toLocaleString()} LF
                  </button>
                </div>
                <input
                  type="number"
                  value={burnAmount}
                  onChange={(e) => setBurnAmount(e.target.value)}
                  placeholder="0.0"
                  className="w-full bg-transparent text-2xl font-bold text-white outline-none placeholder-gray-600"
                />
              </div>
              <div className="flex items-center justify-between p-4 bg-dark-700/30 rounded-xl mb-6">
                <span className="text-gray-400">You will receive</span>
                <span className="text-xl font-bold text-white">{burnAmount || '0'} bLF</span>
              </div>
              <motion.button
                className={`w-full py-4 rounded-xl font-semibold ${
                  burnAmount ? 'bg-flow-gradient text-white btn-glow' : 'bg-dark-600 text-gray-500'
                }`}
                whileHover={burnAmount ? { scale: 1.02 } : {}}
                whileTap={burnAmount ? { scale: 0.98 } : {}}
                disabled={!burnAmount}
              >
                Burn $LF
              </motion.button>
            </div>
          )}

          {activeTab === 'lock' && (
            <div>
              <h3 className="text-xl font-semibold text-white mb-4">Lock $bLF → $vebLF</h3>
              <div className="bg-dark-700/50 rounded-xl p-4 mb-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm text-gray-400">Amount to Lock</span>
                  <button 
                    onClick={() => setLockAmount(token.blfBalance)}
                    className="text-sm text-flow-blue hover:text-flow-purple"
                  >
                    Max: {parseFloat(token.blfBalance).toLocaleString()} bLF
                  </button>
                </div>
                <input
                  type="number"
                  value={lockAmount}
                  onChange={(e) => setLockAmount(e.target.value)}
                  placeholder="0.0"
                  className="w-full bg-transparent text-2xl font-bold text-white outline-none placeholder-gray-600"
                />
              </div>

              <div className="mb-4">
                <label className="text-sm text-gray-400 mb-3 block">Lock Duration</label>
                <div className="grid grid-cols-4 gap-2">
                  {lockDurations.map((duration) => (
                    <button
                      key={duration.years}
                      onClick={() => setLockDuration(duration.years)}
                      className={`p-3 rounded-xl text-center transition-all ${
                        lockDuration === duration.years
                          ? 'bg-flow-purple/20 border-2 border-flow-purple'
                          : 'bg-dark-700/50 border-2 border-transparent hover:border-white/10'
                      }`}
                    >
                      <p className="text-lg font-bold text-white">{duration.years}Y</p>
                      <p className="text-xs text-gray-500">{duration.multiplier}x vebLF</p>
                      <p className="text-xs text-flow-emerald">{duration.boost} boost</p>
                    </button>
                  ))}
                </div>
              </div>

              <div className="bg-gradient-to-r from-flow-purple/10 to-flow-pink/10 rounded-xl p-4 mb-6">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-gray-400">You will receive</p>
                    <p className="text-2xl font-bold text-white">{expectedVebLF.toFixed(2)} vebLF</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">LP Boost</p>
                    <p className="text-2xl font-bold text-flow-emerald">{selectedDuration.boost}</p>
                  </div>
                </div>
              </div>

              <motion.button
                className={`w-full py-4 rounded-xl font-semibold ${
                  lockAmount ? 'bg-flow-gradient text-white btn-glow' : 'bg-dark-600 text-gray-500'
                }`}
                whileHover={lockAmount ? { scale: 1.02 } : {}}
                whileTap={lockAmount ? { scale: 0.98 } : {}}
                disabled={!lockAmount}
              >
                Lock $bLF for {lockDuration} Year{lockDuration > 1 ? 's' : ''}
              </motion.button>
            </div>
          )}

          {activeTab === 'claim' && (
            <div>
              <h3 className="text-xl font-semibold text-white mb-4">Claim Rewards</h3>
              <div className="space-y-3 mb-6">
                {Object.entries(token.pendingFees).map(([tokenSymbol, amount]) => (
                  <div key={tokenSymbol} className="flex items-center justify-between p-4 bg-dark-700/50 rounded-xl">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-full bg-flow-blue/20 flex items-center justify-center">
                        <span className="font-bold text-sm">{tokenSymbol.charAt(0)}</span>
                      </div>
                      <div>
                        <p className="font-medium text-white">{tokenSymbol}</p>
                        <p className="text-sm text-gray-500">Protocol fees</p>
                      </div>
                    </div>
                    <p className="text-lg font-bold text-white">{amount}</p>
                  </div>
                ))}
                <div className="flex items-center justify-between p-4 bg-gradient-to-r from-flow-purple/10 to-flow-pink/10 rounded-xl">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-flow-purple/20 flex items-center justify-center">
                      <TrendingUp className="w-5 h-5 text-flow-purple" />
                    </div>
                    <div>
                      <p className="font-medium text-white">IL Compensation</p>
                      <p className="text-sm text-gray-500">Based on tracked IL</p>
                    </div>
                  </div>
                  <p className="text-lg font-bold text-flow-purple">50.25 LF</p>
                </div>
              </div>
              <motion.button
                className="w-full py-4 rounded-xl bg-flow-gradient text-white font-semibold btn-glow"
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                Claim All Rewards
              </motion.button>
            </div>
          )}
        </motion.div>
      </motion.div>
    </div>
  );
}
