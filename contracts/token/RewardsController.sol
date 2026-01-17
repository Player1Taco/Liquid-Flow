// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RewardsController
 * @notice Manages LP rewards including IL compensation and loyalty bonuses
 * @dev Tracks impermanent loss and distributes LF token rewards
 */
contract RewardsController is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct LPPosition {
        uint256 initialValue;       // USD value at deposit
        uint256 currentValue;       // Current USD value
        int256 impermanentLoss;     // IL in basis points (negative = loss)
        uint256 feesEarned;         // Total fees earned
        uint256 startTime;          // Position start time
        uint256 lastUpdateTime;     // Last IL calculation
        uint256 pendingRewards;     // Unclaimed LF rewards
        uint256 claimedRewards;     // Total claimed LF rewards
    }

    struct RewardConfig {
        uint256 baseEmissionRate;   // LF per second per $1000 TVL
        uint256 ilCompensationRate; // Multiplier for IL compensation
        uint256 loyaltyMultiplier;  // Bonus per day of activity
        uint256 maxBoost;           // Maximum boost from vebLF
    }

    // ============ State Variables ============

    /// @notice LF token
    IERC20 public immutable lfToken;

    /// @notice VotingEscrow for boost calculation
    IVotingEscrow public votingEscrow;

    /// @notice LiquidFlowCore reference
    address public liquidFlowCore;

    /// @notice LP positions: lp => strategyHash => position
    mapping(address => mapping(bytes32 => LPPosition)) public positions;

    /// @notice Reward configuration
    RewardConfig public config;

    /// @notice Total rewards distributed
    uint256 public totalDistributed;

    /// @notice Rewards budget remaining
    uint256 public rewardsBudget;

    // ============ Events ============

    event PositionUpdated(
        address indexed lp,
        bytes32 indexed strategyHash,
        int256 impermanentLoss,
        uint256 feesEarned
    );

    event RewardsClaimed(
        address indexed lp,
        uint256 baseReward,
        uint256 ilCompensation,
        uint256 loyaltyBonus,
        uint256 total
    );

    event RewardConfigUpdated(
        uint256 baseEmissionRate,
        uint256 ilCompensationRate,
        uint256 loyaltyMultiplier,
        uint256 maxBoost
    );

    event BudgetAdded(uint256 amount);

    // ============ Errors ============

    error NoPosition();
    error InsufficientBudget();
    error UnauthorizedCaller();

    // ============ Modifiers ============

    modifier onlyLiquidFlowCore() {
        if (msg.sender != liquidFlowCore) revert UnauthorizedCaller();
        _;
    }

    // ============ Constructor ============

    constructor(address _lfToken, address _votingEscrow) Ownable(msg.sender) {
        lfToken = IERC20(_lfToken);
        votingEscrow = IVotingEscrow(_votingEscrow);

        // Default config
        config = RewardConfig({
            baseEmissionRate: 1e15,      // 0.001 LF per second per $1000
            ilCompensationRate: 150,     // 1.5x IL compensation
            loyaltyMultiplier: 100,      // 1% bonus per day
            maxBoost: 250                // 2.5x max boost
        });
    }

    // ============ Core Functions ============

    /**
     * @notice Register a new LP position
     * @param lp LP address
     * @param strategyHash Strategy identifier
     * @param initialValue Initial USD value
     */
    function registerPosition(
        address lp,
        bytes32 strategyHash,
        uint256 initialValue
    ) external onlyLiquidFlowCore {
        positions[lp][strategyHash] = LPPosition({
            initialValue: initialValue,
            currentValue: initialValue,
            impermanentLoss: 0,
            feesEarned: 0,
            startTime: block.timestamp,
            lastUpdateTime: block.timestamp,
            pendingRewards: 0,
            claimedRewards: 0
        });
    }

    /**
     * @notice Update position with new values (called after swaps)
     * @param lp LP address
     * @param strategyHash Strategy identifier
     * @param currentValue Current USD value
     * @param feesEarned Additional fees earned
     */
    function updatePosition(
        address lp,
        bytes32 strategyHash,
        uint256 currentValue,
        uint256 feesEarned
    ) external onlyLiquidFlowCore {
        LPPosition storage pos = positions[lp][strategyHash];
        if (pos.startTime == 0) revert NoPosition();

        // Calculate IL (in basis points)
        // IL = (currentValue - initialValue) / initialValue * 10000
        int256 valueDiff = int256(currentValue) - int256(pos.initialValue);
        int256 ilBps = (valueDiff * 10000) / int256(pos.initialValue);

        // Accrue pending rewards before updating
        _accrueRewards(lp, strategyHash);

        pos.currentValue = currentValue;
        pos.impermanentLoss = ilBps;
        pos.feesEarned += feesEarned;
        pos.lastUpdateTime = block.timestamp;

        emit PositionUpdated(lp, strategyHash, ilBps, pos.feesEarned);
    }

    /**
     * @notice Claim pending rewards
     * @param strategyHash Strategy to claim for
     */
    function claimRewards(bytes32 strategyHash) external nonReentrant returns (uint256 total) {
        LPPosition storage pos = positions[msg.sender][strategyHash];
        if (pos.startTime == 0) revert NoPosition();

        // Accrue latest rewards
        _accrueRewards(msg.sender, strategyHash);

        total = pos.pendingRewards;
        if (total == 0) return 0;
        if (total > rewardsBudget) revert InsufficientBudget();

        pos.pendingRewards = 0;
        pos.claimedRewards += total;
        rewardsBudget -= total;
        totalDistributed += total;

        lfToken.safeTransfer(msg.sender, total);

        // Calculate components for event
        (uint256 baseReward, uint256 ilComp, uint256 loyalty) = _calculateRewardComponents(msg.sender, strategyHash);

        emit RewardsClaimed(msg.sender, baseReward, ilComp, loyalty, total);
    }

    /**
     * @notice Claim rewards for all positions
     */
    function claimAllRewards(bytes32[] calldata strategyHashes) external nonReentrant returns (uint256 total) {
        for (uint256 i = 0; i < strategyHashes.length; i++) {
            LPPosition storage pos = positions[msg.sender][strategyHashes[i]];
            if (pos.startTime == 0) continue;

            _accrueRewards(msg.sender, strategyHashes[i]);
            total += pos.pendingRewards;
            pos.claimedRewards += pos.pendingRewards;
            pos.pendingRewards = 0;
        }

        if (total == 0) return 0;
        if (total > rewardsBudget) revert InsufficientBudget();

        rewardsBudget -= total;
        totalDistributed += total;

        lfToken.safeTransfer(msg.sender, total);
    }

    // ============ View Functions ============

    /**
     * @notice Get pending rewards for a position
     */
    function getPendingRewards(
        address lp,
        bytes32 strategyHash
    ) external view returns (uint256) {
        LPPosition storage pos = positions[lp][strategyHash];
        if (pos.startTime == 0) return 0;

        (uint256 baseReward, uint256 ilComp, uint256 loyalty) = _calculateRewardComponents(lp, strategyHash);
        uint256 boost = _calculateBoost(lp);
        
        return pos.pendingRewards + ((baseReward + ilComp + loyalty) * boost / 100);
    }

    /**
     * @notice Get position details
     */
    function getPosition(
        address lp,
        bytes32 strategyHash
    ) external view returns (LPPosition memory) {
        return positions[lp][strategyHash];
    }

    /**
     * @notice Get user's vebLF boost multiplier
     */
    function getBoost(address lp) external view returns (uint256) {
        return _calculateBoost(lp);
    }

    // ============ Internal Functions ============

    function _accrueRewards(address lp, bytes32 strategyHash) internal {
        LPPosition storage pos = positions[lp][strategyHash];
        
        (uint256 baseReward, uint256 ilComp, uint256 loyalty) = _calculateRewardComponents(lp, strategyHash);
        uint256 boost = _calculateBoost(lp);
        
        uint256 totalReward = ((baseReward + ilComp + loyalty) * boost) / 100;
        pos.pendingRewards += totalReward;
        pos.lastUpdateTime = block.timestamp;
    }

    function _calculateRewardComponents(
        address lp,
        bytes32 strategyHash
    ) internal view returns (uint256 baseReward, uint256 ilCompensation, uint256 loyaltyBonus) {
        LPPosition storage pos = positions[lp][strategyHash];
        
        uint256 timeElapsed = block.timestamp - pos.lastUpdateTime;
        
        // Base reward: emission rate * time * value
        baseReward = (config.baseEmissionRate * timeElapsed * pos.currentValue) / 1000e18;

        // IL compensation (only if IL is negative)
        if (pos.impermanentLoss < 0) {
            uint256 ilMagnitude = uint256(-pos.impermanentLoss);
            // IL compensation = |IL%| * value * compensation rate
            ilCompensation = (ilMagnitude * pos.currentValue * config.ilCompensationRate) / (10000 * 100);
        }

        // Loyalty bonus: days active * multiplier * base reward
        uint256 daysActive = (block.timestamp - pos.startTime) / 1 days;
        loyaltyBonus = (baseReward * daysActive * config.loyaltyMultiplier) / 10000;
    }

    function _calculateBoost(address lp) internal view returns (uint256) {
        uint256 vebLF = votingEscrow.balanceOf(lp);
        if (vebLF == 0) return 100; // 1x (no boost)

        // Boost scales with vebLF, capped at maxBoost
        // Simple linear scaling for now
        uint256 boost = 100 + (vebLF / 1e18); // +1% per vebLF
        return boost > config.maxBoost ? config.maxBoost : boost;
    }

    // ============ Admin Functions ============

    function setLiquidFlowCore(address _core) external onlyOwner {
        liquidFlowCore = _core;
    }

    function setVotingEscrow(address _ve) external onlyOwner {
        votingEscrow = IVotingEscrow(_ve);
    }

    function setRewardConfig(
        uint256 baseEmissionRate,
        uint256 ilCompensationRate,
        uint256 loyaltyMultiplier,
        uint256 maxBoost
    ) external onlyOwner {
        config = RewardConfig({
            baseEmissionRate: baseEmissionRate,
            ilCompensationRate: ilCompensationRate,
            loyaltyMultiplier: loyaltyMultiplier,
            maxBoost: maxBoost
        });

        emit RewardConfigUpdated(baseEmissionRate, ilCompensationRate, loyaltyMultiplier, maxBoost);
    }

    function addBudget(uint256 amount) external onlyOwner {
        lfToken.safeTransferFrom(msg.sender, address(this), amount);
        rewardsBudget += amount;
        emit BudgetAdded(amount);
    }

    function withdrawExcessBudget(uint256 amount) external onlyOwner {
        require(amount <= rewardsBudget, "Exceeds budget");
        rewardsBudget -= amount;
        lfToken.safeTransfer(msg.sender, amount);
    }
}

interface IVotingEscrow {
    function balanceOf(address account) external view returns (uint256);
}
