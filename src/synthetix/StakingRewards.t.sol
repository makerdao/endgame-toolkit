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
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {StakingRewards} from "./StakingRewards.sol";

contract StakingRewardsTest is Test {
    uint256 constant WAD = 10 ** 18;

    TestToken rewardGem;
    TestToken gem;
    StakingRewards rewards;

    function setupReward(uint256 amt) internal {
        rewardGem.mint(amt);
        rewardGem.transfer(address(rewards), amt);
        rewards.notifyRewardAmount(amt);
    }

    function setupStakingToken(uint256 amt) internal {
        gem.mint(amt);
        gem.approve(address(rewards), amt);
    }

    function initFarm(uint256 stake, uint256 reward, uint256 duration) internal {
        rewards.setRewardsDuration(duration);
        setupReward(reward);
        setupStakingToken(stake);
        rewards.stake(stake);
        assertEq(rewardGem.balanceOf(address(this)), 0);
        assertEq(rewardGem.balanceOf(address(rewards)), reward);
        assertEq(gem.balanceOf(address(this)), 0);
        assertEq(gem.balanceOf(address(rewards)), stake);
        assertEq(rewards.rewardPerTokenStored(), 0);
        assertEq(rewards.lastUpdateTime(), block.timestamp);
        assertEq(rewards.rewardRate(), reward / duration);
        assertEq(rewards.periodFinish(), block.timestamp + duration);
        assertEq(rewards.rewardsDuration(), duration);
    }

    function setUp() public {
        rewardGem = new TestToken("SubDaoT", 18);
        gem = new TestToken("MKR", 18);

        rewards = new StakingRewards(address(this), address(this), address(rewardGem), address(gem));
    }

    function testConstructor() public {
        StakingRewards f = new StakingRewards(address(this), address(this), address(rewardGem), address(gem));

        assertEq(address(f.rewardsToken()), address(rewardGem));
        assertEq(address(f.stakingToken()), address(gem));
        assertEq(f.rewardsDistribution(), address(this));
    }

    function testRevertConstructorWhenStakingAndRewardsTokenAreTheSame() public {
        vm.expectRevert("Rewards and staking tokens must not be the same");
        new StakingRewards(address(this), address(this), address(gem), address(gem));
    }

    function testSetRewardsDistribution() public {
        rewards.setRewardsDistribution(address(0));
        assertEq(rewards.rewardsDistribution(), address(0));
    }

    function testSetRewardsDistributionEvent() public {
        vm.expectEmit(false, false, false, true, address(rewards));
        emit RewardsDistributionUpdated(address(0));

        rewards.setRewardsDistribution(address(0));
    }

    function testRevertOnUnauthorizedMethods() public {
        vm.startPrank(address(0));

        vm.expectRevert("Only the contract owner may perform this action");
        rewards.setRewardsDistribution(address(0));

        vm.expectRevert("Only the contract owner may perform this action");
        rewards.setRewardsDuration(1 days);

        vm.expectRevert("Only the contract owner may perform this action");
        rewards.setPaused(true);

        vm.expectRevert("Only the contract owner may perform this action");
        rewards.recoverERC20(address(0), 1);

        vm.expectRevert("Caller is not RewardsDistribution contract");
        rewards.notifyRewardAmount(1);
    }

    function testRevertStakeWhenPaused() public {
        rewards.setPaused(true);

        vm.expectRevert("This action cannot be performed while the contract is paused");
        rewards.stake(1);
    }

    function testPauseUnpause() public {
        rewards.setPaused(true);

        vm.expectRevert("This action cannot be performed while the contract is paused");
        rewards.stake(1);

        rewards.setPaused(false);

        setupStakingToken(1);
        rewards.stake(1);
    }

    function testRevertOnRecoverStakingToken() public {
        vm.expectRevert("Cannot withdraw the staking token");
        rewards.recoverERC20(address(gem), 1);
    }

    function testRecoverERC20() public {
        TestToken t = new TestToken("TT", 18);
        t.mint(10);
        t.transfer(address(rewards), 10);

        assertEq(t.balanceOf(address(rewards)), 10);

        vm.expectEmit(true, true, true, true);
        emit Recovered(address(t), 10);

        rewards.recoverERC20(address(t), 10);

        assertEq(t.balanceOf(address(rewards)), 0);
        assertEq(t.balanceOf(address(this)), 10);
    }

    function testLastTimeRewardApplicable() public {
        assertEq(rewards.lastTimeRewardApplicable(), 0);

        setupReward(10 * WAD);

        assertEq(rewards.lastTimeRewardApplicable(), block.timestamp);
    }

    function testRewardPerToken() public {
        assertEq(rewards.rewardPerToken(), 0);

        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        assertEq(rewards.totalSupply(), 100 * WAD);

        setupReward(5000 * WAD);

        skip(1 days);

        assert(rewards.rewardPerToken() > 0);
    }

    function testStakeEmitEvent() public {
        setupStakingToken(100 * WAD);

        vm.expectEmit(false, false, false, true, address(rewards));
        emit Staked(address(this), 100 * WAD);
        rewards.stake(100 * WAD);
    }

    function testStakeWithReferralEmitEvent() public {
        uint16 referralCode = 1;

        setupStakingToken(100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Staked(address(this), 100 * WAD);
        vm.expectEmit(true, false, false, false);
        emit Referral(1, address(this), 100 * WAD);

        rewards.stake(100 * WAD, referralCode);
    }

    function testStaking() public {
        setupStakingToken(100 * WAD);

        uint256 gemBalance = gem.balanceOf(address(this));

        rewards.stake(100 * WAD);

        assertEq(rewards.balanceOf(address(this)), 100 * WAD);
        assertEq(gem.balanceOf(address(this)), gemBalance - 100 * WAD);
        assertEq(gem.balanceOf(address(rewards)), 100 * WAD);
    }

    function testRevertOnZeroStake() public {
        vm.expectRevert("Cannot stake 0");
        rewards.stake(0);
    }

    function testEarned() public {
        assertEq(rewards.earned(address(this)), 0);

        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        setupReward(5000 * WAD);

        skip(1 days);

        assert(rewards.earned(address(this)) > 0);
    }

    function testRewardRateIncreaseOnNewRewardBeforeDurationEnd() public {
        setupReward(5000 * WAD);

        uint256 rewardRate = rewards.rewardRate();

        setupReward(5000 * WAD);

        assert(rewardRate > 0);
        assert(rewards.rewardRate() > rewardRate);
    }

    function earnedShouldIncreaseAfterDuration() public {
        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        setupStakingToken(5000 * WAD);

        skip(7 days);

        uint256 earned = rewards.earned(address(this));

        setupStakingToken(5000 * WAD);

        skip(7 days);

        assertEq(rewards.earned(address(this)), earned + earned);
    }

    function testGetRewardEvent() public {
        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        setupReward(5000 * WAD);

        skip(1 days);

        vm.expectEmit(true, true, true, true);
        emit RewardPaid(address(this), rewards.rewardRate() * 1 days);
        rewards.getReward();
    }

    function testGetReward() public {
        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        setupReward(5000 * WAD);

        skip(1 days);

        uint256 rewardBalance = rewardGem.balanceOf(address(this));
        uint256 earned = rewards.earned(address(this));

        rewards.getReward();

        assert(rewards.earned(address(this)) < earned);
        assert(rewardGem.balanceOf(address(this)) > rewardBalance);
    }

    function testSetRewardsDurationEvent() public {
        vm.expectEmit(true, true, true, true);
        emit RewardsDurationUpdated(70 days);
        rewards.setRewardsDuration(70 days);
    }

    function testSetRewardsDurationBeforeDistribution() public {
        assertEq(rewards.rewardsDuration(), 7 days);

        rewards.setRewardsDuration(70 days);

        assertEq(rewards.rewardsDuration(), 70 days);
    }

    function checkChangeRewardDurationOnActiveDistribution(uint256 newDuration) private {
        uint256 totalStake = 100 * WAD;
        uint256 totalReward = 123 * WAD;
        uint256 initialDuration = 7 days;
        uint256 initialRun = 1 days;
        initFarm(totalStake, totalReward, initialDuration);

        skip(initialRun);

        rewards.setRewardsDuration(newDuration);

        assertEq(rewards.rewardPerTokenStored(), (initialRun * (totalReward / initialDuration) * WAD) / totalStake);
        assertEq(rewards.lastUpdateTime(), block.timestamp);
        assertEq(
            rewards.rewardRate(),
            ((initialDuration - initialRun) * (totalReward / initialDuration)) / newDuration
        );
        assertEq(rewards.periodFinish(), block.timestamp + newDuration);
        assertEq(rewards.rewardsDuration(), newDuration);

        skip(newDuration);

        rewards.exit();

        uint256 rewardLeft = (totalReward % initialDuration) +
            (((initialDuration - initialRun) * (totalReward / initialDuration)) % newDuration); // dust lost due to rewardRate being rounded down
        uint256 rewardPaid = totalReward - rewardLeft;
        assertEq(rewardGem.balanceOf(address(this)), rewardPaid);
        assertEq(rewardGem.balanceOf(address(rewards)), rewardLeft);
        assertEq(gem.balanceOf(address(this)), totalStake);
        assertEq(gem.balanceOf(address(rewards)), 0);
    }

    function testIncreaseRewardsDurationOnActiveDistribution() public {
        checkChangeRewardDurationOnActiveDistribution(70 days);
    }

    function testDecreaseRewardsDurationOnActiveDistribution() public {
        checkChangeRewardDurationOnActiveDistribution(5 days);
    }

    function testSetSameRewardsDurationOnActiveDistribution() public {
        uint256 totalStake = 100 * WAD;
        uint256 totalReward = 123 * WAD;
        uint256 initialDuration = 7 days;
        uint256 initialRun = 1 days;
        initFarm(totalStake, totalReward, initialDuration);
        skip(initialRun);

        uint256 prevRewardRate = rewards.rewardRate();
        uint256 prevPeriodFinish = rewards.periodFinish();

        rewards.setRewardsDuration(initialDuration - initialRun); // same duration as time left

        assertEq(rewards.rewardPerTokenStored(), (initialRun * (totalReward / initialDuration) * WAD) / totalStake);
        assertEq(rewards.lastUpdateTime(), block.timestamp);
        assertEq(rewards.rewardRate(), prevRewardRate);
        assertEq(rewards.periodFinish(), prevPeriodFinish);
        assertEq(rewards.rewardsDuration(), initialDuration - initialRun);
    }

    function testSetRewardsDurationAndNotifyRewardAmountCallOrderOnActiveDistribution() public {
        uint256 totalStake = 100 * WAD;
        uint256 initialReward = 123 * WAD;
        uint256 additionalReward = 32 * WAD;
        uint256 initialDuration = 7 days;
        uint256 initialRun = 1 days;
        initFarm(totalStake, initialReward, initialDuration);
        skip(initialRun);

        uint256 snapshot = vm.snapshot();

        // call setRewardsDuration followed by notifyRewardAmount in the same block
        rewards.setRewardsDuration(13 days);
        setupReward(additionalReward);

        assertEq(rewards.rewardPerTokenStored(), (initialRun * (initialReward / initialDuration) * WAD) / totalStake);
        assertEq(rewards.lastUpdateTime(), block.timestamp);
        assertEq(
            rewards.rewardRate(),
            ((initialDuration - initialRun) * (initialReward / initialDuration) + additionalReward) / 13 days
        );
        assertEq(rewards.periodFinish(), block.timestamp + 13 days);
        assertEq(rewards.rewardsDuration(), 13 days);

        skip(13 days);

        rewards.exit();

        uint256 rewardLeft = (initialReward % initialDuration) +
            (((initialDuration - initialRun) * (initialReward / initialDuration) + additionalReward) % 13 days); // dust lost due to rewardRate being rounded down
        uint256 rewardPaid = initialReward + additionalReward - rewardLeft;
        assertEq(rewardGem.balanceOf(address(this)), rewardPaid);
        assertEq(rewardGem.balanceOf(address(rewards)), rewardLeft);
        assertEq(gem.balanceOf(address(this)), totalStake);
        assertEq(gem.balanceOf(address(rewards)), 0);

        // reset farm
        vm.revertTo(snapshot);

        // call notifyRewardAmount followed by setRewardsDuration in the same block
        setupReward(additionalReward);
        rewards.setRewardsDuration(13 days);

        // same values as before
        assertEq(rewards.rewardPerTokenStored(), (initialRun * (initialReward / initialDuration) * WAD) / totalStake);
        assertEq(rewards.lastUpdateTime(), block.timestamp);
        assertEq(
            rewards.rewardRate(),
            ((initialDuration - initialRun) * (initialReward / initialDuration) + additionalReward) / 13 days
        );
        assertEq(rewards.periodFinish(), block.timestamp + 13 days);
        assertEq(rewards.rewardsDuration(), 13 days);

        skip(13 days);

        rewards.exit();

        // same values as before
        rewardLeft =
            (initialReward % initialDuration) +
            (((initialDuration - initialRun) * (initialReward / initialDuration) + additionalReward) % 13 days); // dust lost due to rewardRate being rounded down
        rewardPaid = initialReward + additionalReward - rewardLeft;
        assertEq(rewardGem.balanceOf(address(this)), rewardPaid);
        assertEq(rewardGem.balanceOf(address(rewards)), rewardLeft);
        assertEq(gem.balanceOf(address(this)), totalStake);
        assertEq(gem.balanceOf(address(rewards)), 0);
    }

    function testSetRewardsDurationAfterDistributionPeriod() public {
        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        setupReward(100 * WAD);

        skip(8 days);

        rewards.setRewardsDuration(70 days);
        assertEq(rewards.rewardsDuration(), 70 days);
    }

    function testGetRewardForDuration() public {
        setupReward(5000 * WAD);

        uint256 rewardForDuration = rewards.getRewardForDuration();
        uint256 rewardDuration = rewards.rewardsDuration();
        uint256 rewardRate = rewards.rewardRate();

        assert(rewardForDuration > 0);
        assertEq(rewardForDuration, rewardRate * rewardDuration);
    }

    function testWithdrawalEvent() public {
        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        vm.expectEmit(true, true, true, true);
        emit Withdrawn(address(this), 1 * WAD);
        rewards.withdraw(1 * WAD);
    }

    function testRevertIfNothingToWithdraw() public {
        vm.expectRevert();
        rewards.withdraw(1);
    }

    function testRevertOnZeroWithdraw() public {
        vm.expectRevert("Cannot withdraw 0");
        rewards.withdraw(0);
    }

    function testWithdrawal() public {
        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        uint256 initialStakeBalance = rewards.balanceOf(address(this));

        rewards.withdraw(100 * WAD);

        assertEq(initialStakeBalance, rewards.balanceOf(address(this)) + 100 * WAD);
        assertEq(gem.balanceOf(address(this)), 100 * WAD);
    }

    function testExit() public {
        setupStakingToken(100 * WAD);
        rewards.stake(100 * WAD);

        setupReward(500 * WAD);

        skip(1 days);

        rewards.exit();

        assertEq(rewards.earned(address(this)), 0);
        assertEq(gem.balanceOf(address(this)), 100 * WAD);
        assertEq(rewardGem.balanceOf(address(this)), rewards.rewardRate() * 1 days);
    }

    function testNotifyRewardEvent() public {
        uint256 amt = 1 * WAD;

        rewardGem.mint(amt);
        rewardGem.transfer(address(rewards), amt);

        vm.expectEmit(false, false, false, true, address(rewards));
        emit RewardAdded(amt);

        rewards.notifyRewardAmount(amt);
    }

    function testRevertOnNotBeingRewardDistributor() public {
        vm.prank(address(0));
        vm.expectRevert("Caller is not RewardsDistribution contract");
        rewards.notifyRewardAmount(1);
    }

    function testRevertOnRewardGreaterThenBalance() public {
        rewardGem.mint(100 * WAD);
        rewardGem.transfer(address(rewards), 100 * WAD);

        vm.expectRevert("Provided reward too high");
        rewards.notifyRewardAmount(101 * WAD);
    }

    function testRevertOnRewardGreaterThenBalancePlusRollOverBalance() public {
        setupReward(100 * WAD);

        rewardGem.mint(100 * WAD);
        rewardGem.transfer(address(rewards), 100 * WAD);

        vm.expectRevert("Provided reward too high");
        rewards.notifyRewardAmount(101 * WAD);
    }

    function testFarm() public {
        uint256 staked = 100 * WAD;

        setupStakingToken(staked);
        rewards.stake(staked);

        setupReward(5000 * WAD);

        // Period finish should be 7 days from now
        assertEq(rewards.periodFinish(), block.timestamp + 7 days);

        // Reward duration is 7 days, so we'll
        // skip by 6 days to prevent expiration
        skip(6 days);

        // Make sure we earned in proportion to reward per token
        assertEq(rewards.earned(address(this)), (rewards.rewardPerToken() * staked) / WAD);

        // Make sure we get staking token after withdrawal and we still have the same amount earned
        rewards.withdraw(20 * WAD);
        assertEq(gem.balanceOf(address(this)), 20 * WAD);
        assertEq(rewards.earned(address(this)), (rewards.rewardPerToken() * staked) / WAD);

        // Get rewards
        rewards.getReward();
        assertEq(rewardGem.balanceOf(address(this)), (rewards.rewardPerToken() * staked) / WAD);
        assertEq(rewards.earned(address(this)), 0);

        // exit
        rewards.exit();
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
