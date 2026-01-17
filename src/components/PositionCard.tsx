import { motion } from 'framer-motion';
import { ExternalLink, TrendingUp, TrendingDown, Activity } from 'lucide-react';

interface Position {
  id: string;
  chain: string;
  strategy: string;
  strategyHash: string;
  token0: { address: string; symbol: string; amount: string; };
  token1: { address: string; symbol: string; amount: string; };
  feeTier: number;
  earnedFees24h: number;
  earnedFeesTotal: number;
  impermanentLoss: number;
  utilization24h: number;
  valueUSD: number;
}

interface PositionCardProps {
  position: Position;
  index: number;
}

const chainIcons: { [key: string]: string } = {
  ethereum: '⟠',
  arbitrum: '🔵',
  base: '🔷',
  optimism: '🔴',
  polygon: '🟣',
};

export default function PositionCard({ position, index }: PositionCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: index * 0.1 }}
      className="glass rounded-2xl p-5 card-hover"
    >
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="flex -space-x-2">
            <div className="w-10 h-10 rounded-full bg-flow-blue/20 flex items-center justify-center text-lg font-bold border-2 border-dark-800">
              {position.token0.symbol.charAt(0)}
            </div>
            <div className="w-10 h-10 rounded-full bg-flow-purple/20 flex items-center justify-center text-lg font-bold border-2 border-dark-800">
              {position.token1.symbol.charAt(0)}
            </div>
          </div>
          <div>
            <h3 className="font-semibold text-white">
              {position.token0.symbol}/{position.token1.symbol}
            </h3>
            <div className="flex items-center gap-2 text-sm text-gray-400">
              <span>{chainIcons[position.chain]}</span>
              <span className="capitalize">{position.chain}</span>
              <span className="text-gray-600">•</span>
              <span>{position.feeTier / 100}% fee</span>
            </div>
          </div>
        </div>
        <div className="text-right">
          <p className="text-lg font-bold text-white">${position.valueUSD.toLocaleString()}</p>
          <p className="text-sm text-gray-400">Total Value</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div className="bg-dark-700/50 rounded-xl p-3">
          <p className="text-xs text-gray-400 mb-1">Token Amounts</p>
          <p className="text-sm text-white">{position.token0.amount} {position.token0.symbol}</p>
          <p className="text-sm text-white">{position.token1.amount} {position.token1.symbol}</p>
        </div>
        <div className="bg-dark-700/50 rounded-xl p-3">
          <p className="text-xs text-gray-400 mb-1">Fees Earned</p>
          <p className="text-sm text-flow-emerald">+${position.earnedFees24h.toFixed(2)} (24h)</p>
          <p className="text-sm text-gray-300">${position.earnedFeesTotal.toFixed(2)} total</p>
        </div>
      </div>

      <div className="flex items-center justify-between pt-4 border-t border-white/5">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-1">
            {position.impermanentLoss < 0 ? (
              <TrendingDown className="w-4 h-4 text-red-400" />
            ) : (
              <TrendingUp className="w-4 h-4 text-flow-emerald" />
            )}
            <span className={`text-sm ${position.impermanentLoss < 0 ? 'text-red-400' : 'text-flow-emerald'}`}>
              {position.impermanentLoss.toFixed(2)}% IL
            </span>
          </div>
          <div className="flex items-center gap-1">
            <Activity className="w-4 h-4 text-flow-cyan" />
            <span className="text-sm text-gray-300">
              {(position.utilization24h * 100).toFixed(0)}% utilized
            </span>
          </div>
        </div>
        <button className="flex items-center gap-1 text-sm text-flow-blue hover:text-flow-purple transition-colors">
          <span>Manage</span>
          <ExternalLink className="w-3 h-3" />
        </button>
      </div>
    </motion.div>
  );
}
