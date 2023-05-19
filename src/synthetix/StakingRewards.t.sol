// SPDX-FileCopyrightText: © 2019-2021 Synthetix
// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: MIT AND AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {StakingRewards} from "./StakingRewards.sol";

contract StakingRewardsTest is Test {
    uint256 constant WAD = 10 ** 18;

    TestToken rewardGem;
    TestToken gem;
    StakingRewards farm;

    function setupReward(uint256 amt) internal {
        rewardGem.mint(amt);
        rewardGem.transfer(address(farm), amt);
        farm.notifyRewardAmount(amt);
    }

    function setupStakingToken(uint256 amt) internal {
        gem.mint(amt);
        gem.approve(address(farm), amt);
    }

    function setUp() public {
        rewardGem = new TestToken("SubDaoT", 18);
        gem = new TestToken("MKR", 18);

        farm = new StakingRewards(address(this), address(this), address(rewardGem), address(gem));
    }

    function testConstructor() public {
        StakingRewards f = new StakingRewards(address(this), address(this), address(rewardGem), address(gem));

        assertEq(address(f.rewardsToken()), address(rewardGem));
        assertEq(address(f.stakingToken()), address(gem));
        assertEq(f.rewardsDistribution(), address(this));
    }

    function testSetRewardsDistribution() public {
        farm.setRewardsDistribution(address(0));
        assertEq(farm.rewardsDistribution(), address(0));
    }

    function testSetRewardsDistributionEvent() public {
        vm.expectEmit(false, false, false, true, address(farm));
        emit RewardsDistributionUpdated(address(0));

        farm.setRewardsDistribution(address(0));
    }

    function testRevertOnUnauthorizedMethods() public {
        vm.startPrank(address(0));

        vm.expectRevert("Only the contract owner may perform this action");
        farm.setRewardsDistribution(address(0));

        vm.expectRevert("Only the contract owner may perform this action");
        farm.setRewardsDuration(1 days);

        vm.expectRevert("Only the contract owner may perform this action");
        farm.setPaused(true);

        vm.expectRevert("Only the contract owner may perform this action");
        farm.recoverERC20(address(0), 1);

        vm.expectRevert("Caller is not RewardsDistribution contract");
        farm.notifyRewardAmount(1);
    }

    function testRevertStakeWhenPaused() public {
        farm.setPaused(true);

        vm.expectRevert("This action cannot be performed while the contract is paused");
        farm.stake(1);
    }

    function testPauseUnpause() public {
        farm.setPaused(true);

        vm.expectRevert("This action cannot be performed while the contract is paused");
        farm.stake(1);

        farm.setPaused(false);

        setupStakingToken(1);
        farm.stake(1);
    }

    function testRevertOnRecoverStakingToken() public {
        vm.expectRevert("Cannot withdraw the staking token");
        farm.recoverERC20(address(gem), 1);
    }

    function testRecoverERC20() public {
        TestToken t = new TestToken("TT", 18);
        t.mint(10);
        t.transfer(address(farm), 10);

        assertEq(t.balanceOf(address(farm)), 10);

        vm.expectEmit(true, true, true, true);
        emit Recovered(address(t), 10);

        farm.recoverERC20(address(t), 10);

        assertEq(t.balanceOf(address(farm)), 0);
        assertEq(t.balanceOf(address(this)), 10);
    }

    function testLastTimeRewardApplicable() public {
        assertEq(farm.lastTimeRewardApplicable(), 0);

        setupReward(10 * WAD);

        assertEq(farm.lastTimeRewardApplicable(), block.timestamp);
    }

    function testRewardPerToken() public {
        assertEq(farm.rewardPerToken(), 0);

        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        assertEq(farm.totalSupply(), 100 * WAD);

        setupReward(5000 * WAD);

        skip(1 days);

        assert(farm.rewardPerToken() > 0);
    }

    function testStakeEmitEvent() public {
        setupStakingToken(100 * WAD);

        vm.expectEmit(false, false, false, true, address(farm));
        emit Staked(address(this), 100 * WAD);
        farm.stake(100 * WAD);
    }

    function testStakeWithReferralEmitEvent() public {
        uint16 referralCode = 1;

        setupStakingToken(100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Staked(address(this), 100 * WAD);
        vm.expectEmit(true, false, false, false);
        emit Referral(1, address(this), 100 * WAD);

        farm.stake(100 * WAD, referralCode);
    }

    function testStaking() public {
        setupStakingToken(100 * WAD);

        uint256 gemBalance = gem.balanceOf(address(this));

        farm.stake(100 * WAD);

        assertEq(farm.balanceOf(address(this)), 100 * WAD);
        assertEq(gem.balanceOf(address(this)), gemBalance - 100 * WAD);
        assertEq(gem.balanceOf(address(farm)), 100 * WAD);
    }

    function testRevertOnZeroStake() public {
        vm.expectRevert("Cannot stake 0");
        farm.stake(0);
    }

    function testEarned() public {
        assertEq(farm.earned(address(this)), 0);

        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        setupReward(5000 * WAD);

        skip(1 days);

        assert(farm.earned(address(this)) > 0);
    }

    function testRewardRateIncreaseOnNewRewardBeforeDurationEnd() public {
        setupReward(5000 * WAD);

        uint256 rewardRate = farm.rewardRate();

        setupReward(5000 * WAD);

        assert(rewardRate > 0);
        assert(farm.rewardRate() > rewardRate);
    }

    function earnedShouldIncreaseAfterDuration() public {
        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        setupStakingToken(5000 * WAD);

        skip(7 days);

        uint256 earned = farm.earned(address(this));

        setupStakingToken(5000 * WAD);

        skip(7 days);

        assertEq(farm.earned(address(this)), earned + earned);
    }

    function testGetRewardEvent() public {
        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        setupReward(5000 * WAD);

        skip(1 days);

        vm.expectEmit(true, true, true, true);
        emit RewardPaid(address(this), farm.rewardRate() * 1 days);
        farm.getReward();
    }

    function testGetReward() public {
        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        setupReward(5000 * WAD);

        skip(1 days);

        uint256 rewardBalance = rewardGem.balanceOf(address(this));
        uint256 earned = farm.earned(address(this));

        farm.getReward();

        assert(farm.earned(address(this)) < earned);
        assert(rewardGem.balanceOf(address(this)) > rewardBalance);
    }

    function testsetRewardsDurationEvent() public {
        vm.expectEmit(true, true, true, true);
        emit RewardsDurationUpdated(70 days);
        farm.setRewardsDuration(70 days);
    }

    function testSetRewardsDurationBeforeDistribution() public {
        assertEq(farm.rewardsDuration(), 7 days);

        farm.setRewardsDuration(70 days);

        assertEq(farm.rewardsDuration(), 70 days);
    }

    function testRevertSetRewardsDurationOnActiveDistribution() public {
        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        setupReward(100 * WAD);

        skip(1 days);

        vm.expectRevert("Previous rewards period must be complete before changing the duration for the new period");
        farm.setRewardsDuration(70 days);
    }

    function testSetRewardsDurationAfterDistributionPeriod() public {
        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        setupReward(100 * WAD);

        skip(8 days);

        farm.setRewardsDuration(70 days);
        assertEq(farm.rewardsDuration(), 70 days);
    }

    function testGetRewardForDuration() public {
        setupReward(5000 * WAD);

        uint256 rewardForDuration = farm.getRewardForDuration();
        uint256 rewardDuration = farm.rewardsDuration();
        uint256 rewardRate = farm.rewardRate();

        assert(rewardForDuration > 0);
        assertEq(rewardForDuration, rewardRate * rewardDuration);
    }

    function testWithdrawalEvent() public {
        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Withdrawn(address(this), 1 * WAD);
        farm.withdraw(1 * WAD);
    }

    function testFailtIfNothingToWithdraw() public {
        farm.withdraw(1);
    }

    function testRevertOnZeroWithdraw() public {
        vm.expectRevert("Cannot withdraw 0");
        farm.withdraw(0);
    }

    function testWithdrwal() public {
        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        uint256 initialStakeBalance = farm.balanceOf(address(this));

        farm.withdraw(100 * WAD);

        assertEq(initialStakeBalance, farm.balanceOf(address(this)) + 100 * WAD);
        assertEq(gem.balanceOf(address(this)), 100 * WAD);
    }

    function testExit() public {
        setupStakingToken(100 * WAD);
        farm.stake(100 * WAD);

        setupReward(500 * WAD);

        skip(1 days);

        farm.exit();

        assertEq(farm.earned(address(this)), 0);
        assertEq(gem.balanceOf(address(this)), 100 * WAD);
        assertEq(rewardGem.balanceOf(address(this)), farm.rewardRate() * 1 days);
    }

    function testNotifyRewardEvent() public {
        uint256 amt = 1 * WAD;

        rewardGem.mint(amt);
        rewardGem.transfer(address(farm), amt);

        vm.expectEmit(false, false, false, true, address(farm));
        emit RewardAdded(amt);

        farm.notifyRewardAmount(amt);
    }

    function testRevertOnNotBeingRewardDistributor() public {
        vm.prank(address(0));
        vm.expectRevert("Caller is not RewardsDistribution contract");
        farm.notifyRewardAmount(1);
    }

    function testRevertOnRewardGreaterThenBalance() public {
        rewardGem.mint(100 * WAD);
        rewardGem.transfer(address(farm), 100 * WAD);

        vm.expectRevert("Provided reward too high");
        farm.notifyRewardAmount(101 * WAD);
    }

    function testRevertOnRewardGreaterThenBalancePlusRollOverBalance() public {
        setupReward(100 * WAD);

        rewardGem.mint(100 * WAD);
        rewardGem.transfer(address(farm), 100 * WAD);

        vm.expectRevert("Provided reward too high");
        farm.notifyRewardAmount(101 * WAD);
    }

    function testFarm() public {
        uint256 staked = 100 * WAD;

        setupStakingToken(staked);
        farm.stake(staked);

        setupReward(5000 * WAD);

        // Period finish should be 7 days from now
        assertEq(farm.periodFinish(), block.timestamp + 7 days);

        // Reward duration is 7 days, so we'll
        // skip by 6 days to prevent expiration
        skip(6 days);

        // Make sure we earned in proportion to reward per token
        assertEq(farm.earned(address(this)), (farm.rewardPerToken() * staked) / WAD);

        // Make sure we get staking token after withdrawal and we still have the same amount earned
        farm.withdraw(20 * WAD);
        assertEq(gem.balanceOf(address(this)), 20 * WAD);
        assertEq(farm.earned(address(this)), (farm.rewardPerToken() * staked) / WAD);

        // Get rewards
        farm.getReward();
        assertEq(rewardGem.balanceOf(address(this)), (farm.rewardPerToken() * staked) / WAD);
        assertEq(farm.earned(address(this)), 0);

        // exit
        farm.exit();
        assertEq(gem.balanceOf(address(this)), staked);
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Referral(uint16 indexed referral, address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event RewardsDistributionUpdated(address newRewardsDistribution);
    event Recovered(address token, uint256 amount);
}

contract TestToken is ERC20 {
    uint8 private _decimals;

    constructor(string memory symbol_, uint8 decimals_) ERC20("TestToken", symbol_) {
        _decimals = decimals_;
    }

    function mint(uint256 wad) external {
        _mint(msg.sender, wad);
    }
}
