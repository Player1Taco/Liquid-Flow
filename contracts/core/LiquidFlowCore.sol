// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title LiquidFlowCore
 * @notice Core protocol contract for Liquid Flow - the shared liquidity layer
 * @dev Manages virtual balances, strategy registration, and liquidity operations
 * 
 * Key Innovation: Same capital can be allocated to unlimited strategies simultaneously.
 * Actual token transfers only occur during swap execution (push/pull).
 */
contract LiquidFlowCore is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct VirtualBalance {
        uint256 amount;
        uint256 lastUpdated;
        bool isActive;
    }

    struct Strategy {
        address strategyContract;
        bytes32 strategyHash;
        address lp;
        bool isActive;
        uint256 createdAt;
        uint256 totalVolume;
        uint256 totalFees;
    }

    struct WithdrawalRequest {
        address lp;
        address strategy;
        bytes32 strategyHash;
        address[] tokens;
        uint256 requestedAt;
        bool executed;
    }

    // ============ State Variables ============

    /// @notice Virtual balances: lp => strategy => strategyHash => token => balance
    mapping(address => mapping(address => mapping(bytes32 => mapping(address => VirtualBalance)))) 
        public virtualBalances;

    /// @notice Registered strategies
    mapping(bytes32 => Strategy) public strategies;

    /// @notice Approved strategy contracts
    mapping(address => bool) public approvedStrategies;

    /// @notice Withdrawal requests queue
    mapping(bytes32 => WithdrawalRequest) public withdrawalRequests;
    uint256 public withdrawalRequestCount;

    /// @notice Protocol fee (basis points, e.g., 1000 = 10%)
    uint256 public protocolFeeBps = 1000;

    /// @notice Fee collector address
    address public feeCollector;

    /// @notice Batch processor contract
    address public batchProcessor;

    /// @notice Minimum withdrawal delay (for queued withdrawals)
    uint256 public constant MIN_WITHDRAWAL_DELAY = 180; // 3 minutes max batch time

    // ============ Events ============

    event StrategyShipped(
        address indexed lp,
        address indexed strategy,
        bytes32 indexed strategyHash,
        address[] tokens,
        uint256[] amounts
    );

    event StrategyDocked(
        address indexed lp,
        address indexed strategy,
        bytes32 indexed strategyHash
    );

    event LiquidityPulled(
        address indexed lp,
        bytes32 indexed strategyHash,
        address token,
        uint256 amount,
        address recipient
    );

    event LiquidityPushed(
        address indexed lp,
        bytes32 indexed strategyHash,
        address token,
        uint256 amount,
        address from
    );

    event WithdrawalRequested(
        bytes32 indexed requestId,
        address indexed lp,
        address strategy,
        bytes32 strategyHash
    );

    event WithdrawalExecuted(
        bytes32 indexed requestId,
        address indexed lp
    );

    event StrategyApproved(address indexed strategy, bool approved);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeCollectorUpdated(address oldCollector, address newCollector);
    event BatchProcessorUpdated(address oldProcessor, address newProcessor);

    // ============ Errors ============

    error StrategyNotApproved();
    error StrategyNotActive();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidStrategy();
    error UnauthorizedCaller();
    error WithdrawalNotReady();
    error WithdrawalAlreadyExecuted();
    error ArrayLengthMismatch();
    error ZeroAddress();

    // ============ Modifiers ============

    modifier onlyApprovedStrategy() {
        if (!approvedStrategies[msg.sender]) revert StrategyNotApproved();
        _;
    }

    modifier onlyBatchProcessor() {
        if (msg.sender != batchProcessor) revert UnauthorizedCaller();
        _;
    }

    // ============ Constructor ============

    constructor(address _feeCollector) Ownable(msg.sender) {
        if (_feeCollector == address(0)) revert ZeroAddress();
        feeCollector = _feeCollector;
    }

    // ============ LP Functions ============

    /**
     * @notice Ship (create/allocate) a strategy with virtual balances
     * @param strategy The strategy contract address
     * @param strategyData Encoded strategy parameters
     * @param tokens Array of token addresses
     * @param amounts Array of amounts to allocate
     */
    function ship(
        address strategy,
        bytes calldata strategyData,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external nonReentrant whenNotPaused {
        if (!approvedStrategies[strategy]) revert StrategyNotApproved();
        if (tokens.length != amounts.length) revert ArrayLengthMismatch();
        if (tokens.length == 0) revert InvalidAmount();

        bytes32 strategyHash = keccak256(abi.encode(msg.sender, strategy, strategyData));

        // Verify LP has sufficient actual token balances
        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] == 0) revert InvalidAmount();
            uint256 balance = IERC20(tokens[i]).balanceOf(msg.sender);
            if (balance < amounts[i]) revert InsufficientBalance();
            
            // Check allowance
            uint256 allowance = IERC20(tokens[i]).allowance(msg.sender, address(this));
            if (allowance < amounts[i]) revert InsufficientBalance();
        }

        // Set virtual balances (no actual token transfer)
        for (uint256 i = 0; i < tokens.length; i++) {
            virtualBalances[msg.sender][strategy][strategyHash][tokens[i]] = VirtualBalance({
                amount: amounts[i],
                lastUpdated: block.timestamp,
                isActive: true
            });
        }

        // Register strategy
        strategies[strategyHash] = Strategy({
            strategyContract: strategy,
            strategyHash: strategyHash,
            lp: msg.sender,
            isActive: true,
            createdAt: block.timestamp,
            totalVolume: 0,
            totalFees: 0
        });

        emit StrategyShipped(msg.sender, strategy, strategyHash, tokens, amounts);
    }

    /**
     * @notice Request to dock (remove) a strategy
     * @dev Withdrawal is queued to allow current batch to settle
     * @param strategy The strategy contract address
     * @param strategyHash The strategy hash
     * @param tokens Array of token addresses to withdraw
     */
    function requestDock(
        address strategy,
        bytes32 strategyHash,
        address[] calldata tokens
    ) external nonReentrant {
        Strategy storage strat = strategies[strategyHash];
        if (strat.lp != msg.sender) revert UnauthorizedCaller();
        if (!strat.isActive) revert StrategyNotActive();

        bytes32 requestId = keccak256(abi.encode(
            msg.sender,
            strategy,
            strategyHash,
            withdrawalRequestCount++
        ));

        withdrawalRequests[requestId] = WithdrawalRequest({
            lp: msg.sender,
            strategy: strategy,
            strategyHash: strategyHash,
            tokens: tokens,
            requestedAt: block.timestamp,
            executed: false
        });

        emit WithdrawalRequested(requestId, msg.sender, strategy, strategyHash);
    }

    /**
     * @notice Execute a queued withdrawal after delay
     * @param requestId The withdrawal request ID
     */
    function executeDock(bytes32 requestId) external nonReentrant {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        
        if (request.executed) revert WithdrawalAlreadyExecuted();
        if (request.lp != msg.sender) revert UnauthorizedCaller();
        if (block.timestamp < request.requestedAt + MIN_WITHDRAWAL_DELAY) {
            revert WithdrawalNotReady();
        }

        request.executed = true;

        // Clear virtual balances
        for (uint256 i = 0; i < request.tokens.length; i++) {
            delete virtualBalances[request.lp][request.strategy][request.strategyHash][request.tokens[i]];
        }

        // Deactivate strategy
        strategies[request.strategyHash].isActive = false;

        emit StrategyDocked(request.lp, request.strategy, request.strategyHash);
        emit WithdrawalExecuted(requestId, request.lp);
    }

    /**
     * @notice Instant dock for emergency situations (owner only)
     * @param lp The LP address
     * @param strategy The strategy contract
     * @param strategyHash The strategy hash
     * @param tokens Tokens to clear
     */
    function emergencyDock(
        address lp,
        address strategy,
        bytes32 strategyHash,
        address[] calldata tokens
    ) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            delete virtualBalances[lp][strategy][strategyHash][tokens[i]];
        }
        strategies[strategyHash].isActive = false;
        emit StrategyDocked(lp, strategy, strategyHash);
    }

    // ============ Strategy Functions ============

    /**
     * @notice Pull tokens from LP to recipient (called by strategy during swap)
     * @param lp The LP address
     * @param strategyHash The strategy hash
     * @param token The token to pull
     * @param amount The amount to pull
     * @param recipient The recipient address
     */
    function pull(
        address lp,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address recipient
    ) external onlyApprovedStrategy nonReentrant whenNotPaused {
        VirtualBalance storage vBalance = virtualBalances[lp][msg.sender][strategyHash][token];
        
        if (!vBalance.isActive) revert StrategyNotActive();
        if (vBalance.amount < amount) revert InsufficientBalance();

        // Update virtual balance
        vBalance.amount -= amount;
        vBalance.lastUpdated = block.timestamp;

        // Actual token transfer from LP to recipient
        IERC20(token).safeTransferFrom(lp, recipient, amount);

        // Update strategy stats
        strategies[strategyHash].totalVolume += amount;

        emit LiquidityPulled(lp, strategyHash, token, amount, recipient);
    }

    /**
     * @notice Push tokens from sender to LP (called by strategy during swap)
     * @param lp The LP address
     * @param strategyHash The strategy hash
     * @param token The token to push
     * @param amount The amount to push
     * @param from The sender address
     */
    function push(
        address lp,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address from
    ) external onlyApprovedStrategy nonReentrant whenNotPaused {
        VirtualBalance storage vBalance = virtualBalances[lp][msg.sender][strategyHash][token];
        
        if (!vBalance.isActive) revert StrategyNotActive();

        // Calculate protocol fee
        uint256 fee = (amount * protocolFeeBps) / 10000;
        uint256 amountAfterFee = amount - fee;

        // Update virtual balance
        vBalance.amount += amountAfterFee;
        vBalance.lastUpdated = block.timestamp;

        // Actual token transfers
        IERC20(token).safeTransferFrom(from, lp, amountAfterFee);
        if (fee > 0) {
            IERC20(token).safeTransferFrom(from, feeCollector, fee);
        }

        // Update strategy stats
        strategies[strategyHash].totalVolume += amount;
        strategies[strategyHash].totalFees += fee;

        emit LiquidityPushed(lp, strategyHash, token, amount, from);
    }

    /**
     * @notice Push with callback for complex swap flows
     * @param lp The LP address
     * @param strategyHash The strategy hash
     * @param token The token to push
     * @param amount The amount to push
     * @param from The sender address (must implement callback)
     * @param data Callback data
     */
    function pushWithCallback(
        address lp,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address from,
        bytes calldata data
    ) external onlyApprovedStrategy nonReentrant whenNotPaused {
        VirtualBalance storage vBalance = virtualBalances[lp][msg.sender][strategyHash][token];
        
        if (!vBalance.isActive) revert StrategyNotActive();

        // Call the callback on the sender
        ILiquidFlowCallback(from).liquidFlowPushCallback(
            lp,
            strategyHash,
            token,
            amount,
            data
        );

        // Calculate protocol fee
        uint256 fee = (amount * protocolFeeBps) / 10000;
        uint256 amountAfterFee = amount - fee;

        // Update virtual balance
        vBalance.amount += amountAfterFee;
        vBalance.lastUpdated = block.timestamp;

        // Actual token transfers
        IERC20(token).safeTransferFrom(from, lp, amountAfterFee);
        if (fee > 0) {
            IERC20(token).safeTransferFrom(from, feeCollector, fee);
        }

        strategies[strategyHash].totalVolume += amount;
        strategies[strategyHash].totalFees += fee;

        emit LiquidityPushed(lp, strategyHash, token, amount, from);
    }

    // ============ View Functions ============

    /**
     * @notice Get virtual balance for a specific allocation
     */
    function balanceOf(
        address lp,
        address strategy,
        bytes32 strategyHash,
        address token
    ) external view returns (uint256) {
        return virtualBalances[lp][strategy][strategyHash][token].amount;
    }

    /**
     * @notice Check if a strategy allocation is active
     */
    function isStrategyActive(bytes32 strategyHash) external view returns (bool) {
        return strategies[strategyHash].isActive;
    }

    /**
     * @notice Get strategy details
     */
    function getStrategy(bytes32 strategyHash) external view returns (Strategy memory) {
        return strategies[strategyHash];
    }

    /**
     * @notice Get withdrawal request details
     */
    function getWithdrawalRequest(bytes32 requestId) external view returns (WithdrawalRequest memory) {
        return withdrawalRequests[requestId];
    }

    // ============ Admin Functions ============

    /**
     * @notice Approve or revoke a strategy contract
     */
    function setStrategyApproval(address strategy, bool approved) external onlyOwner {
        approvedStrategies[strategy] = approved;
        emit StrategyApproved(strategy, approved);
    }

    /**
     * @notice Update protocol fee
     */
    function setProtocolFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 2000, "Fee too high"); // Max 20%
        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(oldFee, newFeeBps);
    }

    /**
     * @notice Update fee collector
     */
    function setFeeCollector(address newCollector) external onlyOwner {
        if (newCollector == address(0)) revert ZeroAddress();
        address oldCollector = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(oldCollector, newCollector);
    }

    /**
     * @notice Update batch processor
     */
    function setBatchProcessor(address newProcessor) external onlyOwner {
        address oldProcessor = batchProcessor;
        batchProcessor = newProcessor;
        emit BatchProcessorUpdated(oldProcessor, newProcessor);
    }

    /**
     * @notice Pause the protocol
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the protocol
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}

/**
 * @title ILiquidFlowCallback
 * @notice Interface for push callback
 */
interface ILiquidFlowCallback {
    function liquidFlowPushCallback(
        address lp,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}
