// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1

pragma solidity ^0.8.0;

import { AquaApp } from "@1inch/aqua/src/AquaApp.sol";
import { IAqua } from "@1inch/aqua/src/interfaces/IAqua.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title XYCSwap
 * @notice A constant product AMM implementation using the Aqua protocol
 * @dev Implements X * Y = C (constant product) swap logic with Aqua's shared liquidity
 *
 * This contract demonstrates how to build an AMM on top of Aqua:
 * - Uses Aqua balances as virtual reserves instead of locked liquidity
 * - Supports both direct transfers and Aqua push callbacks for taker payments
 * - Implements standard constant product formula with configurable fees
 */
contract XYCSwap is AquaApp {
    using SafeERC20 for IERC20;

    uint256 private constant _BPS_BASE = 10000;

    /**
     * @notice Strategy parameters that define a unique AMM pool
     * @param maker The liquidity provider's address
     * @param token0 The first token in the pair
     * @param token1 The second token in the pair
     * @param feeBps Fee in basis points (e.g., 30 = 0.3%)
     * @param salt Unique identifier to allow multiple pools with same parameters
     */
    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        bytes32 salt;
    }

    error InsufficientOutputAmount(uint256 actual, uint256 minimum);
    error InsufficientInputAmount(uint256 actual, uint256 maximum);

    constructor(IAqua aqua) AquaApp(aqua) {}

    /**
     * @notice Executes a swap with exact input amount
     * @param strategy The strategy parameters defining the pool
     * @param zeroForOne Direction of swap (true = token0 -> token1)
     * @param takerUseAquaPush If true, uses Aqua push callback for taker payment
     * @param amountIn Exact amount of input tokens
     * @param amountOutMin Minimum acceptable output amount (slippage protection)
     * @param to Recipient address for output tokens
     * @param takerData Additional data passed to aquaPush callback
     * @return amountOut The actual output amount
     */
    function swapExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        bool takerUseAquaPush,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        bytes calldata takerData
    ) external returns (uint256 amountOut) {
        bytes32 strategyHash = _strategyHash(strategy);

        (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) =
            _getInAndOut(strategy, strategyHash, zeroForOne);

        amountOut = _quoteExactIn(strategy, balanceIn, balanceOut, amountIn);
        if (amountOut < amountOutMin) revert InsufficientOutputAmount(amountOut, amountOutMin);

        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        _collectInput(strategy.maker, strategyHash, tokenIn, amountIn, takerUseAquaPush, takerData);
    }

    /**
     * @notice Executes a swap with exact output amount
     * @param strategy The strategy parameters defining the pool
     * @param zeroForOne Direction of swap (true = token0 -> token1)
     * @param takerUseAquaPush If true, uses Aqua push callback for taker payment
     * @param amountOut Exact amount of output tokens desired
     * @param amountInMax Maximum acceptable input amount (slippage protection)
     * @param to Recipient address for output tokens
     * @param takerData Additional data passed to aquaPush callback
     * @return amountIn The actual input amount required
     */
    function swapExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        bool takerUseAquaPush,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        bytes calldata takerData
    ) external returns (uint256 amountIn) {
        bytes32 strategyHash = _strategyHash(strategy);

        (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) =
            _getInAndOut(strategy, strategyHash, zeroForOne);

        amountIn = _quoteExactOut(strategy, balanceIn, balanceOut, amountOut);
        if (amountIn > amountInMax) revert InsufficientInputAmount(amountIn, amountInMax);

        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        _collectInput(strategy.maker, strategyHash, tokenIn, amountIn, takerUseAquaPush, takerData);
    }

    /**
     * @notice Collects input tokens from the taker
     * @dev Either uses Aqua push callback or direct transferFrom
     */
    function _collectInput(
        address maker,
        bytes32 strategyHash,
        address tokenIn,
        uint256 amountIn,
        bool takerUseAquaPush,
        bytes calldata takerData
    ) internal {
        if (takerUseAquaPush) {
            AQUA.pushWithCallback(maker, strategyHash, tokenIn, amountIn, msg.sender, takerData);
        } else {
            IERC20(tokenIn).safeTransferFrom(msg.sender, maker, amountIn);
        }
    }

    /**
     * @notice Gets token addresses and current balances for a swap direction
     * @return tokenIn Input token address
     * @return tokenOut Output token address
     * @return balanceIn Current balance of input token
     * @return balanceOut Current balance of output token
     */
    function _getInAndOut(
        Strategy calldata strategy,
        bytes32 strategyHash,
        bool zeroForOne
    ) internal view returns (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) {
        (tokenIn, tokenOut) = zeroForOne
            ? (strategy.token0, strategy.token1)
            : (strategy.token1, strategy.token0);

        balanceIn = AQUA.balanceOf(strategy.maker, address(this), strategyHash, tokenIn);
        balanceOut = AQUA.balanceOf(strategy.maker, address(this), strategyHash, tokenOut);
    }

    /**
     * @notice Calculates output amount for exact input using constant product formula
     * @dev Formula: amountOut = (amountIn * (1 - fee) * balanceOut) / (balanceIn + amountIn * (1 - fee))
     */
    function _quoteExactIn(
        Strategy calldata strategy,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountIn
    ) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * (_BPS_BASE - strategy.feeBps) / _BPS_BASE;
        return amountInWithFee * balanceOut / (balanceIn + amountInWithFee);
    }

    /**
     * @notice Calculates input amount for exact output using constant product formula
     * @dev Formula: amountIn = (balanceIn * amountOut) / ((balanceOut - amountOut) * (1 - fee))
     */
    function _quoteExactOut(
        Strategy calldata strategy,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountOut
    ) internal pure returns (uint256) {
        return balanceIn * amountOut * _BPS_BASE / ((balanceOut - amountOut) * (_BPS_BASE - strategy.feeBps)) + 1;
    }

    /**
     * @notice Computes the strategy hash from strategy parameters
     * @dev Used as a unique identifier for the strategy in Aqua
     */
    function _strategyHash(Strategy calldata strategy) internal pure returns (bytes32) {
        return keccak256(abi.encode(strategy));
    }
}
