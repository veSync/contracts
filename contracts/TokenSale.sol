// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "contracts/interfaces/IERC20.sol";
import "contracts/interfaces/IVotingEscrow.sol";

import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract TokenSale is Ownable, ReentrancyGuard {
    IERC20 public immutable salesToken;
    IVotingEscrow public immutable ve;
    uint256 public immutable tokensToSell;
    uint256 public immutable wlRate;
    uint256 public immutable publicRate;

    // those who lock up their tokens right away at claim time get a bonus
    uint256 public immutable maxBonusPercentage;

    bool public started; // 1st stage: WL sale
    bool public publicRoundStarted; // 2nd stage: public sale
    bool public finished; // 3rd stage: finished and claimable
    
    bytes32 public merkleRoot;

    uint256 public totalTokensSold;
    uint256 public reservedTokens; // tokens reserved for sales + bonus. only unreserved tokens can be withdrawn by team after sale ends
    mapping(address => uint256) public claimableAmounts; // amount of tokens claimable by user
    mapping(address => uint256) public wlCommitments; // amount of ETH committed in WL sale

    uint internal constant WEEK = 1 weeks;
    uint internal constant MAX_LOCK_TIME = 52 weeks; // max lock is 1 year
    uint internal constant MIN_LOCK_TIME = 4 weeks;

    constructor(
        IERC20 _salesToken,
        IVotingEscrow _ve,
        uint256 _wlRate, // whitelist sale ETH to token conversion rate
        uint256 _publicRate, // public sale ETH to token conversion rate
        uint256 _tokensToSell,
        uint256 _maxBonusPercentage
    ) {
        require(
            _wlRate >= _publicRate,
            "WL price must not be higher than public"
        );
        require(_maxBonusPercentage <= 100, "Max bonus must be <= 100%");

        // token must be 18 decimals, otherwise we'll have problems with ETH conversion rate
        require(_salesToken.decimals() == 18, "Token must be 18 decimals");

        require(_ve.token() == address(_salesToken), "ve token address mismatch");

        salesToken = _salesToken;
        ve = _ve;
        tokensToSell = _tokensToSell;
        wlRate = _wlRate;
        publicRate = _publicRate;
        maxBonusPercentage = _maxBonusPercentage;
        _salesToken.approve(address(_ve), type(uint).max);
    }

    // owner can set merkle root for WL sale
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // start WL sale and transfer tokens to this contract
    function start() external onlyOwner {
        require(!started, "Already started");
        started = true;
        _safeTransferFrom(address(salesToken), msg.sender, address(this), tokensToSell * (100 + maxBonusPercentage) / 100);
    }

    // start public sale, can only be called after WL sale is started
    function startPublicRound() external onlyOwner {
        require(started, "Not started yet");
        require(!publicRoundStarted, "Already started");
        publicRoundStarted = true;
    }
    
    function finish() external onlyOwner {
        require(!finished, "Already finished");
        finished = true;

        // transfer ETH to owner
        uint256 remainingETH = address(this).balance;
        (bool success, ) = msg.sender.call{value: remainingETH}("");
        require(success, "Failed to transfer ether");
    }

    // user address + capAmount must match merkle proof
    // capAmount is the max amount of ETH user can commit for WL sale
    function commitWhitelist(uint256 capAmount, bytes32[] calldata merkleProof) external payable nonReentrant {
        require(msg.value > 0, "No ETH sent");
        require(capAmount > 0, "Cap amount must be > 0");
        require(started, "Not started yet");
        require(!finished, "Already finished");
        require(!publicRoundStarted, "Public round already started");

        // Verify the merkle proof
        bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, capAmount))));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Invalid proof");
        require(wlCommitments[msg.sender] + msg.value <= capAmount, "Individual cap reached");

        uint256 tokenAmount = msg.value * wlRate;

        require(totalTokensSold + tokenAmount <= tokensToSell, "Global cap reached");

        claimableAmounts[msg.sender] += tokenAmount;
        wlCommitments[msg.sender] += msg.value;
        totalTokensSold += tokenAmount;
        reservedTokens += ((tokenAmount * (100 + maxBonusPercentage)) / 100);
    }

    function commitPublic() external payable nonReentrant {
        require(publicRoundStarted, "Not started yet");
        require(!finished, "Already finished");

        uint256 tokenAmount = msg.value * publicRate;
        require(totalTokensSold + tokenAmount <= tokensToSell, "Global cap reached");
        claimableAmounts[msg.sender] += tokenAmount;
        totalTokensSold += tokenAmount;
        reservedTokens += ((tokenAmount * (100 + maxBonusPercentage)) / 100);
    }

    function claim() external nonReentrant {
        require(finished, "Not finished yet");
        require(claimableAmounts[msg.sender] > 0, "Nothing to claim");

        uint256 amt = claimableAmounts[msg.sender];
        claimableAmounts[msg.sender] = 0;
        _safeTransfer(address(salesToken), msg.sender, amt);

        // decrease the amount of reserved tokens
        reservedTokens -= (amt + amt * maxBonusPercentage / 100);
    }

    function claimAndLock(uint lockDuration) external nonReentrant {
        require(finished, "Not finished yet");
        require(claimableAmounts[msg.sender] > 0, "Nothing to claim");

        // round lock duration to weeks
        lockDuration = lockDuration / WEEK * WEEK;

        require(lockDuration >= MIN_LOCK_TIME, "Lock duration too short");
        require(lockDuration <= MAX_LOCK_TIME, "Lock duration too long");

        uint256 amt = claimableAmounts[msg.sender];
        claimableAmounts[msg.sender] = 0;
        ve.create_lock_for(amt, lockDuration, msg.sender);

        // calculate bonus: if you lock for 1 year, you get max bonus. bonus is proportional to lock duration
        uint256 maxBonus = amt * maxBonusPercentage / 100;
        uint256 bonus = maxBonus * lockDuration / MAX_LOCK_TIME;
        _safeTransfer(address(salesToken), msg.sender, bonus);

        // decrease the amount of reserved tokens
        reservedTokens -= (amt + maxBonus);
    }

    receive() external payable {}

    function emergencyWithdrawETH() external onlyOwner {
        uint256 remainingETH = address(this).balance;
        msg.sender.call{value: remainingETH}("");
    }

    function emergencyWithdrawTokens() external onlyOwner {
        uint256 allTokens = salesToken.balanceOf(address(this));
        _safeTransfer(address(salesToken), msg.sender, allTokens);
    }

    // use this to withdraw unsold tokens from the contract after sale is finished
    function withdrawUnsoldTokens() external onlyOwner {
        require(finished, "Not finished yet");
        uint256 remainingTokens = salesToken.balanceOf(address(this)) - reservedTokens;
        _safeTransfer(address(salesToken), msg.sender, remainingTokens);
    }

    // View functions

    function getClaimableAmount(address _user) external view returns (uint256) {
        return claimableAmounts[_user];
    }

    function getWlCommitment(address _user) external view returns (uint256) {
        return wlCommitments[_user];
    }
    
    // Helper functions

    function _safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}
