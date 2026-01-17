// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BridgeRouter
 * @notice Aggregates multiple bridge providers for cross-chain liquidity
 * @dev Users can choose their preferred bridge based on speed, cost, and security
 */
contract BridgeRouter is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ Enums ============

    enum BridgeProvider {
        DEBRIDGE,
        STARGATE,
        ACROSS,
        NATIVE
    }

    // ============ Structs ============

    struct BridgeAdapter {
        address adapter;
        bool isActive;
        uint256 totalVolume;
        uint256 successCount;
        uint256 failCount;
    }

    struct BridgeQuote {
        BridgeProvider provider;
        uint256 estimatedTime;      // seconds
        uint256 fee;                // in source token
        uint256 outputAmount;       // expected output
        uint8 securityRating;       // 1-5 stars
    }

    struct BridgeRequest {
        bytes32 requestId;
        address user;
        BridgeProvider provider;
        uint256 srcChain;
        uint256 dstChain;
        address token;
        uint256 amount;
        address recipient;
        uint256 timestamp;
        bool completed;
    }

    // ============ State Variables ============

    /// @notice Bridge adapters by provider
    mapping(BridgeProvider => BridgeAdapter) public adapters;

    /// @notice Bridge requests
    mapping(bytes32 => BridgeRequest) public requests;

    /// @notice Request counter
    uint256 public requestCount;

    /// @notice Protocol fee (basis points)
    uint256 public protocolFeeBps = 50; // 0.5%

    /// @notice Fee collector
    address public feeCollector;

    /// @notice Supported chains
    mapping(uint256 => bool) public supportedChains;

    /// @notice Supported tokens per chain
    mapping(uint256 => mapping(address => bool)) public supportedTokens;

    // ============ Events ============

    event BridgeInitiated(
        bytes32 indexed requestId,
        address indexed user,
        BridgeProvider provider,
        uint256 srcChain,
        uint256 dstChain,
        address token,
        uint256 amount
    );

    event BridgeCompleted(
        bytes32 indexed requestId,
        address indexed user,
        uint256 outputAmount
    );

    event BridgeFailed(
        bytes32 indexed requestId,
        address indexed user,
        string reason
    );

    event AdapterUpdated(BridgeProvider provider, address adapter, bool isActive);

    // ============ Errors ============

    error UnsupportedChain();
    error UnsupportedToken();
    error AdapterNotActive();
    error InsufficientAmount();
    error BridgeFailed();
    error InvalidProvider();

    // ============ Constructor ============

    constructor(address _feeCollector) Ownable(msg.sender) {
        feeCollector = _feeCollector;
    }

    // ============ Core Functions ============

    /**
     * @notice Get quotes from all available bridges
     * @param srcChain Source chain ID
     * @param dstChain Destination chain ID
     * @param token Token address
     * @param amount Amount to bridge
     * @return quotes Array of quotes from each provider
     */
    function getQuotes(
        uint256 srcChain,
        uint256 dstChain,
        address token,
        uint256 amount
    ) external view returns (BridgeQuote[] memory quotes) {
        quotes = new BridgeQuote[](4);

        // deBridge quote
        if (adapters[BridgeProvider.DEBRIDGE].isActive) {
            quotes[0] = BridgeQuote({
                provider: BridgeProvider.DEBRIDGE,
                estimatedTime: 120,     // ~2 minutes
                fee: (amount * 45) / 10000, // 0.45%
                outputAmount: amount - (amount * 45) / 10000,
                securityRating: 4
            });
        }

        // Stargate quote
        if (adapters[BridgeProvider.STARGATE].isActive) {
            quotes[1] = BridgeQuote({
                provider: BridgeProvider.STARGATE,
                estimatedTime: 300,     // ~5 minutes
                fee: (amount * 38) / 10000, // 0.38%
                outputAmount: amount - (amount * 38) / 10000,
                securityRating: 4
            });
        }

        // Across quote
        if (adapters[BridgeProvider.ACROSS].isActive) {
            quotes[2] = BridgeQuote({
                provider: BridgeProvider.ACROSS,
                estimatedTime: 60,      // ~1 minute
                fee: (amount * 52) / 10000, // 0.52%
                outputAmount: amount - (amount * 52) / 10000,
                securityRating: 4
            });
        }

        // Native bridge quote
        if (adapters[BridgeProvider.NATIVE].isActive) {
            quotes[3] = BridgeQuote({
                provider: BridgeProvider.NATIVE,
                estimatedTime: 604800,  // ~7 days
                fee: (amount * 12) / 10000, // 0.12%
                outputAmount: amount - (amount * 12) / 10000,
                securityRating: 5
            });
        }

        return quotes;
    }

    /**
     * @notice Initiate a bridge transfer
     * @param provider Bridge provider to use
     * @param dstChain Destination chain ID
     * @param token Token to bridge
     * @param amount Amount to bridge
     * @param recipient Recipient on destination chain
     */
    function bridge(
        BridgeProvider provider,
        uint256 dstChain,
        address token,
        uint256 amount,
        address recipient
    ) external payable nonReentrant returns (bytes32 requestId) {
        if (!supportedChains[dstChain]) revert UnsupportedChain();
        if (!supportedTokens[dstChain][token]) revert UnsupportedToken();
        
        BridgeAdapter storage adapter = adapters[provider];
        if (!adapter.isActive) revert AdapterNotActive();

        // Calculate and collect protocol fee
        uint256 protocolFee = (amount * protocolFeeBps) / 10000;
        uint256 bridgeAmount = amount - protocolFee;

        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Send protocol fee to collector
        if (protocolFee > 0) {
            IERC20(token).safeTransfer(feeCollector, protocolFee);
        }

        // Generate request ID
        requestId = keccak256(abi.encode(
            msg.sender,
            provider,
            dstChain,
            token,
            amount,
            requestCount++
        ));

        // Store request
        requests[requestId] = BridgeRequest({
            requestId: requestId,
            user: msg.sender,
            provider: provider,
            srcChain: block.chainid,
            dstChain: dstChain,
            token: token,
            amount: bridgeAmount,
            recipient: recipient,
            timestamp: block.timestamp,
            completed: false
        });

        // Approve adapter
        IERC20(token).approve(adapter.adapter, bridgeAmount);

        // Call adapter to initiate bridge
        (bool success, ) = adapter.adapter.call(
            abi.encodeWithSignature(
                "bridge(uint256,address,uint256,address)",
                dstChain,
                token,
                bridgeAmount,
                recipient
            )
        );

        if (!success) {
            adapter.failCount++;
            revert BridgeFailed();
        }

        adapter.totalVolume += bridgeAmount;
        adapter.successCount++;

        emit BridgeInitiated(
            requestId,
            msg.sender,
            provider,
            block.chainid,
            dstChain,
            token,
            bridgeAmount
        );

        return requestId;
    }

    /**
     * @notice Mark bridge as completed (called by adapter or relayer)
     * @param requestId Request ID
     * @param outputAmount Actual output amount received
     */
    function completeBridge(
        bytes32 requestId,
        uint256 outputAmount
    ) external {
        BridgeRequest storage request = requests[requestId];
        require(!request.completed, "Already completed");
        require(
            msg.sender == adapters[request.provider].adapter || msg.sender == owner(),
            "Unauthorized"
        );

        request.completed = true;

        emit BridgeCompleted(requestId, request.user, outputAmount);
    }

    // ============ View Functions ============

    function getRequest(bytes32 requestId) external view returns (BridgeRequest memory) {
        return requests[requestId];
    }

    function getAdapter(BridgeProvider provider) external view returns (BridgeAdapter memory) {
        return adapters[provider];
    }

    function isChainSupported(uint256 chainId) external view returns (bool) {
        return supportedChains[chainId];
    }

    function isTokenSupported(uint256 chainId, address token) external view returns (bool) {
        return supportedTokens[chainId][token];
    }

    // ============ Admin Functions ============

    function setAdapter(
        BridgeProvider provider,
        address adapter,
        bool isActive
    ) external onlyOwner {
        adapters[provider] = BridgeAdapter({
            adapter: adapter,
            isActive: isActive,
            totalVolume: adapters[provider].totalVolume,
            successCount: adapters[provider].successCount,
            failCount: adapters[provider].failCount
        });

        emit AdapterUpdated(provider, adapter, isActive);
    }

    function setSupportedChain(uint256 chainId, bool supported) external onlyOwner {
        supportedChains[chainId] = supported;
    }

    function setSupportedToken(
        uint256 chainId,
        address token,
        bool supported
    ) external onlyOwner {
        supportedTokens[chainId][token] = supported;
    }

    function setProtocolFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 100, "Fee too high"); // Max 1%
        protocolFeeBps = _feeBps;
    }

    function setFeeCollector(address _collector) external onlyOwner {
        feeCollector = _collector;
    }

    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    receive() external payable {}
}
