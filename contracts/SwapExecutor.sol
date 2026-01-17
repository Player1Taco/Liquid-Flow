// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1

pragma solidity ^0.8.0;

import { IAqua } from "@1inch/aqua/src/interfaces/IAqua.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SwapExecutor
 * @notice A contract that executes swaps and handles Aqua push callbacks
 * @dev This contract demonstrates how to integrate with the Aqua protocol
 *      by implementing the aquaPush callback mechanism
 */
contract SwapExecutor {
    using SafeERC20 for IERC20;

    IAqua public immutable AQUA;

    error OnlyAqua();

    constructor(address aqua) {
        AQUA = IAqua(aqua);
    }

    /**
     * @notice Executes an arbitrary call to a target contract
     * @param target The address of the contract to call
     * @param data The calldata to send
     * @return result The return data from the call
     */
    function arbitraryCall(address target, bytes calldata data) external returns (bytes memory result) {
        (bool success, bytes memory returnData) = target.call(data);
        require(success, "Call failed");
        return returnData;
    }

    /**
     * @notice Callback function called by Aqua during push operations
     * @dev This function is called when a swap requires tokens to be pushed to the maker
     * @param maker The address of the maker receiving tokens
     * @param strategyHash The hash identifying the strategy
     * @param token The token being pushed
     * @param amount The amount of tokens to push
     * @param data Additional data (unused in this implementation)
     */
    function aquaPush(
        address maker,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        bytes calldata data
    ) external {
        if (msg.sender != address(AQUA)) revert OnlyAqua();
        (data);
        IERC20(token).forceApprove(address(AQUA), amount);
        AQUA.push(maker, strategyHash, token, amount, address(this));
    }
}
