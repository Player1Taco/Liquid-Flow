import { useState } from 'react';
import { motion } from 'framer-motion';
import { 
  Vote, 
  Clock, 
  CheckCircle, 
  XCircle,
  Users,
  FileText,
  ExternalLink
} from 'lucide-react';
import { useStore } from '../store/useStore';

const proposals = [
  {
    id: 1,
    title: 'LFP-1: Increase Protocol Fee to 12%',
    description: 'Proposal to increase the protocol fee from 10% to 12% of LP fees to fund development and security audits.',
    status: 'active',
    votesFor: 1250000,
    votesAgainst: 450000,
    endTime: Date.now() + 3 * 24 * 60 * 60 * 1000,
    quorum: 2000000,
  },
  {
    id: 2,
    title: 'LFP-2: Add Polygon zkEVM Support',
    description: 'Deploy Liquid Flow contracts to Polygon zkEVM to expand cross-chain liquidity.',
    status: 'active',
    votesFor: 890000,
    votesAgainst: 120000,
    endTime: Date.now() + 5 * 24 * 60 * 60 * 1000,
    quorum: 2000000,
  },
  {
    id: 3,
    title: 'LFP-0: Genesis Parameters',
    description: 'Initial protocol parameters including fee structure, emission schedule, and governance thresholds.',
    status: 'passed',
    votesFor: 3500000,
    votesAgainst: 200000,
    endTime: Date.now() - 7 * 24 * 60 * 60 * 1000,
    quorum: 2000000,
  },
];

export default function Governance() {
  const { wallet, token } = useStore();
  const [selectedProposal, setSelectedProposal] = useState<number | null>(null);

  const formatNumber = (num: number) => {
    if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
    if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
    return num.toString();
  };

  const formatTimeRemaining = (endTime: number) => {
    const diff = endTime - Date.now();
    if (diff <= 0) return 'Ended';
    const days = Math.floor(diff / (24 * 60 * 60 * 1000));
    const hours = Math.floor((diff % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    return `${days}d ${hours}h remaining`;
  };

  if (!wallet.isConnected) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="text-center"
        >
          <Vote className="w-16 h-16 text-flow-purple mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-white mb-4">Governance</h2>
          <p className="text-gray-400 mb-6">Connect your wallet to participate in governance</p>
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
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Governance</h1>
            <p className="text-gray-400">Vote on proposals with your vebLF</p>
          </div>
          <motion.button
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-flow-gradient text-white font-medium btn-glow"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            <FileText className="w-4 h-4" />
            <span>Create Proposal</span>
          </motion.button>
        </div>

        {/* Voting Power */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="glass rounded-2xl p-6 mb-8"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="w-14 h-14 rounded-2xl bg-flow-purple/20 flex items-center justify-center">
                <Vote className="w-7 h-7 text-flow-purple" />
              </div>
              <div>
                <p className="text-sm text-gray-400">Your Voting Power</p>
                <p className="text-3xl font-bold text-white">{formatNumber(token.votingPower)} vebLF</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-sm text-gray-400">% of Total</p>
              <p className="text-xl font-bold text-flow-purple">0.15%</p>
            </div>
          </div>
        </motion.div>

        {/* Proposals */}
        <div className="space-y-4">
          <h2 className="text-xl font-semibold text-white">Proposals</h2>
          {proposals.map((proposal, index) => (
            <motion.div
              key={proposal.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 + index * 0.1 }}
              className="glass rounded-2xl p-6 card-hover cursor-pointer"
              onClick={() => setSelectedProposal(selectedProposal === proposal.id ? null : proposal.id)}
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    <span className={`px-2 py-1 rounded-lg text-xs font-medium ${
                      proposal.status === 'active' 
                        ? 'bg-flow-blue/20 text-flow-blue' 
                        : proposal.status === 'passed'
                        ? 'bg-flow-emerald/20 text-flow-emerald'
                        : 'bg-red-500/20 text-red-400'
                    }`}>
                      {proposal.status.charAt(0).toUpperCase() + proposal.status.slice(1)}
                    </span>
                    {proposal.status === 'active' && (
                      <span className="flex items-center gap-1 text-xs text-gray-500">
                        <Clock className="w-3 h-3" />
                        {formatTimeRemaining(proposal.endTime)}
                      </span>
                    )}
                  </div>
                  <h3 className="text-lg font-semibold text-white mb-2">{proposal.title}</h3>
                  <p className="text-sm text-gray-400">{proposal.description}</p>
                </div>
              </div>

              {/* Vote Progress */}
              <div className="mb-4">
                <div className="flex items-center justify-between text-sm mb-2">
                  <span className="text-flow-emerald flex items-center gap-1">
                    <CheckCircle className="w-4 h-4" />
                    For: {formatNumber(proposal.votesFor)}
                  </span>
                  <span className="text-red-400 flex items-center gap-1">
                    Against: {formatNumber(proposal.votesAgainst)}
                    <XCircle className="w-4 h-4" />
                  </span>
                </div>
                <div className="h-3 bg-dark-600 rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-gradient-to-r from-flow-emerald to-flow-blue rounded-full"
                    style={{ 
                      width: `${(proposal.votesFor / (proposal.votesFor + proposal.votesAgainst)) * 100}%` 
                    }}
                  />
                </div>
                <div className="flex items-center justify-between text-xs text-gray-500 mt-1">
                  <span>Quorum: {formatNumber(proposal.quorum)}</span>
                  <span>{((proposal.votesFor + proposal.votesAgainst) / proposal.quorum * 100).toFixed(1)}% reached</span>
                </div>
              </div>

              {/* Vote Buttons */}
              {proposal.status === 'active' && selectedProposal === proposal.id && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  className="flex gap-3 pt-4 border-t border-white/5"
                >
                  <motion.button
                    className="flex-1 py-3 rounded-xl bg-flow-emerald/20 text-flow-emerald font-medium hover:bg-flow-emerald/30 transition-colors"
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                  >
                    <CheckCircle className="w-4 h-4 inline mr-2" />
                    Vote For
                  </motion.button>
                  <motion.button
                    className="flex-1 py-3 rounded-xl bg-red-500/20 text-red-400 font-medium hover:bg-red-500/30 transition-colors"
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                  >
                    <XCircle className="w-4 h-4 inline mr-2" />
                    Vote Against
                  </motion.button>
                </motion.div>
              )}
            </motion.div>
          ))}
        </div>
      </motion.div>
    </div>
  );
}
