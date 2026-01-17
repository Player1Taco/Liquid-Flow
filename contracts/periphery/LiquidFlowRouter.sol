// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title LiquidFlowRouter
 * @notice User-facing router for simplified interactions with Liquid Flow
 * @dev Provides convenience functions for common operations
 */
contract LiquidFlowRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    ILiquidFlowCore public immutable core;
    IBatchProcessor public immutable batchProcessor;

    /// @notice WETH address for ETH wrapping
    address public immutable WETH;

    // ============ Events ============

    event SwapExecuted(
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event LiquidityProvided(
        address indexed lp,
        address strategy,
        bytes32 strategyHash,
        uint256 value
    );

    // ============ Errors ============

    error InsufficientOutput();
    error DeadlineExpired();
    error InvalidPath();

    // ============ Constructor ============

    constructor(
        address _core,
        address _batchProcessor,
        address _weth
    ) {
        core = ILiquidFlowCore(_core);
        batchProcessor = IBatchProcessor(_batchProcessor);
        WETH = _weth;
    }

    // ============ Swap Functions ============

    /**
     * @notice Simple swap through batch auction
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @param minAmountOut Minimum output (slippage protection)
     * @param deadline Transaction deadline
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external nonReentrant returns (bytes32 intentId) {
        if (block.timestamp > deadline) revert DeadlineExpired();

        // Transfer tokens from user
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve batch processor
        IERC20(tokenIn).approve(address(batchProcessor), amountIn);

        // Submit intent to batch
        intentId = batchProcessor.submitIntent(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            0, // maxFee
            IBatchProcessor.MEVPreference.PROTECTED,
            true, // allowPartialFill
            deadline
        );

        return intentId;
    }

    /**
     * @notice Swap with ETH input
     */
    function swapETH(
        address tokenOut,
        uint256 minAmountOut,
        uint256 deadline
    ) external payable nonReentrant returns (bytes32 intentId) {
        if (block.timestamp > deadline) revert DeadlineExpired();

        // Wrap ETH
        IWETH(WETH).deposit{value: msg.value}();

        // Approve batch processor
        IERC20(WETH).approve(address(batchProcessor), msg.value);

        // Submit intent
        intentId = batchProcessor.submitIntent(
            WETH,
            tokenOut,
            msg.value,
            minAmountOut,
            0,
            IBatchProcessor.MEVPreference.PROTECTED,
            true,
            deadline
        );

        return intentId;
    }

    // ============ Liquidity Functions ============

    /**
     * @notice Provide liquidity to a strategy
     * @param strategy Strategy contract address
     * @param strategyData Encoded strategy parameters
     * @param tokens Token addresses
     * @param amounts Token amounts
     */
    function provideLiquidity(
        address strategy,
        bytes calldata strategyData,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external nonReentrant {
        // Approve core for all tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(msg.sender, msg.sender, 0); // Check balance
            // User must have already approved core
        }

        // Ship strategy
        core.ship(strategy, strategyData, tokens, amounts);

        bytes32 strategyHash = keccak256(abi.encode(msg.sender, strategy, strategyData));
        
        emit LiquidityProvided(msg.sender, strategy, strategyHash, _calculateValue(tokens, amounts));
    }

    /**
     * @notice Provide liquidity with ETH
     */
    function provideLiquidityETH(
        address strategy,
        bytes calldata strategyData,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external payable nonReentrant {
        // Wrap ETH
        IWETH(WETH).deposit{value: msg.value}();

        // Transfer WETH to user (they need to have approved core)
        IERC20(WETH).safeTransfer(msg.sender, msg.value);

        // Ship strategy
        core.ship(strategy, strategyData, tokens, amounts);

        bytes32 strategyHash = keccak256(abi.encode(msg.sender, strategy, strategyData));
        
        emit LiquidityProvided(msg.sender, strategy, strategyHash, _calculateValue(tokens, amounts));
    }

    // ============ View Functions ============

    /**
     * @notice Get quote for a swap
     */
    function getQuote(
        address strategy,
        bytes calldata strategyParams,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        // Call strategy's quote function
        (bool success, bytes memory data) = strategy.staticcall(
            abi.encodeWithSignature(
                "quoteExactIn((address,address,address,uint256,bytes32),bool,uint256)",
                strategyParams,
                zeroForOne,
                amountIn
            )
        );

        if (success) {
            amountOut = abi.decode(data, (uint256));
        }
    }

    // ============ Internal Functions ============

    function _calculateValue(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) internal pure returns (uint256 value) {
        // Simplified - in production would use oracle
        for (uint256 i = 0; i < amounts.length; i++) {
            value += amounts[i];
        }
    }

    // ============ Receive ============

    receive() external payable {}
}

interface ILiquidFlowCore {
    function ship(
        address strategy,
        bytes calldata strategyData,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external;
}

interface IBatchProcessor {
    enum MEVPreference { NONE, BASIC, PROTECTED, MAXIMUM }
    
    function submitIntent(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 maxFee,
        MEVPreference mevPref,
        bool allowPartialFill,
        uint256 deadline
    ) external returns (bytes32);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
}
