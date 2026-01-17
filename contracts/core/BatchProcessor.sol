// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title BatchProcessor
 * @notice Manages batch auctions for MEV-protected swap execution
 * @dev Collects swap intents, runs solver competition, executes winning solution
 */
contract BatchProcessor is ReentrancyGuard, Ownable, Pausable {
    
    // ============ Structs ============

    enum MEVPreference {
        NONE,           // No protection, fastest
        BASIC,          // Commit-reveal
        PROTECTED,      // Private mempool
        MAXIMUM         // MEV-Share rebates
    }

    enum BatchStatus {
        OPEN,           // Accepting intents
        SOLVING,        // Solvers competing
        EXECUTING,      // Winner executing
        SETTLED,        // Complete
        CANCELLED       // Cancelled
    }

    struct SwapIntent {
        bytes32 intentId;
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 maxFee;
        MEVPreference mevPref;
        bool allowPartialFill;
        uint256 deadline;
        bytes32 commitHash;     // For commit-reveal
        bool revealed;
    }

    struct Batch {
        uint256 id;
        uint256 openTime;
        uint256 closeTime;
        uint256 solveDeadline;
        BatchStatus status;
        bytes32[] intentIds;
        bytes32 winningSolutionHash;
        address winningSolver;
    }

    struct SolverSolution {
        bytes32 solutionHash;
        address solver;
        uint256 batchId;
        uint256 totalUserSurplus;   // Total value given to users above minAmountOut
        uint256 solverBid;          // Amount solver pays for the right to execute
        bytes executionData;
        uint256 submittedAt;
    }

    // ============ State Variables ============

    /// @notice Current batch
    Batch public currentBatch;
    
    /// @notice Historical batches
    mapping(uint256 => Batch) public batches;
    
    /// @notice Swap intents by ID
    mapping(bytes32 => SwapIntent) public intents;
    
    /// @notice Solutions by hash
    mapping(bytes32 => SolverSolution) public solutions;
    
    /// @notice Batch ID counter
    uint256 public batchCounter;

    /// @notice Batch duration (chain-specific, max 180 seconds)
    uint256 public batchDuration = 60;

    /// @notice Solver competition window
    uint256 public solverWindow = 10;

    /// @notice Solver registry reference
    address public solverRegistry;

    /// @notice LiquidFlowCore reference
    address public liquidFlowCore;

    /// @notice Minimum volume to close batch early
    uint256 public minVolumeForEarlyClose = 100000e18; // $100k

    // ============ Events ============

    event BatchOpened(uint256 indexed batchId, uint256 openTime, uint256 closeTime);
    event BatchClosed(uint256 indexed batchId, uint256 intentCount);
    event BatchSettled(uint256 indexed batchId, address indexed solver, uint256 userSurplus);
    event BatchCancelled(uint256 indexed batchId, string reason);

    event IntentSubmitted(
        bytes32 indexed intentId,
        uint256 indexed batchId,
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    );

    event IntentRevealed(bytes32 indexed intentId, address indexed user);
    event IntentCancelled(bytes32 indexed intentId, address indexed user);

    event SolutionSubmitted(
        bytes32 indexed solutionHash,
        uint256 indexed batchId,
        address indexed solver,
        uint256 userSurplus,
        uint256 solverBid
    );

    event SolverSelected(
        uint256 indexed batchId,
        address indexed solver,
        bytes32 solutionHash
    );

    // ============ Errors ============

    error BatchNotOpen();
    error BatchNotSolving();
    error IntentExpired();
    error IntentAlreadyExists();
    error InvalidCommitment();
    error SolverNotRegistered();
    error InvalidSolution();
    error NotIntentOwner();
    error DeadlinePassed();

    // ============ Modifiers ============

    modifier onlyRegisteredSolver() {
        require(
            ISolverRegistry(solverRegistry).isSolverActive(msg.sender),
            "Not registered solver"
        );
        _;
    }

    // ============ Constructor ============

    constructor(
        address _solverRegistry,
        address _liquidFlowCore
    ) Ownable(msg.sender) {
        solverRegistry = _solverRegistry;
        liquidFlowCore = _liquidFlowCore;
        _openNewBatch();
    }

    // ============ User Functions ============

    /**
     * @notice Submit a swap intent to the current batch
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @param minAmountOut Minimum acceptable output
     * @param maxFee Maximum fee willing to pay
     * @param mevPref MEV protection preference
     * @param allowPartialFill Whether to accept partial fills
     * @param deadline Intent expiration timestamp
     * @return intentId The unique intent identifier
     */
    function submitIntent(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 maxFee,
        MEVPreference mevPref,
        bool allowPartialFill,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (bytes32 intentId) {
        if (currentBatch.status != BatchStatus.OPEN) revert BatchNotOpen();
        if (deadline <= block.timestamp) revert IntentExpired();

        intentId = keccak256(abi.encode(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            block.timestamp,
            currentBatch.id
        ));

        if (intents[intentId].user != address(0)) revert IntentAlreadyExists();

        intents[intentId] = SwapIntent({
            intentId: intentId,
            user: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            maxFee: maxFee,
            mevPref: mevPref,
            allowPartialFill: allowPartialFill,
            deadline: deadline,
            commitHash: bytes32(0),
            revealed: true // No commit-reveal for basic intents
        });

        currentBatch.intentIds.push(intentId);

        emit IntentSubmitted(
            intentId,
            currentBatch.id,
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn
        );

        // Check if we should close batch early due to volume
        _checkEarlyClose();

        return intentId;
    }

    /**
     * @notice Submit a committed intent (for MEV protection)
     * @param commitHash Hash of the intent details
     * @return intentId The unique intent identifier
     */
    function submitCommittedIntent(
        bytes32 commitHash
    ) external nonReentrant whenNotPaused returns (bytes32 intentId) {
        if (currentBatch.status != BatchStatus.OPEN) revert BatchNotOpen();

        intentId = keccak256(abi.encode(msg.sender, commitHash, block.timestamp));

        intents[intentId] = SwapIntent({
            intentId: intentId,
            user: msg.sender,
            tokenIn: address(0),
            tokenOut: address(0),
            amountIn: 0,
            minAmountOut: 0,
            maxFee: 0,
            mevPref: MEVPreference.BASIC,
            allowPartialFill: false,
            deadline: 0,
            commitHash: commitHash,
            revealed: false
        });

        currentBatch.intentIds.push(intentId);

        emit IntentSubmitted(intentId, currentBatch.id, msg.sender, address(0), address(0), 0);

        return intentId;
    }

    /**
     * @notice Reveal a committed intent
     * @param intentId The intent to reveal
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @param minAmountOut Minimum output
     * @param maxFee Maximum fee
     * @param allowPartialFill Partial fill flag
     * @param deadline Expiration
     * @param salt Random salt used in commitment
     */
    function revealIntent(
        bytes32 intentId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 maxFee,
        bool allowPartialFill,
        uint256 deadline,
        bytes32 salt
    ) external nonReentrant {
        SwapIntent storage intent = intents[intentId];
        
        if (intent.user != msg.sender) revert NotIntentOwner();
        if (intent.revealed) revert InvalidCommitment();

        // Verify commitment
        bytes32 expectedHash = keccak256(abi.encode(
            tokenIn, tokenOut, amountIn, minAmountOut, maxFee, allowPartialFill, deadline, salt
        ));
        
        if (expectedHash != intent.commitHash) revert InvalidCommitment();

        // Update intent with revealed data
        intent.tokenIn = tokenIn;
        intent.tokenOut = tokenOut;
        intent.amountIn = amountIn;
        intent.minAmountOut = minAmountOut;
        intent.maxFee = maxFee;
        intent.allowPartialFill = allowPartialFill;
        intent.deadline = deadline;
        intent.revealed = true;

        emit IntentRevealed(intentId, msg.sender);
    }

    /**
     * @notice Cancel an intent before batch closes
     * @param intentId The intent to cancel
     */
    function cancelIntent(bytes32 intentId) external nonReentrant {
        SwapIntent storage intent = intents[intentId];
        
        if (intent.user != msg.sender) revert NotIntentOwner();
        if (currentBatch.status != BatchStatus.OPEN) revert BatchNotOpen();

        delete intents[intentId];

        emit IntentCancelled(intentId, msg.sender);
    }

    // ============ Solver Functions ============

    /**
     * @notice Submit a solution for the current batch
     * @param batchId The batch ID
     * @param executionData Encoded execution instructions
     * @param totalUserSurplus Total surplus given to users
     * @param solverBid Amount solver bids for execution rights
     */
    function submitSolution(
        uint256 batchId,
        bytes calldata executionData,
        uint256 totalUserSurplus,
        uint256 solverBid
    ) external onlyRegisteredSolver nonReentrant {
        if (currentBatch.id != batchId) revert InvalidSolution();
        if (currentBatch.status != BatchStatus.SOLVING) revert BatchNotSolving();
        if (block.timestamp > currentBatch.solveDeadline) revert DeadlinePassed();

        bytes32 solutionHash = keccak256(abi.encode(
            msg.sender,
            batchId,
            executionData,
            totalUserSurplus,
            solverBid
        ));

        solutions[solutionHash] = SolverSolution({
            solutionHash: solutionHash,
            solver: msg.sender,
            batchId: batchId,
            totalUserSurplus: totalUserSurplus,
            solverBid: solverBid,
            executionData: executionData,
            submittedAt: block.timestamp
        });

        emit SolutionSubmitted(solutionHash, batchId, msg.sender, totalUserSurplus, solverBid);
    }

    // ============ Batch Management ============

    /**
     * @notice Close current batch and start solver competition
     */
    function closeBatch() external {
        require(
            block.timestamp >= currentBatch.closeTime || 
            msg.sender == owner(),
            "Batch not ready to close"
        );
        require(currentBatch.status == BatchStatus.OPEN, "Batch not open");

        currentBatch.status = BatchStatus.SOLVING;
        currentBatch.solveDeadline = block.timestamp + solverWindow;

        batches[currentBatch.id] = currentBatch;

        emit BatchClosed(currentBatch.id, currentBatch.intentIds.length);
    }

    /**
     * @notice Select winning solver and execute batch
     * @param solutionHash The winning solution hash
     */
    function executeBatch(bytes32 solutionHash) external nonReentrant {
        require(currentBatch.status == BatchStatus.SOLVING, "Not in solving phase");
        require(block.timestamp > currentBatch.solveDeadline, "Solver window not closed");

        SolverSolution storage solution = solutions[solutionHash];
        require(solution.batchId == currentBatch.id, "Wrong batch");

        // Verify solver is still active
        require(
            ISolverRegistry(solverRegistry).isSolverActive(solution.solver),
            "Solver not active"
        );

        currentBatch.status = BatchStatus.EXECUTING;
        currentBatch.winningSolutionHash = solutionHash;
        currentBatch.winningSolver = solution.solver;

        emit SolverSelected(currentBatch.id, solution.solver, solutionHash);

        // Execute the solution (solver calls back with execution)
        ISolver(solution.solver).executeSolution(
            currentBatch.id,
            solution.executionData
        );

        // Mark as settled
        currentBatch.status = BatchStatus.SETTLED;
        batches[currentBatch.id] = currentBatch;

        emit BatchSettled(currentBatch.id, solution.solver, solution.totalUserSurplus);

        // Open new batch
        _openNewBatch();
    }

    /**
     * @notice Cancel batch if no valid solutions
     */
    function cancelBatch() external onlyOwner {
        require(
            currentBatch.status == BatchStatus.SOLVING &&
            block.timestamp > currentBatch.solveDeadline + 60,
            "Cannot cancel yet"
        );

        currentBatch.status = BatchStatus.CANCELLED;
        batches[currentBatch.id] = currentBatch;

        emit BatchCancelled(currentBatch.id, "No valid solutions");

        _openNewBatch();
    }

    // ============ Internal Functions ============

    function _openNewBatch() internal {
        batchCounter++;
        
        currentBatch = Batch({
            id: batchCounter,
            openTime: block.timestamp,
            closeTime: block.timestamp + batchDuration,
            solveDeadline: 0,
            status: BatchStatus.OPEN,
            intentIds: new bytes32[](0),
            winningSolutionHash: bytes32(0),
            winningSolver: address(0)
        });

        emit BatchOpened(batchCounter, block.timestamp, currentBatch.closeTime);
    }

    function _checkEarlyClose() internal {
        // Calculate total volume in batch
        uint256 totalVolume = 0;
        for (uint256 i = 0; i < currentBatch.intentIds.length; i++) {
            SwapIntent storage intent = intents[currentBatch.intentIds[i]];
            if (intent.revealed) {
                totalVolume += intent.amountIn;
            }
        }

        // Close early if volume threshold met
        if (totalVolume >= minVolumeForEarlyClose) {
            currentBatch.closeTime = block.timestamp;
        }
    }

    // ============ View Functions ============

    function getCurrentBatch() external view returns (Batch memory) {
        return currentBatch;
    }

    function getBatchIntents(uint256 batchId) external view returns (bytes32[] memory) {
        if (batchId == currentBatch.id) {
            return currentBatch.intentIds;
        }
        return batches[batchId].intentIds;
    }

    function getIntent(bytes32 intentId) external view returns (SwapIntent memory) {
        return intents[intentId];
    }

    function getSolution(bytes32 solutionHash) external view returns (SolverSolution memory) {
        return solutions[solutionHash];
    }

    // ============ Admin Functions ============

    function setBatchDuration(uint256 _duration) external onlyOwner {
        require(_duration <= 180, "Max 3 minutes");
        batchDuration = _duration;
    }

    function setSolverWindow(uint256 _window) external onlyOwner {
        require(_window >= 5 && _window <= 30, "Invalid window");
        solverWindow = _window;
    }

    function setMinVolumeForEarlyClose(uint256 _volume) external onlyOwner {
        minVolumeForEarlyClose = _volume;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

interface ISolverRegistry {
    function isSolverActive(address solver) external view returns (bool);
}

interface ISolver {
    function executeSolution(uint256 batchId, bytes calldata executionData) external;
}
