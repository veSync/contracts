// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "contracts/interfaces/IERC20.sol";
import "contracts/interfaces/IVotingEscrow.sol";

import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


contract PrivateSaleClaim is Ownable, ReentrancyGuard {

    IERC20 public salesToken;
    IVotingEscrow public ve;
    uint public immutable maxBonusPercentage;
    uint public immutable bonusEndTime; // The timestamp when lock Bonus period ends
    
    mapping(address => bool) public hasClaimed; // whether user has claimed
    
    bytes32 public merkleRoot;
    
    uint public tokensToClaim;

    // Tokens reserved in the contract for claims + max bonus
    // Only unreserved tokens can be withdrawn by team
    uint public reservedTokens;

    // mapping from lock time (in months) to bonus percentage
    // we treat 1 month = 4 weeks for simplicity
    mapping(uint => uint) internal bonusPercentages; 

    constructor(
        uint _bonusEndTime
    ) {
        bonusEndTime = _bonusEndTime;

        bonusPercentages[1] = 6; // 1 mo lock = 6% bonus in veVS
        bonusPercentages[2] = 12; // 2 mo lock = 12% bonus
        bonusPercentages[4] = 18; // 4 mo lock = 18% bonus
        bonusPercentages[8] = 24; // 8 mo lock = 24% bonus
        bonusPercentages[12] = 30; // 12 mo lock = 30% bonus
        maxBonusPercentage = 30; // 30% max bonus
    }

    // owner can set merkle root
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // owner need to set sales token and ve token before enabling claiming
    // owner should approve spending of _salesToken, and have at least 130% in the wallet
    function setSaleTokenAndVe(IERC20 _salesToken, IVotingEscrow _ve, uint _tokensToClaim) external onlyOwner {
        require(address(salesToken) == address(0), "Token already set");
        require(address(ve) == address(0), "ve already set");

        // avoid accidentally setting the wrong address
        require(address(_salesToken) != address(0), "Invalid token address");
        require(address(_ve) != address(0), "Invalid ve address");

        require(_ve.token() == address(_salesToken), "ve token address mismatch");

        salesToken = _salesToken;
        ve = _ve;
        tokensToClaim = _tokensToClaim;

        _salesToken.approve(address(_ve), type(uint).max);
        
        reservedTokens = _tokensToClaim + _tokensToClaim * maxBonusPercentage / 100;
        _safeTransferFrom(address(_salesToken), msg.sender, address(this), reservedTokens);
    }
    
    // ------- user interaction -------

    // user can optionally lock their tokens for 1/2/4/8/12 months to get bonus in liquid $VS
    // 1 mo = 4 epochs
    // 2 mo = 8 epochs
    // 4 mo = 16 epochs
    // 8 mo = 32 epochs
    // 12 mo = 52 epochs (1 year, this is different)
    // if lockMonths == 0, no lock
    // bonus amount = lockAmount * bonusPercentage / 100
    function claimAndLock(uint claimAmount, bytes32[] calldata merkleProof, uint lockAmount, uint lockMonths) external nonReentrant {
        require(address(salesToken) != address(0), "Not initialized");
        require(!hasClaimed[msg.sender], "Nothing to claim");
        require(lockMonths == 0 || bonusPercentages[lockMonths] > 0, "Must lock 1/2/4/8/12 months");
        require(claimAmount >= lockAmount, "Invalid lock amount");
        
        // Verify the merkle proof
        bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, claimAmount))));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Invalid proof");

        hasClaimed[msg.sender] = true;

        uint bonus = 0;

        if (lockAmount > 0 && lockMonths > 0) {
            // only give bonus before bonusEndTime
            if (block.timestamp < bonusEndTime) {
                bonus = getBonusAmount(lockAmount, lockMonths);
            }

            // convert lock duration to seconds
            uint lockDurationSeconds = lockMonths == 12 ? 52 weeks : lockMonths * 4 weeks;

            // mint veVS of lockAmount
            ve.create_lock_for(lockAmount + bonus, lockDurationSeconds, msg.sender);
        }

        // transfer liquid tokens
        _safeTransfer(address(salesToken), msg.sender, claimAmount - lockAmount);

        // decrease the amount of reserved tokens
        reservedTokens -= (claimAmount + claimAmount * maxBonusPercentage / 100);
    }

    function emergencyWithdrawTokens() external onlyOwner {
        uint allTokens = salesToken.balanceOf(address(this));
        _safeTransfer(address(salesToken), msg.sender, allTokens);
    }

    function withdrawRemainingTokens() external onlyOwner {
        _safeTransfer(address(salesToken), msg.sender, getRemainingTokens());
    }

    // View functions

    function getBonusAmount(uint lockAmount, uint lockMonths) public view returns (uint) {
        return lockAmount * bonusPercentages[lockMonths] / 100;
    }

    // returns the unsold tokens + unallocated bonus in the contract
    function getRemainingTokens() public view returns (uint) {
        return salesToken.balanceOf(address(this)) - reservedTokens;
    }
    
    // Helper functions

    function _safeTransfer(address token, address to, uint value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(address token, address from, address to, uint value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}