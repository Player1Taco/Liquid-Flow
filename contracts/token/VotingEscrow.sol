// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotingEscrow (vebLF)
 * @notice Vote-escrowed bLF for governance and fee sharing
 * @dev Aerodrome-style ve-token with lock duration multipliers
 * 
 * Lock Duration → vebLF Multiplier:
 * - 1 year  = 0.25x bLF
 * - 2 years = 0.50x bLF
 * - 3 years = 0.75x bLF
 * - 4 years = 1.00x bLF
 * 
 * vebLF balance decays linearly over the lock period
 */
contract VotingEscrow is ReentrancyGuard, Ownable {
    
    // ============ Structs ============

    struct Lock {
        uint256 amount;         // bLF locked
        uint256 end;            // Lock end timestamp
        uint256 maxVebLF;       // Maximum vebLF at lock creation
        uint256 start;          // Lock start timestamp
    }

    struct Point {
        int128 bias;            // Current voting power
        int128 slope;           // Decay rate
        uint256 ts;             // Timestamp
        uint256 blk;            // Block number
    }

    // ============ Constants ============

    uint256 public constant WEEK = 7 days;
    uint256 public constant MAXTIME = 4 * 365 days; // 4 years
    uint256 public constant MINTIME = 365 days;     // 1 year minimum
    uint256 public constant MULTIPLIER = 1e18;

    // ============ State Variables ============

    /// @notice bLF token
    IBurnedLF public immutable blfToken;

    /// @notice User locks
    mapping(address => Lock) public locks;

    /// @notice Total locked bLF
    uint256 public totalLocked;

    /// @notice Total vebLF supply (sum of all voting power)
    uint256 public totalSupply;

    /// @notice Global point history
    Point[] public pointHistory;

    /// @notice User point history
    mapping(address => Point[]) public userPointHistory;

    /// @notice Slope changes at future timestamps
    mapping(uint256 => int128) public slopeChanges;

    /// @notice Fee distributor contract
    address public feeDistributor;

    /// @notice Rewards controller contract
    address public rewardsController;

    // ============ Events ============

    event Deposit(
        address indexed user,
        uint256 amount,
        uint256 lockEnd,
        uint256 vebLFAmount,
        uint256 timestamp
    );

    event Withdraw(address indexed user, uint256 amount, uint256 timestamp);
    event IncreaseLockAmount(address indexed user, uint256 amount, uint256 newTotal);
    event IncreaseLockTime(address indexed user, uint256 newEnd);

    // ============ Errors ============

    error LockExists();
    error NoLockFound();
    error LockNotExpired();
    error LockExpired();
    error InvalidLockTime();
    error ZeroAmount();
    error LockTooShort();
    error LockTooLong();

    // ============ Constructor ============

    constructor(address _blfToken) Ownable(msg.sender) {
        blfToken = IBurnedLF(_blfToken);
        pointHistory.push(Point({
            bias: 0,
            slope: 0,
            ts: block.timestamp,
            blk: block.number
        }));
    }

    // ============ Core Functions ============

    /**
     * @notice Create a new lock
     * @param amount Amount of bLF to lock
     * @param duration Lock duration in seconds
     */
    function createLock(uint256 amount, uint256 duration) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (locks[msg.sender].amount != 0) revert LockExists();
        if (duration < MINTIME) revert LockTooShort();
        if (duration > MAXTIME) revert LockTooLong();

        uint256 unlockTime = _roundToWeek(block.timestamp + duration);
        
        // Calculate vebLF amount based on duration
        uint256 vebLFAmount = _calculateVebLF(amount, duration);

        // Burn bLF from user
        blfToken.burnForLock(msg.sender, amount);

        locks[msg.sender] = Lock({
            amount: amount,
            end: unlockTime,
            maxVebLF: vebLFAmount,
            start: block.timestamp
        });

        totalLocked += amount;
        totalSupply += vebLFAmount;

        _checkpoint(msg.sender, Lock({amount: 0, end: 0, maxVebLF: 0, start: 0}), locks[msg.sender]);

        emit Deposit(msg.sender, amount, unlockTime, vebLFAmount, block.timestamp);
    }

    /**
     * @notice Increase lock amount
     * @param amount Additional bLF to lock
     */
    function increaseAmount(uint256 amount) external nonReentrant {
        Lock storage lock = locks[msg.sender];
        if (lock.amount == 0) revert NoLockFound();
        if (lock.end <= block.timestamp) revert LockExpired();
        if (amount == 0) revert ZeroAmount();

        Lock memory oldLock = lock;

        // Burn additional bLF
        blfToken.burnForLock(msg.sender, amount);

        // Recalculate vebLF for remaining duration
        uint256 remainingDuration = lock.end - block.timestamp;
        uint256 additionalVebLF = _calculateVebLF(amount, remainingDuration);

        lock.amount += amount;
        lock.maxVebLF += additionalVebLF;

        totalLocked += amount;
        totalSupply += additionalVebLF;

        _checkpoint(msg.sender, oldLock, lock);

        emit IncreaseLockAmount(msg.sender, amount, lock.amount);
    }

    /**
     * @notice Increase lock duration
     * @param newDuration New total duration from now
     */
    function increaseUnlockTime(uint256 newDuration) external nonReentrant {
        Lock storage lock = locks[msg.sender];
        if (lock.amount == 0) revert NoLockFound();
        if (lock.end <= block.timestamp) revert LockExpired();

        uint256 newUnlockTime = _roundToWeek(block.timestamp + newDuration);
        if (newUnlockTime <= lock.end) revert InvalidLockTime();
        if (newDuration > MAXTIME) revert LockTooLong();

        Lock memory oldLock = lock;

        // Recalculate vebLF for new duration
        uint256 oldVebLF = lock.maxVebLF;
        uint256 newVebLF = _calculateVebLF(lock.amount, newDuration);

        lock.end = newUnlockTime;
        lock.maxVebLF = newVebLF;
        lock.start = block.timestamp;

        totalSupply = totalSupply - oldVebLF + newVebLF;

        _checkpoint(msg.sender, oldLock, lock);

        emit IncreaseLockTime(msg.sender, newUnlockTime);
    }

    /**
     * @notice Withdraw after lock expires
     */
    function withdraw() external nonReentrant {
        Lock storage lock = locks[msg.sender];
        if (lock.amount == 0) revert NoLockFound();
        if (lock.end > block.timestamp) revert LockNotExpired();

        uint256 amount = lock.amount;
        Lock memory oldLock = lock;

        totalLocked -= amount;
        // vebLF already decayed to 0

        delete locks[msg.sender];

        _checkpoint(msg.sender, oldLock, Lock({amount: 0, end: 0, maxVebLF: 0, start: 0}));

        // Note: bLF was burned, user gets nothing back
        // This is the "burn" part of the tokenomics

        emit Withdraw(msg.sender, amount, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @notice Get current voting power (decaying balance)
     * @param account User address
     * @return Current vebLF balance
     */
    function balanceOf(address account) external view returns (uint256) {
        Lock memory lock = locks[account];
        if (lock.amount == 0 || block.timestamp >= lock.end) {
            return 0;
        }

        uint256 timeRemaining = lock.end - block.timestamp;
        uint256 totalDuration = lock.end - lock.start;
        
        // Linear decay
        return (lock.maxVebLF * timeRemaining) / totalDuration;
    }

    /**
     * @notice Get voting power at a specific timestamp
     */
    function balanceOfAt(address account, uint256 timestamp) external view returns (uint256) {
        Lock memory lock = locks[account];
        if (lock.amount == 0 || timestamp >= lock.end || timestamp < lock.start) {
            return 0;
        }

        uint256 timeRemaining = lock.end - timestamp;
        uint256 totalDuration = lock.end - lock.start;
        
        return (lock.maxVebLF * timeRemaining) / totalDuration;
    }

    /**
     * @notice Get lock details
     */
    function getLock(address account) external view returns (Lock memory) {
        return locks[account];
    }

    /**
     * @notice Calculate vebLF for given amount and duration
     */
    function calculateVebLF(uint256 amount, uint256 duration) external pure returns (uint256) {
        return _calculateVebLF(amount, duration);
    }

    // ============ Internal Functions ============

    function _calculateVebLF(uint256 amount, uint256 duration) internal pure returns (uint256) {
        // Duration multiplier: 1 year = 0.25x, 4 years = 1.0x
        // Linear interpolation between 0.25 and 1.0
        
        if (duration >= MAXTIME) {
            return amount; // 1.0x
        }
        
        // multiplier = 0.25 + 0.75 * (duration / MAXTIME)
        // = (0.25 * MAXTIME + 0.75 * duration) / MAXTIME
        // = (MAXTIME/4 + 3*duration/4) / MAXTIME
        // = (MAXTIME + 3*duration) / (4 * MAXTIME)
        
        uint256 multiplier = (MAXTIME + 3 * duration) * MULTIPLIER / (4 * MAXTIME);
        return (amount * multiplier) / MULTIPLIER;
    }

    function _roundToWeek(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / WEEK) * WEEK;
    }

    function _checkpoint(
        address account,
        Lock memory oldLock,
        Lock memory newLock
    ) internal {
        // Simplified checkpoint - full implementation would track global slope changes
        Point memory userPoint = Point({
            bias: int128(int256(newLock.maxVebLF)),
            slope: newLock.end > block.timestamp 
                ? int128(int256(newLock.maxVebLF / (newLock.end - block.timestamp)))
                : int128(0),
            ts: block.timestamp,
            blk: block.number
        });

        userPointHistory[account].push(userPoint);
    }

    // ============ Admin Functions ============

    function setFeeDistributor(address _feeDistributor) external onlyOwner {
        feeDistributor = _feeDistributor;
    }

    function setRewardsController(address _rewardsController) external onlyOwner {
        rewardsController = _rewardsController;
    }
}

interface IBurnedLF {
    function burnForLock(address from, uint256 amount) external;
}
