// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LFToken
 * @notice The Liquid Flow protocol token
 * @dev ERC20 with burn functionality that mints bLF tokens
 */
contract LFToken is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    
    /// @notice bLF token contract
    IBurnedLF public burnedLF;

    /// @notice Maximum supply (1 billion)
    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;

    /// @notice Minter addresses
    mapping(address => bool) public minters;

    // ============ Events ============

    event BurnedForBLF(address indexed user, uint256 amount);
    event MinterUpdated(address indexed minter, bool status);
    event BurnedLFSet(address indexed burnedLF);

    // ============ Errors ============

    error ExceedsMaxSupply();
    error NotMinter();
    error BurnedLFNotSet();
    error ZeroAmount();

    // ============ Modifiers ============

    modifier onlyMinter() {
        if (!minters[msg.sender]) revert NotMinter();
        _;
    }

    // ============ Constructor ============

    constructor() 
        ERC20("Liquid Flow", "LF") 
        ERC20Permit("Liquid Flow")
        Ownable(msg.sender) 
    {
        minters[msg.sender] = true;
    }

    // ============ Core Functions ============

    /**
     * @notice Burn LF tokens and receive bLF tokens
     * @param amount Amount of LF to burn
     * @return blfAmount Amount of bLF received (1:1)
     */
    function burnForBLF(uint256 amount) external returns (uint256 blfAmount) {
        if (amount == 0) revert ZeroAmount();
        if (address(burnedLF) == address(0)) revert BurnedLFNotSet();

        // Burn LF tokens
        _burn(msg.sender, amount);

        // Mint bLF tokens (1:1 ratio)
        burnedLF.mint(msg.sender, amount);

        emit BurnedForBLF(msg.sender, amount);

        return amount;
    }

    /**
     * @notice Mint new LF tokens (only minters)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyMinter {
        if (totalSupply() + amount > MAX_SUPPLY) revert ExceedsMaxSupply();
        _mint(to, amount);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set the bLF token contract
     */
    function setBurnedLF(address _burnedLF) external onlyOwner {
        burnedLF = IBurnedLF(_burnedLF);
        emit BurnedLFSet(_burnedLF);
    }

    /**
     * @notice Update minter status
     */
    function setMinter(address minter, bool status) external onlyOwner {
        minters[minter] = status;
        emit MinterUpdated(minter, status);
    }
}

interface IBurnedLF {
    function mint(address to, uint256 amount) external;
}
