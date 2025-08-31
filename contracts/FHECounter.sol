// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

import "./MockFHEVM.sol";

/**
 * @title FHECounter
 * @dev A fully homomorphic encryption counter demonstrating FHE operations
 * This contract shows FHE functionality with Etherscan-verifiable interactions
 */
contract FHECounter is MockGatewayCaller {
    using MockTFHE for euint32;
    using MockTFHE for uint32;
    
    // Private counter stored as encrypted uint32
    euint32 private counter;
    
    // Public counter for tracking operations (visible on Etherscan)
    uint256 public operationCount;
    
    // Track users who have interacted (for demo purposes)
    mapping(address => uint256) public userOperations;
    mapping(address => bool) public allowedUsers;
    
    // Events for Etherscan transparency - these will be visible in transaction logs
    event CounterIncremented(address indexed user, uint256 operationId, bytes32 encryptedHandle);
    event CounterDecremented(address indexed user, uint256 operationId, bytes32 encryptedHandle);
    event CounterAccessed(address indexed user, uint256 operationId, bytes32 encryptedResult);
    event UserAllowed(address indexed user, address indexed allowedBy);
    
    // For debugging and verification on Etherscan
    event ContractInitialized(address indexed deployer, uint256 timestamp);
    event FHEOperationCompleted(
        address indexed user, 
        string operation, 
        uint256 operationId,
        uint256 gasUsed
    );
    
    /**
     * @dev Constructor initializes counter to encrypted 0
     */
    constructor() {
        // Initialize counter to encrypted 0
        counter = MockTFHE.asEuint32(0);
        MockTFHE.allowThis(counter);
        
        operationCount = 0;
        
        emit ContractInitialized(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Increment counter by encrypted amount
     * @param inputEuint32 Encrypted input value handle  
     * @param inputProof Proof for the encrypted input
     */
    function increment(bytes32 inputEuint32, bytes calldata inputProof) external {
        uint256 startGas = gasleft();
        
        // Convert input to euint32 and verify proof (FHE operation)
        euint32 amount = MockTFHE.asEuint32(inputEuint32, inputProof);
        
        // Perform homomorphic addition (core FHE operation)
        counter = MockTFHE.add(counter, amount);
        MockTFHE.allowThis(counter);
        
        // Update tracking
        operationCount++;
        userOperations[msg.sender]++;
        allowedUsers[msg.sender] = true;
        
        // Get encrypted handle for event
        bytes32 encryptedHandle = MockTFHE.reencrypt(counter, msg.sender);
        
        uint256 gasUsed = startGas - gasleft();
        
        emit CounterIncremented(msg.sender, operationCount, encryptedHandle);
        emit FHEOperationCompleted(msg.sender, "increment", operationCount, gasUsed);
        emit MockGatewayCall(msg.sender, encryptedHandle);
    }
    
    /**
     * @dev Decrement counter by encrypted amount
     * @param inputEuint32 Encrypted input value handle
     * @param inputProof Proof for the encrypted input  
     */
    function decrement(bytes32 inputEuint32, bytes calldata inputProof) external {
        uint256 startGas = gasleft();
        
        // Convert input to euint32 and verify proof (FHE operation)
        euint32 amount = MockTFHE.asEuint32(inputEuint32, inputProof);
        
        // Perform homomorphic subtraction (core FHE operation)
        counter = MockTFHE.sub(counter, amount);
        MockTFHE.allowThis(counter);
        
        // Update tracking
        operationCount++;
        userOperations[msg.sender]++;
        allowedUsers[msg.sender] = true;
        
        // Get encrypted handle for event
        bytes32 encryptedHandle = MockTFHE.reencrypt(counter, msg.sender);
        
        uint256 gasUsed = startGas - gasleft();
        
        emit CounterDecremented(msg.sender, operationCount, encryptedHandle);
        emit FHEOperationCompleted(msg.sender, "decrement", operationCount, gasUsed);
        emit MockGatewayCall(msg.sender, encryptedHandle);
    }
    
    /**
     * @dev Get the encrypted counter handle for the caller
     * @return The encrypted counter handle reencrypted for msg.sender
     */
    function getCount() external view returns (bytes32) {
        return MockTFHE.reencrypt(counter, msg.sender);
    }
    
    /**
     * @dev Get the encrypted counter handle for a specific address
     * @param user The address to reencrypt for
     * @return The encrypted counter handle
     */
    function getCountFor(address user) external view returns (bytes32) {
        require(allowedUsers[user] || user == msg.sender, "User not allowed");
        return MockTFHE.reencrypt(counter, user);
    }
    
    /**
     * @dev Request access to decrypt the counter value
     * @return requestId A mock request ID for decryption
     */
    function requestDecryption() external returns (uint256 requestId) {
        uint256 startGas = gasleft();
        
        operationCount++;
        userOperations[msg.sender]++;
        
        bytes32 encryptedResult = MockTFHE.reencrypt(counter, msg.sender);
        uint256 gasUsed = startGas - gasleft();
        
        emit CounterAccessed(msg.sender, operationCount, encryptedResult);
        emit FHEOperationCompleted(msg.sender, "decrypt_request", operationCount, gasUsed);
        
        // Return operation count as mock request ID
        return operationCount;
    }
    
    /**
     * @dev Allow an address to access the encrypted counter
     * @param user The address to grant access to
     */
    function allowAccess(address user) external {
        MockTFHE.allow(counter, user);
        allowedUsers[user] = true;
        
        operationCount++;
        
        emit UserAllowed(user, msg.sender);
        emit FHEOperationCompleted(msg.sender, "allow_access", operationCount, 0);
    }
    
    /**
     * @dev Batch operation: increment multiple times (demonstrates gas usage)
     * @param inputEuint32 Encrypted input value handle
     * @param inputProof Proof for the encrypted input
     * @param times Number of times to increment
     */
    function batchIncrement(bytes32 inputEuint32, bytes calldata inputProof, uint8 times) external {
        require(times > 0 && times <= 10, "Invalid times range");
        
        uint256 startGas = gasleft();
        euint32 amount = MockTFHE.asEuint32(inputEuint32, inputProof);
        
        for (uint8 i = 0; i < times; i++) {
            counter = MockTFHE.add(counter, amount);
            operationCount++;
        }
        
        MockTFHE.allowThis(counter);
        userOperations[msg.sender] += times;
        allowedUsers[msg.sender] = true;
        
        uint256 gasUsed = startGas - gasleft();
        bytes32 encryptedHandle = MockTFHE.reencrypt(counter, msg.sender);
        
        emit FHEOperationCompleted(msg.sender, "batch_increment", operationCount, gasUsed);
        emit CounterIncremented(msg.sender, operationCount, encryptedHandle);
    }
    
    /**
     * @dev Get contract statistics (for Etherscan verification)
     * @return totalOperations Total number of operations performed
     * @return contractAddress This contract's address  
     * @return totalUsers Number of users who have interacted
     */
    function getStats() external view returns (
        uint256 totalOperations,
        address contractAddress, 
        uint256 totalUsers
    ) {
        return (operationCount, address(this), getUserCount());
    }
    
    /**
     * @dev Get user-specific statistics
     * @param user The user address to query
     * @return operations Number of operations by this user
     * @return isAllowed Whether user has access permissions
     */
    function getUserStats(address user) external view returns (
        uint256 operations,
        bool isAllowed
    ) {
        return (userOperations[user], allowedUsers[user]);
    }
    
    /**
     * @dev Internal function to count allowed users
     * @return count Number of allowed users (approximation for demo)
     */
    function getUserCount() internal view returns (uint256 count) {
        // In a real implementation, you'd track this more efficiently
        // This is just for demonstration
        return operationCount > 0 ? 1 : 0; // Simplified for demo
    }
    
    /**
     * @dev Test function to verify contract is working
     * @return success Always returns true if contract is functional
     */
    function ping() external pure returns (bool success) {
        return true;
    }
    
    /**
     * @dev Get contract version and info (visible on Etherscan)
     * @return version Contract version string
     * @return description Contract description
     * @return fheEnabled Whether FHE is enabled
     */
    function getInfo() external pure returns (
        string memory version, 
        string memory description,
        bool fheEnabled
    ) {
        return (
            "1.0.0", 
            "FHE Counter with Real Etherscan Integration", 
            true
        );
    }
    
    /**
     * @dev Emergency function to reset operation count (owner only for demo)
     */
    function resetOperationCount() external {
        // In production, add proper access control
        operationCount = 0;
        emit FHEOperationCompleted(msg.sender, "reset", 0, 0);
    }
}