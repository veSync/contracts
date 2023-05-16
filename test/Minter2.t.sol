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
    address gaugeAddress;
    Gauge gauge;

    function deployBase() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        vm.warp(block.timestamp + 20 weeks); // put some initial time in

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

        gaugeAddress = voter.gauges(address(pair));
        gauge = Gauge(gaugeAddress);

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


        assertEq(minter.earlyGrowthParams(1), growthParams[1], 'growth param set failed');

        
        minter.start();

        address teamAddress = address(owner2);
        minter.setTeam(teamAddress);
        
        vm.expectRevert(abi.encodePacked("not pending team"));
        minter.acceptTeam();

        vm.startPrank(address(owner2));
        minter.acceptTeam();
        vm.stopPrank();

        uint teamBalanceBefore;
        uint teamBalanceAfter;

        minter.update_period();
        minter.update_period();

        // cannot update at the start time
        console.log("block timestamp");
        console.log(block.timestamp);
        assertEq(minter.current_epoch_num(), 0);

        assertEq(distributor.last_token_time(), distributor.start_time(), 'token should not distribute');
        assertEq(VSTOKEN.balanceOf(address(distributor)), 0);
        assertEq(distributor.claimable(1), 0);
        assertEq(VSTOKEN.balanceOf(address(voter)), 0);
        assertEq(VSTOKEN.balanceOf(teamAddress), 0);


        // cannot update at the first epoch
        vm.warp(block.timestamp + 1 days);
        assertEq(minter.current_epoch_num(), 0);

        minter.update_period();
        // no token distribute
        assertEq(distributor.last_token_time(), distributor.start_time(), 'token should not distribute');
        assertEq(VSTOKEN.balanceOf(address(distributor)), 0, 'no token distribute');
        assertEq(distributor.claimable(1), 0);
        assertEq(VSTOKEN.balanceOf(address(voter)), 0);
        assertEq(VSTOKEN.balanceOf(teamAddress), 0);


        // can update at the epoch 1, the first epoch distribting tokens
        vm.warp(block.timestamp + 6 days);
        assertEq(minter.current_epoch_num(), 1);
        assertEq(minter.weekly(), 4 * TOKEN_1M, "emission correct");

        // owner3 vote at epoch 1
        VSTOKEN.transfer(address(owner3), TOKEN_100K);
        vm.startPrank(address(owner3));
        VSTOKEN.approve(address(escrow), TOKEN_100K);
        escrow.create_lock(TOKEN_100K, 365 * 86400);
        vm.stopPrank();

        uint updatedWeekly = minter.weekly() * 9850/10000;
        minter.update_period();

        assertEq(distributor.last_token_time(), block.timestamp, 'token distribute');
        uint growth = 736512821764926259294157;
        assertEq(VSTOKEN.balanceOf(address(distributor)), growth, 'rebasing amount correct');
        assertEq(VSTOKEN.balanceOf(address(voter)), updatedWeekly, 'voter emission correct');
        assertEq(VSTOKEN.balanceOf(teamAddress), (100 * (growth + updatedWeekly)) /
                (10000 - 100), 'team emission correct');

        assertEq(distributor.claimable(1), 0, 'cannot claim yet, must wait a full epoch');


        // next epoch (epoch 2, the second epoch distribting tokens, and votes at the epoch 0 can claim)
        vm.warp(block.timestamp + 7 days);
        assertEq(minter.current_epoch_num(), 2);
        assertEq(minter.weekly(), 4 * TOKEN_1M * 9850/10000, "emission correct");

        
        minter.update_period();
        assertEq(distributor.claimable(1), 2004813888577500549002, "votes at two epochs ago can claim now");
        assertEq(distributor.claimable(2), 0, 'cannot claim yet for votes at last epoch, must wait a full epoch');

        assertEq(VSTOKEN.balanceOf(address(distributor)), 738516421189210500056416);

        // must wait for a full epoch
        vm.warp(block.timestamp + 6 days);
        assertEq(minter.current_epoch_num(), 2);
        minter.update_period();
        assertEq(distributor.claimable(2), 0, 'cannot claim yet, must wait a full epoch');


        // next epoch (epoch 3, the third epoch distribting tokens, and votes at the epoch 1 can claim)
        vm.warp(block.timestamp + 1 days);

        updatedWeekly = minter.weekly() * 9850/10000;

        uint distributorBalanceBefore = VSTOKEN.balanceOf(address(distributor));
        uint voteBalanceBefore = VSTOKEN.balanceOf(address(voter));
        uint teamAddressBalanceBefore = VSTOKEN.balanceOf(teamAddress);

        console.log('ve', escrow.totalSupply());
        console.log('vs', VSTOKEN.totalSupply());
        console.log('emission', updatedWeekly);

        minter.update_period();

        uint distributorBalanceAfter = VSTOKEN.balanceOf(address(distributor));
        uint voteBalanceAfter = VSTOKEN.balanceOf(address(voter));
        uint teamAddressBalanceAfter = VSTOKEN.balanceOf(teamAddress);

        assertEq(minter.current_epoch_num(), 3);
        
        assertEq(distributor.claimable(1), 2131708420791023633322, 'can claim after a full epoch');
        assertEq(distributor.claimable(2), 129432422857793546006, 'can claim after a full epoch');


        growth = 256324066057827499353;
        assertEq(distributorBalanceAfter - distributorBalanceBefore, growth, 'rebasing amount correct');
        assertEq(voteBalanceAfter - voteBalanceBefore, updatedWeekly, 'voter emission correct');
        assertEq(teamAddressBalanceAfter - teamAddressBalanceBefore, (100 * (growth + updatedWeekly)) /
                (10000 - 100), 'team emission correct');


        
        // epoch 4
        vm.warp(block.timestamp + 1 weeks);
        assertEq(minter.current_epoch_num(), 4);
        // override

        vm.expectRevert(abi.encodePacked("not team"));
        minter.setOverrideGrowthParam(1000000);

        vm.startPrank(address(owner2));
        minter.setOverrideGrowthParam(1000000);
        vm.stopPrank();

        distributorBalanceBefore = VSTOKEN.balanceOf(address(distributor));
        voteBalanceBefore = VSTOKEN.balanceOf(address(voter));
        teamAddressBalanceBefore = VSTOKEN.balanceOf(teamAddress);

        updatedWeekly = minter.weekly() * 9850/10000;

        console.log('ve', escrow.totalSupply());
        console.log('vs', VSTOKEN.totalSupply());
        console.log('emission', updatedWeekly);

        minter.update_period();

        distributorBalanceAfter = VSTOKEN.balanceOf(address(distributor));
        voteBalanceAfter = VSTOKEN.balanceOf(address(voter));
        teamAddressBalanceAfter = VSTOKEN.balanceOf(teamAddress);

        // growth param changed to 1e6
        growth = 4917983650420152774;
        assertEq(distributorBalanceAfter - distributorBalanceBefore, growth, 'rebasing amount correct');
        assertEq(voteBalanceAfter - voteBalanceBefore, updatedWeekly, 'voter emission correct');
        assertEq(teamAddressBalanceAfter - teamAddressBalanceBefore, (100 * (growth + updatedWeekly)) /
                (10000 - 100), 'team emission correct');

    }
}
