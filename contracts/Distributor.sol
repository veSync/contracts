// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "contracts/interfaces/IERC20.sol";
import "contracts/interfaces/IVotingEscrow.sol";

import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract Distributor is Ownable, ReentrancyGuard {
    bytes32 public merkleRoot;

    mapping(address => uint) public claimed; // address -> claimed eth amount

    constructor() {}

    receive() external payable {}

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // user claim ETH
    // amount is cumulative claimable amount
    // if already claimed amount >= amount, revert
    function claim(
        uint amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        uint alreadyClaimedAmount = claimed[msg.sender];
        require(amount > alreadyClaimedAmount, "nothing to claim");

        // Verify the merkle proof
        bytes32 node = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender, amount)))
        );
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "Invalid proof"
        );

        // Claimable amount this time
        uint claimableAmount = amount - alreadyClaimedAmount;

        // Update the claimed amount
        claimed[msg.sender] = amount;

        // Send the ETH
        (bool success, ) = msg.sender.call{value: claimableAmount}("");
        require(success);
    }

    function emergencyWithdrawETH() external onlyOwner {
        uint remainingETH = address(this).balance;
        msg.sender.call{value: remainingETH}("");
    }
}
