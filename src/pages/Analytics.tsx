import { motion } from 'framer-motion';
import { 
  TrendingUp, 
  Users, 
  Activity, 
  DollarSign,
  BarChart3,
  PieChart
} from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';

const tvlData = [
  { date: 'Jan', tvl: 45 },
  { date: 'Feb', tvl: 62 },
  { date: 'Mar', tvl: 78 },
  { date: 'Apr', tvl: 95 },
  { date: 'May', tvl: 110 },
  { date: 'Jun', tvl: 142 },
];

const volumeData = [
  { date: 'Mon', volume: 12.5 },
  { date: 'Tue', volume: 18.2 },
  { date: 'Wed', volume: 15.8 },
  { date: 'Thu', volume: 22.4 },
  { date: 'Fri', volume: 28.3 },
  { date: 'Sat', volume: 19.6 },
  { date: 'Sun', volume: 14.2 },
];

const chainDistribution = [
  { chain: 'Arbitrum', tvl: 52, color: '#3B82F6' },
  { chain: 'Base', tvl: 28, color: '#8B5CF6' },
  { chain: 'Ethereum', tvl: 35, color: '#6366F1' },
  { chain: 'Optimism', tvl: 18, color: '#EC4899' },
  { chain: 'Polygon', tvl: 9, color: '#10B981' },
];

export default function Analytics() {
  const totalTVL = chainDistribution.reduce((sum, c) => sum + c.tvl, 0);

  return (
    <div className="space-y-8">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <h1 className="text-3xl font-bold text-white mb-2">Analytics</h1>
        <p className="text-gray-400">Protocol statistics and performance metrics</p>
      </motion.div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Total Value Locked', value: '$142.5M', change: '+12.5%', icon: DollarSign, color: 'from-flow-blue to-flow-cyan' },
          { label: '24h Volume', value: '$28.3M', change: '+8.2%', icon: Activity, color: 'from-flow-purple to-flow-pink' },
          { label: 'Active LPs', value: '12,450', change: '+156', icon: Users, color: 'from-flow-emerald to-flow-cyan' },
          { label: 'Total Strategies', value: '45,230', change: '+1,250', icon: BarChart3, color: 'from-flow-pink to-flow-purple' },
        ].map((stat, index) => (
          <motion.div
            key={stat.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
            className="glass rounded-2xl p-6"
          >
            <div className="flex items-start justify-between">
              <div>
                <p className="text-sm text-gray-400 mb-1">{stat.label}</p>
                <p className="text-2xl font-bold text-white">{stat.value}</p>
                <p className="text-sm text-flow-emerald mt-1">{stat.change}</p>
              </div>
              <div className={`w-12 h-12 rounded-xl bg-gradient-to-br ${stat.color} flex items-center justify-center`}>
                <stat.icon className="w-6 h-6 text-white" />
              </div>
            </div>
          </motion.div>
        ))}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* TVL Chart */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="glass rounded-2xl p-6"
        >
          <h2 className="text-lg font-semibold text-white mb-4">Total Value Locked</h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={tvlData}>
                <defs>
                  <linearGradient id="tvlGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3B82F6" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#3B82F6" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
                <XAxis dataKey="date" stroke="#6b7280" />
                <YAxis stroke="#6b7280" tickFormatter={(value) => `$${value}M`} />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: '#1a1a24', 
                    border: '1px solid #2a2a38',
                    borderRadius: '12px'
                  }}
                  formatter={(value: number) => [`$${value}M`, 'TVL']}
                />
                <Area 
                  type="monotone" 
                  dataKey="tvl" 
                  stroke="#3B82F6" 
                  strokeWidth={2}
                  fill="url(#tvlGradient)" 
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </motion.div>

        {/* Volume Chart */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="glass rounded-2xl p-6"
        >
          <h2 className="text-lg font-semibold text-white mb-4">Daily Volume</h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={volumeData}>
                <defs>
                  <linearGradient id="volumeGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#8B5CF6" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#8B5CF6" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a38" />
                <XAxis dataKey="date" stroke="#6b7280" />
                <YAxis stroke="#6b7280" tickFormatter={(value) => `$${value}M`} />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: '#1a1a24', 
                    border: '1px solid #2a2a38',
                    borderRadius: '12px'
                  }}
                  formatter={(value: number) => [`$${value}M`, 'Volume']}
                />
                <Area 
                  type="monotone" 
                  dataKey="volume" 
                  stroke="#8B5CF6" 
                  strokeWidth={2}
                  fill="url(#volumeGradient)" 
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </motion.div>
      </div>

      {/* Chain Distribution */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.6 }}
        className="glass rounded-2xl p-6"
      >
        <h2 className="text-lg font-semibold text-white mb-4">TVL by Chain</h2>
        <div className="space-y-4">
          {chainDistribution.map((chain, index) => (
            <div key={chain.chain}>
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-300">{chain.chain}</span>
                <span className="text-white font-medium">${chain.tvl}M ({((chain.tvl / totalTVL) * 100).toFixed(1)}%)</span>
              </div>
              <div className="h-3 bg-dark-600 rounded-full overflow-hidden">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${(chain.tvl / totalTVL) * 100}%` }}
                  transition={{ delay: 0.7 + index * 0.1, duration: 0.5 }}
                  className="h-full rounded-full"
                  style={{ backgroundColor: chain.color }}
                />
              </div>
            </div>
          ))}
        </div>
      </motion.div>

      {/* Top Pools */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.8 }}
        className="glass rounded-2xl p-6"
      >
        <h2 className="text-lg font-semibold text-white mb-4">Top Pools by Volume</h2>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="text-left text-sm text-gray-400 border-b border-white/5">
                <th className="pb-3">Pool</th>
                <th className="pb-3">Chain</th>
                <th className="pb-3">TVL</th>
                <th className="pb-3">24h Volume</th>
                <th className="pb-3">APY</th>
              </tr>
            </thead>
            <tbody>
              {[
                { pair: 'ETH/USDC', chain: 'Arbitrum', tvl: '$12.5M', volume: '$4.2M', apy: '18.5%' },
                { pair: 'ETH/USDC', chain: 'Base', tvl: '$8.2M', volume: '$3.1M', apy: '15.2%' },
                { pair: 'ARB/USDC', chain: 'Arbitrum', tvl: '$6.8M', volume: '$2.8M', apy: '22.4%' },
                { pair: 'WBTC/ETH', chain: 'Ethereum', tvl: '$5.4M', volume: '$1.9M', apy: '12.8%' },
                { pair: 'OP/USDC', chain: 'Optimism', tvl: '$4.1M', volume: '$1.5M', apy: '19.6%' },
              ].map((pool, index) => (
                <tr key={index} className="border-b border-white/5 hover:bg-white/5 transition-colors">
                  <td className="py-4 font-medium text-white">{pool.pair}</td>
                  <td className="py-4 text-gray-400">{pool.chain}</td>
                  <td className="py-4 text-white">{pool.tvl}</td>
                  <td className="py-4 text-white">{pool.volume}</td>
                  <td className="py-4 text-flow-emerald">{pool.apy}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </motion.div>
    </div>
  );
}
