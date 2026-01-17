import { create } from 'zustand';

interface WalletState {
  address: string | null;
  chainId: number | null;
  isConnected: boolean;
  connect: () => Promise<void>;
  disconnect: () => void;
  switchChain: (chainId: number) => Promise<void>;
}

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

interface LPState {
  positions: Position[];
  totalValueUSD: number;
  totalEarned24h: number;
  totalEarnedAll: number;
  pendingRewards: number;
  fetchPositions: (address: string) => Promise<void>;
}

interface TokenState {
  lfBalance: string;
  blfBalance: string;
  veblfBalance: string;
  lockEnd: number | null;
  votingPower: number;
  pendingFees: { [token: string]: string };
  fetchBalances: (address: string) => Promise<void>;
}

interface AppState {
  wallet: WalletState;
  lp: LPState;
  token: TokenState;
}

// Mock data for demonstration
const mockPositions: Position[] = [
  {
    id: '1',
    chain: 'arbitrum',
    strategy: 'XYK',
    strategyHash: '0x1234...5678',
    token0: { address: '0x...', symbol: 'WETH', amount: '10.5' },
    token1: { address: '0x...', symbol: 'USDC', amount: '25000' },
    feeTier: 30,
    earnedFees24h: 125.50,
    earnedFeesTotal: 4520.00,
    impermanentLoss: -2.3,
    utilization24h: 0.45,
    valueUSD: 52500,
  },
  {
    id: '2',
    chain: 'base',
    strategy: 'XYK',
    strategyHash: '0x2345...6789',
    token0: { address: '0x...', symbol: 'WETH', amount: '5.2' },
    token1: { address: '0x...', symbol: 'USDC', amount: '12500' },
    feeTier: 30,
    earnedFees24h: 85.25,
    earnedFeesTotal: 2150.00,
    impermanentLoss: -1.1,
    utilization24h: 0.62,
    valueUSD: 26000,
  },
  {
    id: '3',
    chain: 'ethereum',
    strategy: 'XYK',
    strategyHash: '0x3456...7890',
    token0: { address: '0x...', symbol: 'ARB', amount: '15000' },
    token1: { address: '0x...', symbol: 'USDC', amount: '18000' },
    feeTier: 100,
    earnedFees24h: 210.00,
    earnedFeesTotal: 8900.00,
    impermanentLoss: -4.5,
    utilization24h: 0.78,
    valueUSD: 36000,
  },
];

export const useStore = create<AppState>((set, get) => ({
  wallet: {
    address: null,
    chainId: null,
    isConnected: false,
    connect: async () => {
      // Mock wallet connection
      await new Promise(resolve => setTimeout(resolve, 1000));
      set(state => ({
        wallet: {
          ...state.wallet,
          address: '0x742d35Cc6634C0532925a3b844Bc9e7595f8fE21',
          chainId: 42161,
          isConnected: true,
        }
      }));
      // Fetch data after connection
      get().lp.fetchPositions('0x742d35Cc6634C0532925a3b844Bc9e7595f8fE21');
      get().token.fetchBalances('0x742d35Cc6634C0532925a3b844Bc9e7595f8fE21');
    },
    disconnect: () => {
      set(state => ({
        wallet: {
          ...state.wallet,
          address: null,
          chainId: null,
          isConnected: false,
        },
        lp: {
          ...state.lp,
          positions: [],
          totalValueUSD: 0,
          totalEarned24h: 0,
          totalEarnedAll: 0,
          pendingRewards: 0,
        }
      }));
    },
    switchChain: async (chainId: number) => {
      await new Promise(resolve => setTimeout(resolve, 500));
      set(state => ({
        wallet: { ...state.wallet, chainId }
      }));
    },
  },
  lp: {
    positions: [],
    totalValueUSD: 0,
    totalEarned24h: 0,
    totalEarnedAll: 0,
    pendingRewards: 0,
    fetchPositions: async (address: string) => {
      await new Promise(resolve => setTimeout(resolve, 800));
      const totalValue = mockPositions.reduce((sum, p) => sum + p.valueUSD, 0);
      const earned24h = mockPositions.reduce((sum, p) => sum + p.earnedFees24h, 0);
      const earnedAll = mockPositions.reduce((sum, p) => sum + p.earnedFeesTotal, 0);
      set(state => ({
        lp: {
          ...state.lp,
          positions: mockPositions,
          totalValueUSD: totalValue,
          totalEarned24h: earned24h,
          totalEarnedAll: earnedAll,
          pendingRewards: 1250.5,
        }
      }));
    },
  },
  token: {
    lfBalance: '0',
    blfBalance: '0',
    veblfBalance: '0',
    lockEnd: null,
    votingPower: 0,
    pendingFees: {},
    fetchBalances: async (address: string) => {
      await new Promise(resolve => setTimeout(resolve, 600));
      set(state => ({
        token: {
          ...state.token,
          lfBalance: '5420.50',
          blfBalance: '2500.00',
          veblfBalance: '1875.00',
          lockEnd: Date.now() + 365 * 24 * 60 * 60 * 1000 * 2, // 2 years from now
          votingPower: 1875,
          pendingFees: {
            USDC: '125.50',
            WETH: '0.05',
            ARB: '45.00',
          }
        }
      }));
    },
  },
}));
