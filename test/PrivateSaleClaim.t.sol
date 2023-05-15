pragma solidity 0.8.13;

import './BaseTest.sol';

contract PrivateSaleClaimTest is BaseTest {
    PrivateSaleClaim sale;
    VotingEscrow ve;
    address user1 = 0x2D66cdD2F86548AaA2B37D7FFbd6aCE28f4D71c4; // 25 tokens
    address user2 = 0xaAA8267C8675Cd632688E726622099D1959797D0; // 25 tokens
    address user3 = 0xF8b3bE51C7D4d1B572b069b182FAE38E04322d6d; // 50 tokens

    function setUp() public {
        deployCoins();
        address[] memory owners = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        owners[0] = address(this);
        amounts[0] = 124e18;
        mintVS(owners, amounts);
        
        VeArtProxy artProxy = new VeArtProxy();
        ve = new VotingEscrow(address(VSTOKEN), address(artProxy));

        sale = new PrivateSaleClaim(block.timestamp + 1 weeks);

        // merkle root is generated in example_private_sale_proof.json
        sale.setMerkleRoot(0xf9d59fc24e357336569d3130051a070f74d06a49040a900f8b56db0ee6955d29);

        VSTOKEN.approve(address(sale), 1000e18);
        sale.setSaleTokenAndVe(IERC20(address(VSTOKEN)), IVotingEscrow(address(ve)), 100e18); // total 100 tokens
    }

    function testPrivateSaleNoBonus() public {
        // user 1 amount = 25e18
        vm.startPrank(user1);
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = 0x2a89c1c4f5c86150b5979a4d60f039847d864b34df289d5ca3ea3c489780ca93;
        proof1[1] = 0x4d992d07b92b7b37155edda1e50d14a3f51b6a7f5e05d3fc7d5735cd5c4780de;

        // test: user1 claims
        sale.claimAndLock(25e18, proof1, 0, 0);
        assertEq(VSTOKEN.balanceOf(user1), 25e18 * 80 / 100);
        
        assertEq(ve.ownerOf(1), address(user1));
        assertEq(ve.balanceOf(address(user1)), 1);

        // test: cannot claim twice
        vm.expectRevert("Nothing to claim");
        sale.claimAndLock(25e18, proof1, 0, 0);
        vm.stopPrank();

        uint balanceBefore = VSTOKEN.balanceOf(address(this));
        sale.withdrawRemainingTokens();
        uint balanceAfter = VSTOKEN.balanceOf(address(this));

        // test: 30% bonus tokens are returned because no one got bonus 
        assertEq(balanceAfter - balanceBefore, 25e18 * 80 / 100 * 30 / 100);
    }

    function testPrivateSaleWithBonus() public {
        // user 1 amount = 25e18
        vm.startPrank(user1);
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = 0x2a89c1c4f5c86150b5979a4d60f039847d864b34df289d5ca3ea3c489780ca93;
        proof1[1] = 0x4d992d07b92b7b37155edda1e50d14a3f51b6a7f5e05d3fc7d5735cd5c4780de;

        // test: user1 claims
        sale.claimAndLock(25e18, proof1, 25e18 * 80 / 100, 12);
        assertEq(VSTOKEN.balanceOf(user1), 0);
        
        assertEq(ve.ownerOf(1), address(user1));
        assertEq(ve.ownerOf(2), address(user1));
        assertEq(ve.balanceOf(address(user1)), 2);

        vm.stopPrank();

        uint balanceBefore = VSTOKEN.balanceOf(address(this));
        sale.withdrawRemainingTokens();
        uint balanceAfter = VSTOKEN.balanceOf(address(this));

        // all bonus are distributed, therefore none claimable by owner
        assertEq(balanceAfter - balanceBefore, 0);
    }
}