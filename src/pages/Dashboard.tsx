import { motion } from 'framer-motion';
import { 
  Wallet, 
  TrendingUp, 
  Coins, 
  Activity,
  Droplets,
  ArrowRight,
  Zap
} from 'lucide-react';
import { useStore } from '../store/useStore';
import StatCard from '../components/StatCard';
import PositionCard from '../components/PositionCard';
import { Link } from 'react-router-dom';

export default function Dashboard() {
  const { wallet, lp, token } = useStore();

  if (!wallet.isConnected) {
    return (
      <div className="min-h-[80vh] flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="text-center max-w-lg"
        >
          <motion.div
            className="w-24 h-24 mx-auto mb-8 rounded-3xl bg-flow-gradient flex items-center justify-center"
            animate={{ 
              boxShadow: [
                '0 0 40px rgba(59, 130, 246, 0.4)',
                '0 0 60px rgba(139, 92, 246, 0.6)',
                '0 0 40px rgba(59, 130, 246, 0.4)',
              ]
            }}
            transition={{ duration: 2, repeat: Infinity }}
          >
            <Droplets className="w-12 h-12 text-white" />
          </motion.div>
          <h1 className="text-4xl font-bold mb-4">
            <span className="gradient-text">Liquid Flow</span>
          </h1>
          <p className="text-gray-400 text-lg mb-8">
            The shared liquidity layer for DeFi. Provide liquidity once, earn from everywhere.
          </p>
          <motion.button
            onClick={wallet.connect}
            className="px-8 py-4 rounded-2xl bg-flow-gradient text-white font-semibold text-lg btn-glow"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            Connect Wallet to Start
          </motion.button>
          
          <div className="mt-12 grid grid-cols-3 gap-6">
            {[
              { label: 'Total Value Locked', value: '$142.5M' },
              { label: '24h Volume', value: '$28.3M' },
              { label: 'Active LPs', value: '12,450' },
            ].map((stat, i) => (
              <motion.div
                key={stat.label}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 + i * 0.1 }}
                className="glass rounded-xl p-4"
              >
                <p className="text-2xl font-bold text-white">{stat.value}</p>
                <p className="text-sm text-gray-400">{stat.label}</p>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">Dashboard</h1>
          <p className="text-gray-400">Overview of your Liquid Flow positions</p>
        </div>
        <Link to="/provide">
          <motion.button
            className="flex items-center gap-2 px-6 py-3 rounded-xl bg-flow-gradient text-white font-medium btn-glow"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            <Zap className="w-5 h-5" />
            <span>New Position</span>
          </motion.button>
        </Link>
      </motion.div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total Value"
          value={`$${lp.totalValueUSD.toLocaleString()}`}
          change={5.23}
          icon={<Wallet className="w-6 h-6 text-white" />}
          gradient="from-flow-blue to-flow-cyan"
          delay={0}
        />
        <StatCard
          title="24h Earnings"
          value={`$${lp.totalEarned24h.toFixed(2)}`}
          change={12.5}
          icon={<TrendingUp className="w-6 h-6 text-white" />}
          gradient="from-flow-emerald to-flow-cyan"
          delay={0.1}
        />
        <StatCard
          title="Pending $LF"
          value={`${lp.pendingRewards.toLocaleString()} LF`}
          icon={<Coins className="w-6 h-6 text-white" />}
          gradient="from-flow-purple to-flow-pink"
          delay={0.2}
        />
        <StatCard
          title="Active Strategies"
          value={lp.positions.length.toString()}
          icon={<Activity className="w-6 h-6 text-white" />}
          gradient="from-flow-pink to-flow-blue"
          delay={0.3}
        />
      </div>

      {/* Token Holdings */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.4 }}
        className="glass rounded-2xl p-6"
      >
        <h2 className="text-xl font-semibold text-white mb-4">$LF Token Holdings</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-dark-700/50 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="w-8 h-8 rounded-lg bg-flow-blue/20 flex items-center justify-center">
                <Coins className="w-4 h-4 text-flow-blue" />
              </div>
              <span className="text-gray-400">$LF Balance</span>
            </div>
            <p className="text-2xl font-bold text-white">{parseFloat(token.lfBalance).toLocaleString()}</p>
            <p className="text-sm text-gray-500">Liquid tokens</p>
          </div>
          <div className="bg-dark-700/50 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="w-8 h-8 rounded-lg bg-flow-purple/20 flex items-center justify-center">
                <Coins className="w-4 h-4 text-flow-purple" />
              </div>
              <span className="text-gray-400">$bLF Balance</span>
            </div>
            <p className="text-2xl font-bold text-white">{parseFloat(token.blfBalance).toLocaleString()}</p>
            <p className="text-sm text-gray-500">Burned tokens</p>
          </div>
          <div className="bg-dark-700/50 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="w-8 h-8 rounded-lg bg-flow-pink/20 flex items-center justify-center">
                <Coins className="w-4 h-4 text-flow-pink" />
              </div>
              <span className="text-gray-400">$vebLF Balance</span>
            </div>
            <p className="text-2xl font-bold text-white">{parseFloat(token.veblfBalance).toLocaleString()}</p>
            <p className="text-sm text-gray-500">Voting power</p>
          </div>
        </div>
        <Link to="/tokenomics" className="flex items-center gap-1 text-flow-blue hover:text-flow-purple transition-colors mt-4">
          <span>Manage tokens</span>
          <ArrowRight className="w-4 h-4" />
        </Link>
      </motion.div>

      {/* Positions */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.5 }}
      >
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-semibold text-white">Your Positions</h2>
          <div className="flex items-center gap-2">
            <span className="text-sm text-gray-400">{lp.positions.length} active</span>
          </div>
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {lp.positions.map((position, index) => (
            <PositionCard key={position.id} position={position} index={index} />
          ))}
        </div>
      </motion.div>
    </div>
  );
}
