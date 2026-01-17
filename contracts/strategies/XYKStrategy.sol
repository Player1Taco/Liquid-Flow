// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title XYKStrategy
 * @notice Uniswap V2 style constant product AMM using Liquid Flow virtual balances
 * @dev Implements x * y = k invariant with configurable fees
 */
contract XYKStrategy is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct StrategyParams {
        address lp;
        address token0;
        address token1;
        uint256 feeBps;     // Fee in basis points (e.g., 30 = 0.3%)
        bytes32 salt;       // Unique identifier for multiple pools with same params
    }

    // ============ State Variables ============

    /// @notice LiquidFlowCore contract
    ILiquidFlowCore public immutable liquidFlowCore;

    /// @notice Basis points denominator
    uint256 private constant BPS_BASE = 10000;

    // ============ Events ============

    event Swap(
        address indexed lp,
        bytes32 indexed strategyHash,
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    // ============ Errors ============

    error InsufficientOutputAmount(uint256 actual, uint256 minimum);
    error InsufficientInputAmount(uint256 actual, uint256 maximum);
    error InvalidTokenPair();
    error ZeroAmount();
    error IdenticalTokens();

    // ============ Constructor ============

    constructor(address _liquidFlowCore) {
        liquidFlowCore = ILiquidFlowCore(_liquidFlowCore);
    }

    // ============ Swap Functions ============

    /**
     * @notice Execute a swap with exact input amount
     * @param params Strategy parameters
     * @param zeroForOne Direction (true = token0 -> token1)
     * @param amountIn Exact input amount
     * @param minAmountOut Minimum acceptable output (slippage protection)
     * @param recipient Address to receive output tokens
     * @return amountOut Actual output amount
     */
    function swapExactIn(
        StrategyParams calldata params,
        bool zeroForOne,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (params.token0 == params.token1) revert IdenticalTokens();

        bytes32 strategyHash = getStrategyHash(params);

        (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) = 
            _getBalances(params, strategyHash, zeroForOne);

        // Calculate output using constant product formula
        amountOut = _calculateAmountOut(amountIn, balanceIn, balanceOut, params.feeBps);
        
        if (amountOut < minAmountOut) {
            revert InsufficientOutputAmount(amountOut, minAmountOut);
        }

        // Pull output tokens from LP to recipient
        liquidFlowCore.pull(params.lp, strategyHash, tokenOut, amountOut, recipient);

        // Push input tokens from sender to LP
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(liquidFlowCore), amountIn);
        liquidFlowCore.push(params.lp, strategyHash, tokenIn, amountIn, address(this));

        uint256 fee = (amountIn * params.feeBps) / BPS_BASE;

        emit Swap(
            params.lp,
            strategyHash,
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            fee
        );

        return amountOut;
    }

    /**
     * @notice Execute a swap with exact output amount
     * @param params Strategy parameters
     * @param zeroForOne Direction (true = token0 -> token1)
     * @param amountOut Exact output amount desired
     * @param maxAmountIn Maximum acceptable input (slippage protection)
     * @param recipient Address to receive output tokens
     * @return amountIn Actual input amount required
     */
    function swapExactOut(
        StrategyParams calldata params,
        bool zeroForOne,
        uint256 amountOut,
        uint256 maxAmountIn,
        address recipient
    ) external nonReentrant returns (uint256 amountIn) {
        if (amountOut == 0) revert ZeroAmount();
        if (params.token0 == params.token1) revert IdenticalTokens();

        bytes32 strategyHash = getStrategyHash(params);

        (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) = 
            _getBalances(params, strategyHash, zeroForOne);

        // Calculate required input using constant product formula
        amountIn = _calculateAmountIn(amountOut, balanceIn, balanceOut, params.feeBps);
        
        if (amountIn > maxAmountIn) {
            revert InsufficientInputAmount(amountIn, maxAmountIn);
        }

        // Pull output tokens from LP to recipient
        liquidFlowCore.pull(params.lp, strategyHash, tokenOut, amountOut, recipient);

        // Push input tokens from sender to LP
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(liquidFlowCore), amountIn);
        liquidFlowCore.push(params.lp, strategyHash, tokenIn, amountIn, address(this));

        uint256 fee = (amountIn * params.feeBps) / BPS_BASE;

        emit Swap(
            params.lp,
            strategyHash,
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            fee
        );

        return amountIn;
    }

    // ============ View Functions ============

    /**
     * @notice Get quote for exact input swap
     */
    function quoteExactIn(
        StrategyParams calldata params,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        bytes32 strategyHash = getStrategyHash(params);
        
        (, , uint256 balanceIn, uint256 balanceOut) = 
            _getBalances(params, strategyHash, zeroForOne);

        return _calculateAmountOut(amountIn, balanceIn, balanceOut, params.feeBps);
    }

    /**
     * @notice Get quote for exact output swap
     */
    function quoteExactOut(
        StrategyParams calldata params,
        bool zeroForOne,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        bytes32 strategyHash = getStrategyHash(params);
        
        (, , uint256 balanceIn, uint256 balanceOut) = 
            _getBalances(params, strategyHash, zeroForOne);

        return _calculateAmountIn(amountOut, balanceIn, balanceOut, params.feeBps);
    }

    /**
     * @notice Get current reserves for a strategy
     */
    function getReserves(
        StrategyParams calldata params
    ) external view returns (uint256 reserve0, uint256 reserve1) {
        bytes32 strategyHash = getStrategyHash(params);
        
        reserve0 = liquidFlowCore.balanceOf(params.lp, address(this), strategyHash, params.token0);
        reserve1 = liquidFlowCore.balanceOf(params.lp, address(this), strategyHash, params.token1);
    }

    /**
     * @notice Calculate strategy hash
     */
    function getStrategyHash(StrategyParams calldata params) public pure returns (bytes32) {
        return keccak256(abi.encode(
            params.lp,
            params.token0,
            params.token1,
            params.feeBps,
            params.salt
        ));
    }

    // ============ Internal Functions ============

    function _getBalances(
        StrategyParams calldata params,
        bytes32 strategyHash,
        bool zeroForOne
    ) internal view returns (
        address tokenIn,
        address tokenOut,
        uint256 balanceIn,
        uint256 balanceOut
    ) {
        if (zeroForOne) {
            tokenIn = params.token0;
            tokenOut = params.token1;
        } else {
            tokenIn = params.token1;
            tokenOut = params.token0;
        }

        balanceIn = liquidFlowCore.balanceOf(params.lp, address(this), strategyHash, tokenIn);
        balanceOut = liquidFlowCore.balanceOf(params.lp, address(this), strategyHash, tokenOut);
    }

    /**
     * @notice Calculate output amount using constant product formula
     * @dev amountOut = (amountIn * (1 - fee) * balanceOut) / (balanceIn + amountIn * (1 - fee))
     */
    function _calculateAmountOut(
        uint256 amountIn,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 feeBps
    ) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * (BPS_BASE - feeBps);
        uint256 numerator = amountInWithFee * balanceOut;
        uint256 denominator = (balanceIn * BPS_BASE) + amountInWithFee;
        return numerator / denominator;
    }

    /**
     * @notice Calculate input amount for desired output
     * @dev amountIn = (balanceIn * amountOut * BPS) / ((balanceOut - amountOut) * (BPS - fee)) + 1
     */
    function _calculateAmountIn(
        uint256 amountOut,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 feeBps
    ) internal pure returns (uint256) {
        uint256 numerator = balanceIn * amountOut * BPS_BASE;
        uint256 denominator = (balanceOut - amountOut) * (BPS_BASE - feeBps);
        return (numerator / denominator) + 1;
    }
}

interface ILiquidFlowCore {
    function balanceOf(
        address lp,
        address strategy,
        bytes32 strategyHash,
        address token
    ) external view returns (uint256);

    function pull(
        address lp,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address recipient
    ) external;

    function push(
        address lp,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address from
    ) external;
}
