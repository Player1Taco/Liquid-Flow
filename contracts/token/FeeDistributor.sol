// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FeeDistributor
 * @notice Distributes protocol fees to vebLF holders
 * @dev Weekly epochs, proportional to vebLF balance at epoch start
 */
contract FeeDistributor is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct Epoch {
        uint256 startTime;
        uint256 endTime;
        mapping(address => uint256) tokenAmounts;  // token => amount
        mapping(address => mapping(address => bool)) claimed; // user => token => claimed
        uint256 totalVebLF;  // Total vebLF at epoch start
    }

    // ============ Constants ============

    uint256 public constant WEEK = 7 days;

    // ============ State Variables ============

    /// @notice VotingEscrow contract
    IVotingEscrow public immutable votingEscrow;

    /// @notice Current epoch number
    uint256 public currentEpoch;

    /// @notice Epoch data
    mapping(uint256 => Epoch) public epochs;

    /// @notice Supported fee tokens
    address[] public feeTokens;
    mapping(address => bool) public isFeeToken;

    /// @notice User's last claimed epoch per token
    mapping(address => mapping(address => uint256)) public userLastClaimedEpoch;

    /// @notice Epoch start time
    uint256 public epochStartTime;

    // ============ Events ============

    event EpochStarted(uint256 indexed epoch, uint256 startTime, uint256 totalVebLF);
    event FeesDeposited(uint256 indexed epoch, address indexed token, uint256 amount);
    event FeesClaimed(address indexed user, uint256 indexed epoch, address indexed token, uint256 amount);
    event FeeTokenAdded(address indexed token);
    event FeeTokenRemoved(address indexed token);

    // ============ Errors ============

    error EpochNotEnded();
    error AlreadyClaimed();
    error NoClaimableAmount();
    error InvalidToken();

    // ============ Constructor ============

    constructor(address _votingEscrow) Ownable(msg.sender) {
        votingEscrow = IVotingEscrow(_votingEscrow);
        epochStartTime = _roundToWeek(block.timestamp);
        _startNewEpoch();
    }

    // ============ Core Functions ============

    /**
     * @notice Checkpoint to start new epoch if needed
     */
    function checkpoint() external {
        if (block.timestamp >= epochs[currentEpoch].endTime) {
            _startNewEpoch();
        }
    }

    /**
     * @notice Deposit fees for current epoch
     * @param token Fee token address
     * @param amount Amount to deposit
     */
    function depositFees(address token, uint256 amount) external nonReentrant {
        if (!isFeeToken[token]) revert InvalidToken();
        
        // Ensure we're in current epoch
        if (block.timestamp >= epochs[currentEpoch].endTime) {
            _startNewEpoch();
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        epochs[currentEpoch].tokenAmounts[token] += amount;

        emit FeesDeposited(currentEpoch, token, amount);
    }

    /**
     * @notice Claim fees for a specific epoch
     * @param epoch Epoch number to claim
     * @param token Token to claim
     */
    function claim(uint256 epoch, address token) external nonReentrant returns (uint256 amount) {
        if (epoch >= currentEpoch) revert EpochNotEnded();
        if (epochs[epoch].claimed[msg.sender][token]) revert AlreadyClaimed();

        amount = _calculateClaimable(msg.sender, epoch, token);
        if (amount == 0) revert NoClaimableAmount();

        epochs[epoch].claimed[msg.sender][token] = true;
        userLastClaimedEpoch[msg.sender][token] = epoch;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit FeesClaimed(msg.sender, epoch, token, amount);
    }

    /**
     * @notice Claim all pending fees for all tokens
     */
    function claimAll() external nonReentrant returns (uint256[] memory amounts) {
        amounts = new uint256[](feeTokens.length);

        for (uint256 e = userLastClaimedEpoch[msg.sender][feeTokens[0]] + 1; e < currentEpoch; e++) {
            for (uint256 t = 0; t < feeTokens.length; t++) {
                address token = feeTokens[t];
                
                if (!epochs[e].claimed[msg.sender][token]) {
                    uint256 amount = _calculateClaimable(msg.sender, e, token);
                    if (amount > 0) {
                        epochs[e].claimed[msg.sender][token] = true;
                        amounts[t] += amount;
                    }
                }
            }
        }

        // Transfer all claimed amounts
        for (uint256 t = 0; t < feeTokens.length; t++) {
            if (amounts[t] > 0) {
                IERC20(feeTokens[t]).safeTransfer(msg.sender, amounts[t]);
                userLastClaimedEpoch[msg.sender][feeTokens[t]] = currentEpoch - 1;
            }
        }
    }

    // ============ View Functions ============

    /**
     * @notice Get claimable amount for user in epoch
     */
    function getClaimable(
        address user,
        uint256 epoch,
        address token
    ) external view returns (uint256) {
        if (epoch >= currentEpoch) return 0;
        if (epochs[epoch].claimed[user][token]) return 0;
        return _calculateClaimable(user, epoch, token);
    }

    /**
     * @notice Get total claimable across all epochs
     */
    function getTotalClaimable(
        address user,
        address token
    ) external view returns (uint256 total) {
        for (uint256 e = userLastClaimedEpoch[user][token] + 1; e < currentEpoch; e++) {
            if (!epochs[e].claimed[user][token]) {
                total += _calculateClaimable(user, e, token);
            }
        }
    }

    /**
     * @notice Get epoch info
     */
    function getEpochInfo(uint256 epoch) external view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 totalVebLF
    ) {
        Epoch storage e = epochs[epoch];
        return (e.startTime, e.endTime, e.totalVebLF);
    }

    /**
     * @notice Get fee token amount in epoch
     */
    function getEpochTokenAmount(uint256 epoch, address token) external view returns (uint256) {
        return epochs[epoch].tokenAmounts[token];
    }

    /**
     * @notice Get all fee tokens
     */
    function getFeeTokens() external view returns (address[] memory) {
        return feeTokens;
    }

    // ============ Internal Functions ============

    function _startNewEpoch() internal {
        currentEpoch++;
        
        uint256 start = _roundToWeek(block.timestamp);
        uint256 end = start + WEEK;

        epochs[currentEpoch].startTime = start;
        epochs[currentEpoch].endTime = end;
        epochs[currentEpoch].totalVebLF = votingEscrow.totalSupply();

        emit EpochStarted(currentEpoch, start, epochs[currentEpoch].totalVebLF);
    }

    function _calculateClaimable(
        address user,
        uint256 epoch,
        address token
    ) internal view returns (uint256) {
        Epoch storage e = epochs[epoch];
        
        if (e.totalVebLF == 0) return 0;

        // Get user's vebLF at epoch start
        uint256 userVebLF = votingEscrow.balanceOfAt(user, e.startTime);
        if (userVebLF == 0) return 0;

        // Calculate proportional share
        uint256 tokenAmount = e.tokenAmounts[token];
        return (tokenAmount * userVebLF) / e.totalVebLF;
    }

    function _roundToWeek(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / WEEK) * WEEK;
    }

    // ============ Admin Functions ============

    function addFeeToken(address token) external onlyOwner {
        if (!isFeeToken[token]) {
            feeTokens.push(token);
            isFeeToken[token] = true;
            emit FeeTokenAdded(token);
        }
    }

    function removeFeeToken(address token) external onlyOwner {
        if (isFeeToken[token]) {
            isFeeToken[token] = false;
            // Note: doesn't remove from array, just marks as inactive
            emit FeeTokenRemoved(token);
        }
    }
}

interface IVotingEscrow {
    function totalSupply() external view returns (uint256);
    function balanceOfAt(address account, uint256 timestamp) external view returns (uint256);
}
