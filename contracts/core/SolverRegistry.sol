// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SolverRegistry
 * @notice Manages solver registration, staking, reputation, and slashing
 * @dev Solvers must stake LF tokens and maintain good reputation to participate
 */
contract SolverRegistry is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct Solver {
        address operator;
        uint256 stakedAmount;
        uint256 reputationScore;
        uint256 totalBatchesSolved;
        uint256 totalUserSurplus;
        uint256 totalSlashed;
        uint256 registeredAt;
        uint256 lastActiveAt;
        bool isActive;
    }

    struct SlashEvent {
        address solver;
        uint256 amount;
        string reason;
        uint256 timestamp;
    }

    // ============ State Variables ============

    /// @notice LF token for staking
    IERC20 public immutable lfToken;

    /// @notice Minimum stake required
    uint256 public minStake = 10_000e18; // 10,000 LF

    /// @notice Slash percentage (basis points)
    uint256 public slashPercentage = 1000; // 10%

    /// @notice Registered solvers
    mapping(address => Solver) public solvers;

    /// @notice Slash history
    SlashEvent[] public slashHistory;

    /// @notice Batch processor (authorized to update reputation)
    address public batchProcessor;

    /// @notice Reputation decay per day of inactivity
    uint256 public reputationDecayPerDay = 1;

    /// @notice Initial reputation score
    uint256 public initialReputation = 100;

    /// @notice Minimum reputation to remain active
    uint256 public minReputation = 10;

    // ============ Events ============

    event SolverRegistered(address indexed solver, uint256 stakedAmount);
    event SolverUnregistered(address indexed solver, uint256 returnedStake);
    event StakeIncreased(address indexed solver, uint256 amount, uint256 newTotal);
    event StakeDecreased(address indexed solver, uint256 amount, uint256 newTotal);
    event SolverSlashed(address indexed solver, uint256 amount, string reason);
    event ReputationUpdated(address indexed solver, uint256 oldScore, uint256 newScore);
    event SolverDeactivated(address indexed solver, string reason);
    event SolverReactivated(address indexed solver);

    // ============ Errors ============

    error InsufficientStake();
    error SolverNotRegistered();
    error SolverAlreadyRegistered();
    error SolverNotActive();
    error UnauthorizedCaller();
    error InvalidAmount();
    error ReputationTooLow();

    // ============ Modifiers ============

    modifier onlyBatchProcessor() {
        if (msg.sender != batchProcessor) revert UnauthorizedCaller();
        _;
    }

    modifier onlyActiveSolver(address solver) {
        if (!solvers[solver].isActive) revert SolverNotActive();
        _;
    }

    // ============ Constructor ============

    constructor(address _lfToken) Ownable(msg.sender) {
        lfToken = IERC20(_lfToken);
    }

    // ============ Solver Functions ============

    /**
     * @notice Register as a solver by staking LF tokens
     * @param stakeAmount Amount of LF to stake
     */
    function registerSolver(uint256 stakeAmount) external nonReentrant {
        if (solvers[msg.sender].operator != address(0)) revert SolverAlreadyRegistered();
        if (stakeAmount < minStake) revert InsufficientStake();

        lfToken.safeTransferFrom(msg.sender, address(this), stakeAmount);

        solvers[msg.sender] = Solver({
            operator: msg.sender,
            stakedAmount: stakeAmount,
            reputationScore: initialReputation,
            totalBatchesSolved: 0,
            totalUserSurplus: 0,
            totalSlashed: 0,
            registeredAt: block.timestamp,
            lastActiveAt: block.timestamp,
            isActive: true
        });

        emit SolverRegistered(msg.sender, stakeAmount);
    }

    /**
     * @notice Unregister and withdraw stake
     * @dev Can only unregister if not currently solving a batch
     */
    function unregisterSolver() external nonReentrant {
        Solver storage solver = solvers[msg.sender];
        if (solver.operator == address(0)) revert SolverNotRegistered();

        uint256 returnAmount = solver.stakedAmount;
        
        delete solvers[msg.sender];

        if (returnAmount > 0) {
            lfToken.safeTransfer(msg.sender, returnAmount);
        }

        emit SolverUnregistered(msg.sender, returnAmount);
    }

    /**
     * @notice Increase stake
     * @param amount Additional amount to stake
     */
    function increaseStake(uint256 amount) external nonReentrant {
        Solver storage solver = solvers[msg.sender];
        if (solver.operator == address(0)) revert SolverNotRegistered();
        if (amount == 0) revert InvalidAmount();

        lfToken.safeTransferFrom(msg.sender, address(this), amount);
        solver.stakedAmount += amount;

        emit StakeIncreased(msg.sender, amount, solver.stakedAmount);
    }

    /**
     * @notice Decrease stake (must remain above minimum)
     * @param amount Amount to withdraw
     */
    function decreaseStake(uint256 amount) external nonReentrant {
        Solver storage solver = solvers[msg.sender];
        if (solver.operator == address(0)) revert SolverNotRegistered();
        if (amount == 0) revert InvalidAmount();
        if (solver.stakedAmount - amount < minStake) revert InsufficientStake();

        solver.stakedAmount -= amount;
        lfToken.safeTransfer(msg.sender, amount);

        emit StakeDecreased(msg.sender, amount, solver.stakedAmount);
    }

    // ============ Batch Processor Functions ============

    /**
     * @notice Update solver reputation after batch execution
     * @param solver Solver address
     * @param delta Reputation change (positive or negative)
     * @param userSurplus Surplus delivered to users
     */
    function updateReputation(
        address solver,
        int256 delta,
        uint256 userSurplus
    ) external onlyBatchProcessor {
        Solver storage s = solvers[solver];
        if (s.operator == address(0)) revert SolverNotRegistered();

        uint256 oldScore = s.reputationScore;
        
        if (delta >= 0) {
            s.reputationScore += uint256(delta);
        } else {
            uint256 decrease = uint256(-delta);
            if (decrease >= s.reputationScore) {
                s.reputationScore = 0;
            } else {
                s.reputationScore -= decrease;
            }
        }

        s.totalBatchesSolved++;
        s.totalUserSurplus += userSurplus;
        s.lastActiveAt = block.timestamp;

        // Deactivate if reputation too low
        if (s.reputationScore < minReputation && s.isActive) {
            s.isActive = false;
            emit SolverDeactivated(solver, "Reputation too low");
        }

        emit ReputationUpdated(solver, oldScore, s.reputationScore);
    }

    /**
     * @notice Slash a solver for bad behavior
     * @param solver Solver address
     * @param reason Reason for slashing
     */
    function slash(
        address solver,
        string calldata reason
    ) external onlyBatchProcessor {
        Solver storage s = solvers[solver];
        if (s.operator == address(0)) revert SolverNotRegistered();

        uint256 slashAmount = (s.stakedAmount * slashPercentage) / 10000;
        
        s.stakedAmount -= slashAmount;
        s.totalSlashed += slashAmount;
        s.reputationScore = s.reputationScore > 20 ? s.reputationScore - 20 : 0;

        // Transfer slashed amount to treasury/fee collector
        // For now, just burn it by keeping in contract

        slashHistory.push(SlashEvent({
            solver: solver,
            amount: slashAmount,
            reason: reason,
            timestamp: block.timestamp
        }));

        // Deactivate if stake falls below minimum
        if (s.stakedAmount < minStake) {
            s.isActive = false;
            emit SolverDeactivated(solver, "Stake below minimum after slash");
        }

        emit SolverSlashed(solver, slashAmount, reason);
    }

    // ============ View Functions ============

    /**
     * @notice Check if solver is active and eligible
     */
    function isSolverActive(address solver) external view returns (bool) {
        Solver storage s = solvers[solver];
        return s.isActive && 
               s.stakedAmount >= minStake && 
               s.reputationScore >= minReputation;
    }

    /**
     * @notice Get solver details
     */
    function getSolver(address solver) external view returns (Solver memory) {
        return solvers[solver];
    }

    /**
     * @notice Get solver reputation with decay applied
     */
    function getEffectiveReputation(address solver) external view returns (uint256) {
        Solver storage s = solvers[solver];
        if (s.operator == address(0)) return 0;

        uint256 daysSinceActive = (block.timestamp - s.lastActiveAt) / 1 days;
        uint256 decay = daysSinceActive * reputationDecayPerDay;
        
        return decay >= s.reputationScore ? 0 : s.reputationScore - decay;
    }

    /**
     * @notice Get slash history length
     */
    function getSlashHistoryLength() external view returns (uint256) {
        return slashHistory.length;
    }

    // ============ Admin Functions ============

    function setBatchProcessor(address _batchProcessor) external onlyOwner {
        batchProcessor = _batchProcessor;
    }

    function setMinStake(uint256 _minStake) external onlyOwner {
        minStake = _minStake;
    }

    function setSlashPercentage(uint256 _percentage) external onlyOwner {
        require(_percentage <= 5000, "Max 50%");
        slashPercentage = _percentage;
    }

    function setMinReputation(uint256 _minReputation) external onlyOwner {
        minReputation = _minReputation;
    }

    function setReputationDecay(uint256 _decayPerDay) external onlyOwner {
        reputationDecayPerDay = _decayPerDay;
    }

    /**
     * @notice Reactivate a solver (admin override)
     */
    function reactivateSolver(address solver) external onlyOwner {
        Solver storage s = solvers[solver];
        if (s.operator == address(0)) revert SolverNotRegistered();
        if (s.stakedAmount < minStake) revert InsufficientStake();
        
        s.isActive = true;
        s.reputationScore = initialReputation;
        
        emit SolverReactivated(solver);
    }
}
