// 1:1 with Hardhat test
pragma solidity 0.8.13;

import "./BaseTest.sol";

contract MinterTeamEmissions is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;
    TestOwner team;

    function setUp() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amountsVS = new uint256[](2);
        amountsVS[0] = 1e25;
        amountsVS[1] = 1e25;
        mintVS(owners, amountsVS);
        team = new TestOwner();
        VeArtProxy artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(VSTOKEN), address(artProxy));
        factory = new PairFactory();
        router = new Router(address(factory), address(owner));
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        voter = new Voter(
            address(escrow),
            address(factory),
            address(gaugeFactory),
            address(bribeFactory)
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(VSTOKEN);
        voter.initialize(tokens, address(owner));
        VSTOKEN.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, 365 * 86400);
        distributor = new RewardsDistributor(address(escrow));
        escrow.setVoter(address(voter));

        minter = new Minter(
            address(voter),
            address(escrow),
            address(distributor)
        );
        distributor.setDepositor(address(minter));
        VSTOKEN.setMinter(address(minter));

        VSTOKEN.approve(address(router), TOKEN_1);
        FRAX.approve(address(router), TOKEN_1);
        router.addLiquidity(
            address(FRAX),
            address(VSTOKEN),
            false,
            TOKEN_1,
            TOKEN_1,
            0,
            0,
            address(owner),
            block.timestamp
        );

        address pair = router.pairFor(address(FRAX), address(VSTOKEN), false);

        VSTOKEN.approve(address(voter), 5 * TOKEN_100K);
        voter.createGauge(pair);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(VSTOKEN.balanceOf(address(escrow)), TOKEN_1);

        address[] memory pools = new address[](1);
        pools[0] = pair;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(1, pools, weights);

        address[] memory claimants = new address[](2);
        claimants[0] = address(owner3);
        claimants[1] = address(owner2);
        uint256[] memory amountsToMint = new uint256[](2);
        amountsToMint[0] = TOKEN_1M;
        amountsToMint[1] = TOKEN_100M;
        vm.expectRevert(abi.encodePacked("not initializeToken"));
        minter.start();

        uint256 before2 = VSTOKEN.balanceOf(address(owner2));
        minter.initializeToken(claimants, amountsToMint);

        vm.expectRevert(abi.encodePacked("no growthParam"));
        minter.start();

        minter.setOverrideGrowthParam(1000000);
        minter.start();

        uint256 before = VSTOKEN.balanceOf(address(owner3));
        assertEq(before, TOKEN_1M);

        uint256 after2 = VSTOKEN.balanceOf(address(owner2));
        assertEq(after2 - before2, TOKEN_100M, "owner2 allocation");

        // update has no effect when the first epoch has not ended
        minter.update_period(); // initial period week 1
        uint256 after_ = VSTOKEN.balanceOf(address(owner3));
        assertEq(minter.weekly(), 4 * TOKEN_1M);
        assertEq(after_ - before, 0);

        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);

        before = VSTOKEN.balanceOf(address(owner3));
         console.log("test2");
        minter.update_period(); // initial period week 2
         console.log("test3");
        after_ = VSTOKEN.balanceOf(address(owner3));
        assertEq(minter.weekly(), 4 * TOKEN_1M * 9850/10000);
        assertEq(after_ - before, 0); // not escrow yet
    }

    function testChangeTeam() public {
        // check that initial team is set to owner
        assertEq(minter.team(), address(owner));
        owner.setTeam(address(minter), address(owner2));
        owner2.acceptTeam(address(minter));

        assertEq(minter.team(), address(owner2));

        // expect revert from owner3 setting team
        vm.expectRevert(abi.encodePacked("not team"));
        owner3.setTeam(address(minter), address(owner));

        // expect revert from owner3 accepting team
        vm.expectRevert(abi.encodePacked("not pending team"));
        owner3.acceptTeam(address(minter));
    }

    function testTeamEmissionsRate() public {
        owner.setTeam(address(minter), address(team));
        team.acceptTeam(address(minter));

        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        uint256 beforeTeamSupply = VSTOKEN.balanceOf(address(team));
        uint256 weekly = minter.weekly_emission();
        uint256 growth = minter.calculate_growth(weekly, 0);
        minter.update_period(); // new period
        uint256 afterTeamSupply = VSTOKEN.balanceOf(address(team));
        uint256 newTeamVS = afterTeamSupply - beforeTeamSupply;
        assertEq(((weekly + growth + newTeamVS) * 100) / 10000, newTeamVS); // check 1% of new emissions to team

        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        beforeTeamSupply = VSTOKEN.balanceOf(address(team));
        weekly = minter.weekly_emission();
        growth = minter.calculate_growth(weekly, 0);
        minter.update_period(); // new period
        afterTeamSupply = VSTOKEN.balanceOf(address(team));
        newTeamVS = afterTeamSupply - beforeTeamSupply;
        assertEq(((weekly + growth + newTeamVS) * 100) / 10000, newTeamVS); // check 1% of new emissions to team

        // rate is right even when VSTOKEN is sent to Minter contract
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        owner2.transfer(address(VSTOKEN), address(minter), 1e25);
        beforeTeamSupply = VSTOKEN.balanceOf(address(team));
        weekly = minter.weekly_emission();
        growth = minter.calculate_growth(weekly, 0);
        minter.update_period(); // new period
        afterTeamSupply = VSTOKEN.balanceOf(address(team));
        newTeamVS = afterTeamSupply - beforeTeamSupply;
        assertEq(((weekly + growth + newTeamVS) * 100) / 10000, newTeamVS); // check 1% of new emissions to team
    }

    function testChangeTeamEmissionsRate() public {
        owner.setTeam(address(minter), address(team));
        team.acceptTeam(address(minter));

        // expect revert from owner3 setting team
        vm.expectRevert(abi.encodePacked("not team"));
        owner3.setTeamEmissions(address(minter), 500);

        // expect revert for out-of-bounds rate
        vm.expectRevert(abi.encodePacked("rate too high"));
        team.setTeamEmissions(address(minter), 600);

        // new rate in bounds
        team.setTeamEmissions(address(minter), 500);

        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        uint256 beforeTeamSupply = VSTOKEN.balanceOf(address(team));
        uint256 weekly = minter.weekly_emission();
        uint256 growth = minter.calculate_growth(weekly, 0);
        minter.update_period(); // new period
        uint256 afterTeamSupply = VSTOKEN.balanceOf(address(team));
        uint256 newTeamVS = afterTeamSupply - beforeTeamSupply;
        assertEq(((weekly + growth + newTeamVS) * 500) / 10000, newTeamVS); // check 5% of new emissions to team
    }
}
