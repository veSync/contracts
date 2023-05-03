pragma solidity 0.8.13;

import './BaseTest.sol';



contract TokenSaleTest is BaseTest {

    TokenSale sale;
    VotingEscrow ve;
    address user1 = 0x2D66cdD2F86548AaA2B37D7FFbd6aCE28f4D71c4; // WL cap 0.25E
    address user2 = 0xaAA8267C8675Cd632688E726622099D1959797D0; // WL cap 0.25E
    address user3 = 0xF8b3bE51C7D4d1B572b069b182FAE38E04322d6d; // WL cap 0.5E

    event Deposit(
        address indexed provider,
        uint tokenId,
        uint value,
        uint indexed locktime,
        DepositType deposit_type,
        uint ts
    );

    event Transfer(address indexed from, address indexed to, uint value);

    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME,
        MERGE_TYPE,
        SPLIT_TYPE
    }

    function setUp() public {
        deployCoins();
        address[] memory owners = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        owners[0] = address(this);
        amounts[0] = 39000e18;
        mintVelo(owners, amounts);
        
        VeArtProxy artProxy = new VeArtProxy();
        ve = new VotingEscrow(address(VELO), address(artProxy));

        // rate 1E = 20000 Token
        // cap 30000 Token (1.5 E)
        sale = new TokenSale(20000 * 1e6, 30000e18, block.timestamp + 1 weeks);

        // merkle root is generated in example_proof.json
        sale.setMerkleRoot(0x8d8edd611c4eda08c1a22a6a9b6c3eadc6e4d2e5c7a475268b5be06aaa269de1);

        // mock ether balance
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 2 ether);
    }

    function testNoBonus() public {
        // test: status is correct
        assertEq(sale.getStatus(), 0);

        sale.start();

        // test: status is correct
        assertEq(sale.getStatus(), 1);

        // user 1 WL amount = 0.25E
        vm.startPrank(user1);
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = 0x91febd0c2d769895ead0f7873c044f3a367bf2ff9849f6800bc4d2187443cb30;
        proof1[1] = 0xc0fe84ab9aa5f745f7cc7efa9948f35d0a09665a15e62073e466e8841a593c47;
        sale.commitWhitelist{value: 0.1 ether}(0.25e18, proof1);
        sale.commitWhitelist{value: 0.14 ether}(0.25e18, proof1);

        // test: claimable amount is correct
        assertEq(sale.getClaimableAmount(user1), 4800e18);

        // test: individual WL cap reached
        vm.expectRevert("Individual cap reached");
        sale.commitWhitelist{value: 0.02 ether}(0.25e18, proof1);
        
        // fill up the rest of WL cap
        sale.commitWhitelist{value: 0.01 ether}(0.25e18, proof1);

        // test: claimable amount is correct
        assertEq(sale.getClaimableAmount(user1), 5000e18);

        vm.stopPrank();

        // user 2 WL amount = 0.25E, commit amount = 0.1E
        vm.startPrank(user2);
        bytes32[] memory proof2 = new bytes32[](2);
        proof2[0] = 0x7ea9b5357dd8c851ccc7bbd872f3a8f62b9725cf3da0e8431afe31d6544a73e1;
        proof2[1] = 0xc0fe84ab9aa5f745f7cc7efa9948f35d0a09665a15e62073e466e8841a593c47;
        sale.commitWhitelist{value: 0.1 ether}(0.25e18, proof2);

        // test: claimable amount is correct
        assertEq(sale.getClaimableAmount(user2), 2000e18);
        vm.stopPrank();

        // test: user 3 uses invalid merkle proof
        vm.startPrank(user3);
        vm.expectRevert("Invalid proof");
        sale.commitWhitelist{value: 0.25 ether}(0.25e18, proof2);
        vm.stopPrank();

        sale.startPublicRound();

        // test: status is correct
        assertEq(sale.getStatus(), 2);

        vm.startPrank(user3);
        // test: commitWhitelist should revert
        vm.expectRevert("Not whitelist round");
        sale.commitWhitelist{value: 0.25 ether}(0.25e18, proof2);

        // test: user 3 commits public round
        sale.commitPublic{value: 0.8 ether}();
        assertEq(sale.getClaimableAmount(user3), 16000e18);

        // test: till now, users have committed 1.15E in total == 23000 Token
        assertEq(sale.totalTokensSold(), 23000e18);
        assertEq(sale.getUnsoldTokens(), 7000e18);

        // test: cannot commit 0.8 eth again
        vm.expectRevert("Global cap reached");
        sale.commitPublic{value: 0.8 ether}();

        // test: cannot claim before end
        vm.expectRevert("Cannot claim yet");
        sale.claimAndLock(0, 0);
        vm.stopPrank();

        // owner calls finish
        uint256 balanceBefore = address(this).balance;
        sale.finish();
        uint256 balanceAfter = address(this).balance;

        // test: ETH is transferred to owner
        assertEq(balanceAfter - balanceBefore, 1.15 ether);
        
        // test: status is correct
        assertEq(sale.getStatus(), 3);

        // test: still cannot claim before "enableClaim"
        vm.expectRevert("Cannot claim yet");
        sale.claimAndLock(0, 0);
        vm.stopPrank();

        vm.expectRevert("Token not set");
        sale.enableClaim();

        VELO.approve(address(sale), 39000e18); // approve extra 30% bonus
        sale.setSaleTokenAndVe(IERC20(address(VELO)), IVotingEscrow(address(ve)));

        sale.enableClaim();
        
        // test: status is correct
        assertEq(sale.getStatus(), 4);

        // test: user1 claims
        vm.prank(user1);
        sale.claimAndLock(0, 0);
        assertEq(VELO.balanceOf(user1), 5000e18);

        // test: user2 claims
        vm.prank(user2);
        sale.claimAndLock(0, 0);
        assertEq(VELO.balanceOf(user2), 2000e18);

        // test: user3 claims
        vm.startPrank(user3);
        sale.claimAndLock(0, 0);
        assertEq(VELO.balanceOf(user3), 16000e18);

        // test: cannot claim twice
        vm.expectRevert("Nothing to claim");
        sale.claimAndLock(0, 0);
        vm.stopPrank();

        balanceBefore = VELO.balanceOf(address(this));
        sale.withdrawRemainingTokens();
        balanceAfter = VELO.balanceOf(address(this));

        // test: 30% bonus tokens are returned because no one got bonus 
        assertEq(balanceAfter - balanceBefore, 30000e18 * 30 / 100 + sale.getUnsoldTokens());

        // test: totalTokensSold is correct
        assertEq(sale.totalTokensSold(), 23000e18);
    }

    function testBonus() public {
        sale.start();

        // user 1 WL amount = 0.25E
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = 0x91febd0c2d769895ead0f7873c044f3a367bf2ff9849f6800bc4d2187443cb30;
        proof1[1] = 0xc0fe84ab9aa5f745f7cc7efa9948f35d0a09665a15e62073e466e8841a593c47;
        vm.prank(user1);
        sale.commitWhitelist{value: 0.25 ether}(0.25e18, proof1);

        // test: claimable amount is correct
        assertEq(sale.getClaimableAmount(user1), 5000e18);

        sale.startPublicRound();

        // user 2 commits public round
        vm.prank(user2);
        sale.commitPublic{value: 1 ether}();
        assertEq(sale.getClaimableAmount(user2), 20000e18);

        // owner calls finish and enable claim
        uint256 balanceBefore = address(this).balance;
        sale.finish();
        uint256 balanceAfter = address(this).balance;

        vm.expectRevert("Token not set");
        sale.enableClaim();

        VELO.approve(address(sale), 39000e18); // approve extra 30% bonus
        sale.setSaleTokenAndVe(IERC20(address(VELO)), IVotingEscrow(address(ve)));

        sale.enableClaim();

        // test: ETH is transferred to owner
        assertEq(balanceAfter - balanceBefore, 1.25 ether);

        // user1 claims and locks 40% (2000e18) for 1 year (12 months)
        vm.prank(user1);

  

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(sale), address(ve),  2600e18);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(sale), address(user1),  3000e18);
        sale.claimAndLock(2000e18, 12);

        // test: user1 will have 3000 unlocked, and 1 veNFT
        assertEq(VELO.balanceOf(user1), 3000e18);
        assertEq(ve.ownerOf(1), address(user1));
        assertEq(ve.balanceOf(address(user1)), 1);

        // test: owner can claim remaining
        balanceBefore = VELO.balanceOf(address(this));
        sale.withdrawRemainingTokens();
        balanceAfter = VELO.balanceOf(address(this));
        uint expectedReturned = 39000e18 - 20000e18 * 130 / 100 - 3000e18 - 2000e18 * 130 / 100; // (2000e18 * 30 / 100 is the bonus but in veVS)
        assertEq(balanceAfter - balanceBefore, expectedReturned);

        // user2 claims and locks 100% for 4 months
        vm.startPrank(user2);

        // test: cannot lock anything other than 1/2/4/8/12 months
        vm.expectRevert("Must lock 1/2/4/8/12 months");
        sale.claimAndLock(20000e18, 13);
        vm.expectRevert("Must lock 1/2/4/8/12 months");
        sale.claimAndLock(20000e18, 9);
        vm.expectRevert("Must lock 1/2/4/8/12 months");
        sale.claimAndLock(20000e18, 3);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(sale), address(ve), 23600e18);

        // lock 4 months
        sale.claimAndLock(20000e18, 4);

        // test: 18% liquid token bonus, and 1 veNFT
        assertEq(VELO.balanceOf(user2), 0);
        assertEq(ve.ownerOf(2), address(user2));
        assertEq(ve.balanceOf(address(user2)), 1);

        // test: cannot claim and lock twice
        vm.expectRevert("Nothing to claim");
        sale.claimAndLock(20000e18, 4);
        vm.stopPrank();

        balanceBefore = VELO.balanceOf(address(this));
        sale.withdrawRemainingTokens();
        balanceAfter = VELO.balanceOf(address(this));

        // test: owner can claim remaining unallocated bonus
        expectedReturned = 20000e18 * 12 / 100;
        assertEq(balanceAfter - balanceBefore, expectedReturned);

        // test: totalTokensSold is correct
        assertEq(sale.totalTokensSold(), 25000e18);
    }


    function testBonusEnds() public {
        sale.start();

        // user 1 WL amount = 0.25E
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = 0x91febd0c2d769895ead0f7873c044f3a367bf2ff9849f6800bc4d2187443cb30;
        proof1[1] = 0xc0fe84ab9aa5f745f7cc7efa9948f35d0a09665a15e62073e466e8841a593c47;
        vm.prank(user1);
        sale.commitWhitelist{value: 0.25 ether}(0.25e18, proof1);

        // test: claimable amount is correct
        assertEq(sale.getClaimableAmount(user1), 5000e18);

        sale.startPublicRound();

        // user 2 commits public round
        vm.prank(user2);
        sale.commitPublic{value: 1 ether}();
        assertEq(sale.getClaimableAmount(user2), 20000e18);

        // owner calls finish and enable claim
        uint256 balanceBefore = address(this).balance;
        sale.finish();
        uint256 balanceAfter = address(this).balance;

        vm.expectRevert("Token not set");
        sale.enableClaim();

        VELO.approve(address(sale), 39000e18); // approve extra 30% bonus
        sale.setSaleTokenAndVe(IERC20(address(VELO)), IVotingEscrow(address(ve)));

        sale.enableClaim();

        // test: ETH is transferred to owner
        assertEq(balanceAfter - balanceBefore, 1.25 ether);

        // user1 claims and locks 40% (2000e18) for 1 year (12 months)
        vm.prank(user1);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(sale), address(ve), 2600e18);

        sale.claimAndLock(2000e18, 12);

        // test: user1 will have 3000 unlocked, and 1 veNFT
        assertEq(VELO.balanceOf(user1), 3000e18);
        assertEq(ve.ownerOf(1), address(user1));
        assertEq(ve.balanceOf(address(user1)), 1);

        // test: owner can claim remaining
        balanceBefore = VELO.balanceOf(address(this));
        sale.withdrawRemainingTokens();
        balanceAfter = VELO.balanceOf(address(this));
        uint expectedReturned = 39000e18 - 20000e18 * 130 / 100 - 3000e18 - 2000e18 * 130 / 100; // (2000e18 * 30 / 100 is the bonus but in veVS)
        assertEq(balanceAfter - balanceBefore, expectedReturned);

        vm.warp(block.timestamp + 1 weeks);
        // user2 claims and locks 100% for 4 months
        vm.startPrank(user2);

        // after bonusEndTime

        // no bonus
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(sale), address(ve),  20000e18);

        // lock 4 months
        sale.claimAndLock(20000e18, 4);

        vm.stopPrank();

        // test: 18% liquid token bonus, and 1 veNFT
        assertEq(VELO.balanceOf(user2), 0);
        assertEq(ve.ownerOf(2), address(user2));
        assertEq(ve.balanceOf(address(user2)), 1);


        balanceBefore = VELO.balanceOf(address(this));
        sale.withdrawRemainingTokens();
        balanceAfter = VELO.balanceOf(address(this));

        // test: owner can claim remaining unallocated bonus
        expectedReturned = 20000e18 * 12 / 100 + 20000e18 * 18 / 100;
        assertEq(balanceAfter - balanceBefore, expectedReturned);

        // test: totalTokensSold is correct
        assertEq(sale.totalTokensSold(), 25000e18);
    }
}