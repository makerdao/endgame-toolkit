// SPDX-FileCopyrightText: © 2017, 2018, 2019 dbrock, rain, mrchico
// SPDX-FileCopyrightText: © 2023 SDAO Foundation <www.sdaofoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
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
pragma solidity =0.8.19;

import {DssTest, stdStorage, StdStorage} from "dss-test/DssTest.sol";
import {DssVestWithGemLike} from "./interfaces/DssVestWithGemLike.sol";
import {StakingRewardsLike} from "./interfaces/StakingRewardsLike.sol";
import {SDAO} from "./SDAO.sol";
import {RewardsDistribution} from "./RewardsDistribution.sol";
import {DistributionCalc, LinearDistribution, ConstantDistribution} from "./DistributionCalc.sol";

contract RewardsDistributionTest is DssTest {
    using stdStorage for StdStorage;

    RewardsDistribution dist;
    DistributionCalc calc;
    DssVestWithGemLike vest;
    StakingRewardsLike farm;
    SDAO token;

    uint256 totalRewards = 1 * 10 ** 18;
    uint256 duration = 360 days;

    uint256 vestId;

    function setUp() public {
        // DssVest checks if params are not too far away in the future or in the past relative to `block.timestamp`.
        // It has a 20 years interval check hardcoded, so we need to be at a time that is at least 20 years ahead of
        // the Unix epoch.  We are setting the current date of the chain to 2000-01-01 to comply with that requirement.
        vm.warp(946692000);

        token = new SDAO("Token", "TKN");

        vest = DssVestWithGemLike(deployCode("DssVest.sol:DssVestMintable", abi.encode(address(token))));
        vest.file("cap", type(uint256).max);
        farm = new FakeStakingRewards(address(token), 7 days);
        calc = new ConstantDistribution();
        dist = new RewardsDistribution(address(vest), address(farm), address(calc));

        vestId = _createVest();

        dist.file("vestId", vestId);
        // Allow DssVest to mint tokens
        token.rely(address(vest));
    }

    function testDistribute() public {
        // 1st distribution
        skip(duration / 3);

        assertEq(token.balanceOf(address(farm)), 0);

        vm.expectEmit(false, false, false, true, address(farm));
        emit RewardAdded(totalRewards / 3);
        dist.distribute();

        assertEq(token.balanceOf(address(farm)), totalRewards / 3);

        // 2nd distribution
        skip(duration / 3);

        vm.expectEmit(false, false, false, true, address(farm));
        emit RewardAdded(totalRewards / 3);
        dist.distribute();

        // Allow for 0,01% error tolerance due to rounding errors.
        uint256 tolerance = 0.01e18;

        assertApproxEqRel(token.balanceOf(address(farm)), (2 * totalRewards) / 3, tolerance);

        // 3rd distribution
        skip(duration / 3);

        vm.expectEmit(false, false, false, true, address(farm));
        emit RewardAdded(totalRewards / 3);
        dist.distribute();

        assertApproxEqRel(token.balanceOf(address(farm)), totalRewards, tolerance);
    }

    function testRevertDistributeInvalidVestId() public {
        // We're `file`ing a valid `vestId` on `setUp`, so we need to revert it to its initial value
        stdstore.target(address(dist)).sig("vestId()").checked_write(bytes32(0));

        vm.expectRevert("RewardsDistribution/invalid-vest-id");
        dist.distribute();
    }

    function testRevertDistributeNoVestedAmount() public {
        vm.expectRevert("RewardsDistribution/empty-vest");
        dist.distribute();
    }

    function testRevertDistributeNoPendingDistributionAmount() public {
        dist.file("calc", address(new ZeroDistribution()));

        skip(duration / 3);

        vm.expectRevert("RewardsDistribution/no-pending-amount");
        dist.distribute();
    }

    function testRevertFileInvalidVestId() public {
        vm.expectRevert("RewardsDistribution/invalid-vest-id");
        dist.file("vestId", 100);
    }

    function testRevertFileInvalidUsr() public {
        address usr = address(0x1337);
        uint256 tot = totalRewards;
        uint256 bgn = block.timestamp; // start immediately
        uint256 tau = duration; // 1 year duration
        uint256 eta = 0; // No cliff; start immediatebly
        address mgr = address(dist);
        uint256 newVestId = _createVest(usr, tot, bgn, tau, eta, mgr);

        vm.expectRevert("RewardsDistribution/invalid-vest-usr");
        dist.file("vestId", newVestId);
    }

    function testRevertFileInvalidMgr() public {
        address usr = address(farm);
        uint256 tot = totalRewards;
        uint256 bgn = block.timestamp; // start immediately
        uint256 tau = duration; // 1 year duration
        uint256 eta = 0; // No cliff; start immediatebly
        address mgr = address(0x1337);
        uint256 newVestId = _createVest(usr, tot, bgn, tau, eta, mgr);

        vm.expectRevert("RewardsDistribution/invalid-vest-mgr");
        dist.file("vestId", newVestId);
    }

    function testAuth() public {
        checkAuth(address(dist), "RewardsDistribution");
    }

    function testFile() public {
        // `checkFileUint` increaments the current value of the param being modified. Since `vestId` is validated,
        // we need to create a new one to make sure the `file`d param is valid.
        _createVest();
        checkFileUint(address(dist), "RewardsDistribution", ["vestId"]);

        checkFileAddress(address(dist), "RewardsDistribution", ["calc"]);
    }

    function testModifiers(address sender) private {
        vm.assume(sender != address(this));

        bytes4[] memory authedMethods = new bytes4[](1);
        // authedMethods[0] = RewardsDistribution.mint.selector;

        vm.startPrank(sender);
        checkModifier(address(dist), "RewardsDistribution/not-authorized", authedMethods);
    }

    function _createVest() internal returns (uint256 _vestId) {
        address usr = address(farm);
        uint256 tot = totalRewards;
        uint256 bgn = block.timestamp; // start immediately
        uint256 tau = duration; // 1 year duration
        uint256 eta = 0; // No cliff; start immediatebly
        address mgr = address(dist);

        return _createVest(usr, tot, bgn, tau, eta, mgr);
    }

    function _createVest(
        address usr,
        uint256 tot,
        uint256 bgn,
        uint256 tau,
        uint256 eta,
        address mgr
    ) internal returns (uint256 _vestId) {
        return vest.create(usr, tot, bgn, tau, eta, mgr);
    }

    event RewardAdded(uint256 reward);
}

contract FakeStakingRewards is StakingRewardsLike {
    address public rewardsToken;
    uint256 public lastUpdateTime;
    uint256 public rewardsDuration;

    event RewardAdded(uint256 reward);

    constructor(address _rewardsToken, uint256 _rewardsDuration) {
        rewardsToken = _rewardsToken;
        rewardsDuration = _rewardsDuration;
        lastUpdateTime = block.timestamp;
    }

    function notifyRewardAmount(uint256 amt) external {
        lastUpdateTime = block.timestamp;

        emit RewardAdded(amt);
    }
}

contract ZeroDistribution is DistributionCalc {
    function getAmount(uint256, uint256, uint256, uint256, uint256) external pure returns (uint256) {
        return 0;
    }
}
