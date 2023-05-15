// 1:1 with Hardhat test
pragma solidity 0.8.13;

import './BaseTest.sol';

contract MinterTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;

    function deployBase() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e24;
        mintVS(owners, amounts);

        VeArtProxy artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(VSTOKEN), address(artProxy));
        factory = new PairFactory();
        router = new Router(address(factory), address(owner));
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        voter = new Voter(address(escrow), address(factory), address(gaugeFactory), address(bribeFactory));

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(VSTOKEN);
        voter.initialize(tokens, address(owner));
        VSTOKEN.approve(address(escrow), TOKEN_100K);
        escrow.create_lock(TOKEN_100K, 365 * 86400);
        distributor = new RewardsDistributor(address(escrow));
        escrow.setVoter(address(voter));

        minter = new Minter(address(voter), address(escrow), address(distributor));

        distributor.setDepositor(address(minter));
        VSTOKEN.setMinter(address(minter));

        VSTOKEN.approve(address(router), TOKEN_1);
        FRAX.approve(address(router), TOKEN_1);
        router.addLiquidity(address(FRAX), address(VSTOKEN), false, TOKEN_1, TOKEN_1, 0, 0, address(owner), block.timestamp);

        address pair = router.pairFor(address(FRAX), address(VSTOKEN), false);

        VSTOKEN.approve(address(voter), 5 * TOKEN_100K);
        voter.createGauge(pair);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(VSTOKEN.balanceOf(address(escrow)), TOKEN_100K);

        address[] memory pools = new address[](1);
        pools[0] = pair;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(1, pools, weights);
    }

    function initializeVotingEscrow() public {
        deployBase();



        // owner has 100M token VS
        address[] memory claimants = new address[](2);
        claimants[0] = address(owner);
        claimants[1] = address(owner2);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = TOKEN_100M;
        amounts[1] = TOKEN_1M;
        
        uint balanceBefore = VSTOKEN.balanceOf(address(owner));
        minter.initializeToken(claimants, amounts);

        vm.expectRevert(abi.encodePacked("no growthParam"));
        minter.start();

    
        minter.setOverrideGrowthParam(1000000);

        minter.start();

        uint balanceAfter = VSTOKEN.balanceOf(address(owner));
        assertEq(escrow.ownerOf(1), address(owner));
        assertEq(escrow.ownerOf(2), address(0));
        assertEq(VSTOKEN.balanceOf(address(minter)), 0);
        assertEq(balanceAfter - balanceBefore, TOKEN_100M);

        // owner creates lock for itself
        VSTOKEN.approve(address(escrow), TOKEN_100M);
        escrow.create_lock(TOKEN_100M, 365 * 86400);

        vm.roll(block.number + 1);
    }
    
    function testMinterPeriodCorrect() public {
        deployBase();
        address[] memory initialClaimants;
        uint256[] memory initialAmounts;
        minter.initializeToken(initialClaimants, initialAmounts);
        
        vm.expectRevert(abi.encodePacked("no growthParam"));
        minter.start();

        uint[] memory growthParams = new uint256[](17);
        growthParams[0] = 0;
        growthParams[1] = 3646943;
        growthParams[2] = 2986691;
        growthParams[3] = 2600468;
        growthParams[4] = 2326439;
        growthParams[5] = 2113885;
        growthParams[6] = 1940216;
        growthParams[7] = 1793381;
        growthParams[8] = 1666187;
        growthParams[9] = 1553994;
        growthParams[10] = 1453633;
        growthParams[11] = 1362846;
        growthParams[12] = 1279964;
        growthParams[13] = 1203720;
        growthParams[14] = 1133129;
        growthParams[15] = 1067411;
        growthParams[16] = 1005935;

        minter.setEarlyGrowthParams(growthParams);

        minter.start();

        assertEq(minter.weekly(), 4 * TOKEN_1M);

        minter.update_period();
        assertEq(minter.weekly(), 4 * TOKEN_1M);

        minter.update_period();
        assertEq(minter.weekly(), 4 * TOKEN_1M);

        assertEq(VSTOKEN.balanceOf(address(distributor)), 0);

        assertEq(distributor.claimable(1), 0);

        console.log(block.timestamp);

        assertEq(minter.current_epoch_num(), 0);

         vm.warp(block.timestamp + 1 days);

        assertEq(minter.current_epoch_num(), 0);

        // next epoch
        vm.warp(block.timestamp + 6 days);

        assertEq(minter.current_epoch_num(), 1);

        assertEq(minter.weekly(), 4 * TOKEN_1M, "emission");

        console.log(VSTOKEN.totalSupply());
        console.log(escrow.totalSupply());
        console.log("test");
        console.log(minter.calculate_growth(4 * TOKEN_1M * 9850/10000, 1));
        console.log("test2");
        console.log(minter.earlyGrowthParams(1));
        assertEq(VSTOKEN.balanceOf(address(distributor)), 0);





        // address[] memory pools = new address[](1);
        // pools[0] = pair;
        // uint256[] memory weights = new uint256[](1);
        // weights[0] = 5000;
        // voter.vote(1, pools, weights);

        console.log(distributor.claimable(1));

        minter.update_period();

        // next epoch
        vm.warp(block.timestamp + 7 days);
        assertEq(minter.current_epoch_num(), 2);

        assertEq(VSTOKEN.balanceOf(address(distributor)), 89408573438455893717131);

    }
}
