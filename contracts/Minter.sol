// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "contracts/libraries/Math.sol";
import "contracts/interfaces/IMinter.sol";
import "contracts/interfaces/IRewardsDistributor.sol";
import "contracts/interfaces/IVS.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IVotingEscrow.sol";

// codifies the minting rules as per ve(3,3), abstracted from the token to support any token that allows minting

contract Minter is IMinter {
    uint internal constant WEEK = 86400 * 7; // allows minting once per week (reset every Thursday 00:00 UTC)
    uint internal constant EMISSION_BPS = 9850;
    uint internal constant TAIL_EMISSION_BPS = 20;
    uint internal constant PRECISION_BPS = 10000;
    uint internal constant MAX_REBASING_RATE = 3000;
    uint internal constant PRECISION_GROWTH = 1000000;
    uint internal constant LOCK = 86400 * 365;
    uint internal constant MAX_TEAM_RATE = 500; // 500 bps = 5%
    uint internal constant OVERRIDE_ALLOWED_DURATION = 4 weeks;
    uint public immutable _launchTime;
    IVS public immutable _vs;
    IVoter public immutable _voter;
    IVotingEscrow public immutable _ve;
    IRewardsDistributor public immutable _rewards_distributor;
    uint public weekly = 4_000_000 * 1e18; // standard weekly emission. the initial value represents a starting weekly emission of 4M VS (VS has 18 decimals)
    uint public weeklyOverride = 0; // we allow admin to override the weekly emission to a lower amount for the first 4 weeks. 0 means no override
    uint public active_period;

    bool public tokenInitialized;
    address public initializer;
    address public team;
    address public pendingTeam;
    uint public teamRate;

    uint[] public earlyGrowthParams; // for early growth param finetune
    uint public overrideGrowthParam; // for long term growth calculation
    uint public startPeriod; // record the start timestamp of the first epoch 

    event Mint(address indexed sender, uint weekly, uint circulating_supply, uint circulating_emission);

    constructor(
        address __voter, // the voting & distribution system
        address __ve, // the ve(3,3) system that will be locked into
        address __rewards_distributor // the distribution system that ensures users aren't diluted
    ) {
        initializer = msg.sender;
        team = msg.sender;
        teamRate = 100; // 100 bps = 1%
        _vs = IVS(IVotingEscrow(__ve).token());
        _voter = IVoter(__voter);
        _ve = IVotingEscrow(__ve);
        _rewards_distributor = IRewardsDistributor(__rewards_distributor);
        _launchTime = block.timestamp;
        active_period = ((block.timestamp + (2 * WEEK)) / WEEK) * WEEK;
    }

    // initialize the minter, distribute initial supply to the targets
    // notice: if you want to airdrop untransferable veNFT to protocols, use `mintFrozen` instead
    function initializeToken(
        address[] memory targets,
        uint[] memory amounts
    ) external {
        require(initializer == msg.sender && !tokenInitialized, "cannot initializeToken");
        _vs.approve(address(_ve), type(uint).max);
        // initialize token
        for (uint i = 0; i < targets.length; i++) {
            _vs.mint(targets[i], amounts[i]);
        }
        tokenInitialized = true;
    }

    function start() external {
        require(initializer == msg.sender && tokenInitialized == true, "not initializeToken");
        require(earlyGrowthParams.length > 0 || overrideGrowthParam > 0, "no growthParam"); 
        active_period = ((block.timestamp) / WEEK) * WEEK; // allow minter.update_period() to mint new emissions on the upcoming Thursday (because 1/1/1970 is a Thursday)
        startPeriod = active_period; // record permanently

        // renounce the initializer
        initializer = address(0);
    }

    function setEarlyGrowthParams(uint[] memory params) external {
        require(msg.sender == team, 'not team');
        earlyGrowthParams = params;
    }

    function setOverrideGrowthParam(uint param) external {
        require(msg.sender == team, 'not team');
        // if overrideGrowthParam is nonzero number, the earlyGrowthParams will be invalidated
        overrideGrowthParam = param;
    }

    function setTeam(address _team) external {
        require(msg.sender == team, "not team");
        pendingTeam = _team;
    }

    function acceptTeam() external {
        require(msg.sender == pendingTeam, "not pending team");
        team = pendingTeam;
    }

    function setTeamRate(uint _teamRate) external {
        require(msg.sender == team, "not team");
        require(_teamRate <= MAX_TEAM_RATE, "rate too high");
        teamRate = _teamRate;
    }

    // set the weekly emission override. this only works for the first 4 weeks
    // if the override is set to 0, the standard weekly emission is used
    function setWeeklyOverride(uint _weeklyOverride) external {
        require(msg.sender == team, "not team");
        require(_weeklyOverride < weekly, "override too high");
        weeklyOverride = _weeklyOverride;
    }

    function mintFrozen(
        address[] memory claimants,
        uint[] memory amounts
    ) external {
        require(msg.sender == team, "not team");
        require(claimants.length == amounts.length, "length mismatch");
        for (uint i = 0; i < claimants.length; i++) {
            _ve.create_lock_and_freeze_for(amounts[i], LOCK, claimants[i]);
        }
    }

    // calculate circulating supply as total token supply - locked supply
    function circulating_supply() public view returns (uint) {
        return _vs.totalSupply() - _ve.totalSupply();
    }

    // emission calculation is 1% of available supply to mint adjusted by circulating / total supply
    function calculate_emission() public view returns (uint) {
        return (weekly * EMISSION_BPS) / PRECISION_BPS;
    }

    // weekly emission takes the max of calculated (aka target) emission versus circulating tail end emission
    function weekly_emission() public view returns (uint) {
        return Math.max(calculate_emission(), circulating_emission());
    }

    // calculates tail end (infinity) emissions as 0.2% of total supply
    function circulating_emission() public view returns (uint) {
        return (circulating_supply() * TAIL_EMISSION_BPS) / PRECISION_BPS;
    }

    // only first 4 weeks can override emission to a lower amount
    function emission_override_enabled() public view returns (bool) {
        return block.timestamp < _launchTime + OVERRIDE_ALLOWED_DURATION && weeklyOverride > 0 && weeklyOverride < weekly;
    }

    // calculate inflation and adjust ve balances accordingly
    // epochNum is the number of epochs since start
    // epochNum = 1 means the first epoch after start
    function calculate_growth(uint _minted, uint epochNum) public view returns (uint) {
        uint _veTotal = _ve.totalSupply();
        uint _vsTotal = _vs.totalSupply();

        uint growthParam;
        if (overrideGrowthParam != 0) {
            growthParam = overrideGrowthParam;
        } else {
            growthParam = earlyGrowthParams[epochNum];
        }
        uint _growth = 
            (((((_minted * growthParam * _veTotal) / _vsTotal) * _veTotal) / _vsTotal) *
                _veTotal) /
            _vsTotal /
            PRECISION_GROWTH /
             2;
        uint _maxGrowth = _minted * (MAX_REBASING_RATE + PRECISION_BPS)/PRECISION_BPS;
        _growth = Math.min(_growth, _maxGrowth);
        return _growth;
    }

    // update period can only be called once per cycle (1 week)
    function update_period() external returns (uint) {
        uint _period = active_period;
        if (block.timestamp >= _period + WEEK && initializer == address(0)) { // only trigger if new week
            _period = (block.timestamp / WEEK) * WEEK;

            uint epochNum = (_period - startPeriod)/WEEK;

            active_period = _period;

            // weekly emission decays by 1% per week, regardless of override
            weekly = weekly_emission();

            uint updatedWeekly = weekly;
            if (emission_override_enabled()) {
                updatedWeekly = weeklyOverride;
            }

            uint _growth = calculate_growth(updatedWeekly, epochNum);
            uint _teamEmissions = (teamRate * (_growth + updatedWeekly)) /
                (PRECISION_BPS - teamRate);
            uint _required = _growth + updatedWeekly + _teamEmissions;
            uint _balanceOf = _vs.balanceOf(address(this));
            if (_balanceOf < _required) {
                _vs.mint(address(this), _required - _balanceOf);
            }

            require(_vs.transfer(team, _teamEmissions));
            require(_vs.transfer(address(_rewards_distributor), _growth));
            _rewards_distributor.checkpoint_token(); // checkpoint token balance that was just minted in rewards distributor
            _rewards_distributor.checkpoint_total_supply(); // checkpoint supply

            _vs.approve(address(_voter), updatedWeekly);
            _voter.notifyRewardAmount(updatedWeekly);

            emit Mint(msg.sender, updatedWeekly, circulating_supply(), circulating_emission());
        }
        return _period;
    }
}
