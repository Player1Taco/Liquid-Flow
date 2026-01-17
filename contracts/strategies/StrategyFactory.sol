// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StrategyFactory
 * @notice Factory for deploying and registering new strategy contracts
 * @dev Permissionless strategy creation with optional verification
 */
contract StrategyFactory is Ownable {
    
    // ============ Structs ============

    struct StrategyTemplate {
        string name;
        address implementation;
        bool isActive;
        bool requiresVerification;
        uint256 deploymentCount;
    }

    struct DeployedStrategy {
        address strategyAddress;
        address deployer;
        uint256 templateId;
        uint256 deployedAt;
        bool isVerified;
    }

    // ============ State Variables ============

    /// @notice Strategy templates
    mapping(uint256 => StrategyTemplate) public templates;
    uint256 public templateCount;

    /// @notice Deployed strategies
    mapping(address => DeployedStrategy) public deployedStrategies;
    address[] public allDeployedStrategies;

    /// @notice LiquidFlowCore reference
    address public liquidFlowCore;

    /// @notice Verified deployers (can deploy without review)
    mapping(address => bool) public verifiedDeployers;

    /// @notice Deployment fee (in native token)
    uint256 public deploymentFee = 0.01 ether;

    // ============ Events ============

    event TemplateAdded(uint256 indexed templateId, string name, address implementation);
    event TemplateUpdated(uint256 indexed templateId, bool isActive);
    event StrategyDeployed(
        address indexed strategy,
        address indexed deployer,
        uint256 indexed templateId
    );
    event StrategyVerified(address indexed strategy);
    event DeployerVerified(address indexed deployer, bool verified);

    // ============ Errors ============

    error TemplateNotActive();
    error InsufficientFee();
    error StrategyNotFound();
    error AlreadyVerified();

    // ============ Constructor ============

    constructor(address _liquidFlowCore) Ownable(msg.sender) {
        liquidFlowCore = _liquidFlowCore;
    }

    // ============ Template Management ============

    /**
     * @notice Add a new strategy template
     * @param name Template name
     * @param implementation Implementation address
     * @param requiresVerification Whether deployments need verification
     */
    function addTemplate(
        string calldata name,
        address implementation,
        bool requiresVerification
    ) external onlyOwner returns (uint256 templateId) {
        templateId = templateCount++;
        
        templates[templateId] = StrategyTemplate({
            name: name,
            implementation: implementation,
            isActive: true,
            requiresVerification: requiresVerification,
            deploymentCount: 0
        });

        emit TemplateAdded(templateId, name, implementation);
    }

    /**
     * @notice Update template status
     */
    function setTemplateActive(uint256 templateId, bool isActive) external onlyOwner {
        templates[templateId].isActive = isActive;
        emit TemplateUpdated(templateId, isActive);
    }

    // ============ Strategy Deployment ============

    /**
     * @notice Deploy a new strategy from template
     * @param templateId Template to use
     * @param initData Initialization data
     */
    function deployStrategy(
        uint256 templateId,
        bytes calldata initData
    ) external payable returns (address strategy) {
        StrategyTemplate storage template = templates[templateId];
        
        if (!template.isActive) revert TemplateNotActive();
        if (msg.value < deploymentFee) revert InsufficientFee();

        // Clone the implementation (minimal proxy pattern)
        strategy = _clone(template.implementation);

        // Initialize if needed
        if (initData.length > 0) {
            (bool success, ) = strategy.call(initData);
            require(success, "Initialization failed");
        }

        // Register deployment
        bool autoVerified = verifiedDeployers[msg.sender] || !template.requiresVerification;
        
        deployedStrategies[strategy] = DeployedStrategy({
            strategyAddress: strategy,
            deployer: msg.sender,
            templateId: templateId,
            deployedAt: block.timestamp,
            isVerified: autoVerified
        });

        allDeployedStrategies.push(strategy);
        template.deploymentCount++;

        emit StrategyDeployed(strategy, msg.sender, templateId);

        // Refund excess
        if (msg.value > deploymentFee) {
            payable(msg.sender).transfer(msg.value - deploymentFee);
        }

        return strategy;
    }

    /**
     * @notice Clone implementation using minimal proxy (EIP-1167)
     */
    function _clone(address implementation) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "Clone failed");
    }

    // ============ Verification ============

    /**
     * @notice Verify a deployed strategy (admin only)
     */
    function verifyStrategy(address strategy) external onlyOwner {
        DeployedStrategy storage deployed = deployedStrategies[strategy];
        if (deployed.strategyAddress == address(0)) revert StrategyNotFound();
        if (deployed.isVerified) revert AlreadyVerified();

        deployed.isVerified = true;
        emit StrategyVerified(strategy);
    }

    /**
     * @notice Set deployer verification status
     */
    function setDeployerVerified(address deployer, bool verified) external onlyOwner {
        verifiedDeployers[deployer] = verified;
        emit DeployerVerified(deployer, verified);
    }

    // ============ View Functions ============

    function getTemplate(uint256 templateId) external view returns (StrategyTemplate memory) {
        return templates[templateId];
    }

    function getDeployedStrategy(address strategy) external view returns (DeployedStrategy memory) {
        return deployedStrategies[strategy];
    }

    function getAllDeployedStrategies() external view returns (address[] memory) {
        return allDeployedStrategies;
    }

    function getDeployedStrategiesCount() external view returns (uint256) {
        return allDeployedStrategies.length;
    }

    // ============ Admin Functions ============

    function setDeploymentFee(uint256 _fee) external onlyOwner {
        deploymentFee = _fee;
    }

    function setLiquidFlowCore(address _core) external onlyOwner {
        liquidFlowCore = _core;
    }

    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
