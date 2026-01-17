// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BurnedLF (bLF)
 * @notice Non-transferable token representing burned LF
 * @dev Soulbound token - can only be minted by LF contract and locked for vebLF
 */
contract BurnedLF is ERC20, Ownable {
    
    /// @notice LF token contract (only minter)
    address public lfToken;

    /// @notice VotingEscrow contract (can lock bLF)
    address public votingEscrow;

    // ============ Events ============

    event LFTokenSet(address indexed lfToken);
    event VotingEscrowSet(address indexed votingEscrow);

    // ============ Errors ============

    error TransferNotAllowed();
    error NotLFToken();
    error NotVotingEscrow();
    error ZeroAddress();

    // ============ Constructor ============

    constructor() ERC20("Burned Liquid Flow", "bLF") Ownable(msg.sender) {}

    // ============ Core Functions ============

    /**
     * @notice Mint bLF tokens (only LF token contract)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        if (msg.sender != lfToken) revert NotLFToken();
        _mint(to, amount);
    }

    /**
     * @notice Burn bLF when locking for vebLF (only VotingEscrow)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnForLock(address from, uint256 amount) external {
        if (msg.sender != votingEscrow) revert NotVotingEscrow();
        _burn(from, amount);
    }

    // ============ Transfer Restrictions (Soulbound) ============

    /**
     * @dev Override transfer to prevent transfers (soulbound)
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert TransferNotAllowed();
    }

    /**
     * @dev Override transferFrom to prevent transfers (soulbound)
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert TransferNotAllowed();
    }

    /**
     * @dev Override approve to prevent approvals (soulbound)
     */
    function approve(address, uint256) public pure override returns (bool) {
        revert TransferNotAllowed();
    }

    // ============ Admin Functions ============

    function setLFToken(address _lfToken) external onlyOwner {
        if (_lfToken == address(0)) revert ZeroAddress();
        lfToken = _lfToken;
        emit LFTokenSet(_lfToken);
    }

    function setVotingEscrow(address _votingEscrow) external onlyOwner {
        if (_votingEscrow == address(0)) revert ZeroAddress();
        votingEscrow = _votingEscrow;
        emit VotingEscrowSet(_votingEscrow);
    }
}
