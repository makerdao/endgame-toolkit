// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
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
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {Reader} from "../helpers/Reader.sol";

contract Phase0Alpha_FarmingCheckScript is Script {
    function run() external returns (bool) {
        Reader deps = new Reader("");
        deps.loadDependenciesOrConfig();

        address admin = deps.envOrReadAddress("FOUNDRY_ADMIN", ".admin");
        address ngt = deps.envOrReadAddress("FOUNDRY_NGT", ".ngt");
        address nst = deps.envOrReadAddress("FOUNDRY_NST", ".nst");
        address dist = deps.readAddress(".dist");
        address rewards = deps.readAddress(".rewards");
        address vest = deps.readAddress(".vest");
        uint256 vestId = deps.readUint(".vestId");

        require(VestedRewardsDistributionLike(dist).dssVest() == vest, "VestedRewardsDistribution/invalid-vest");
        require(VestedRewardsDistributionLike(dist).vestId() == vestId, "VestedRewardsDistribution/invalid-vest-id");
        require(VestedRewardsDistributionLike(dist).gem() == ngt, "VestedRewardsDistribution/invalid-gem");
        require(
            VestedRewardsDistributionLike(dist).stakingRewards() == rewards,
            "VestedRewardsDistribution/invalid-staking-rewards"
        );

        require(StakingRewardsLike(rewards).owner() == admin, "StakingRewards/admin-not-owner");
        require(StakingRewardsLike(rewards).rewardsToken() == ngt, "StakingRewards/invalid-rewards-token");
        require(StakingRewardsLike(rewards).stakingToken() == nst, "StakingRewards/invalid-rewards-token");
        require(
            StakingRewardsLike(rewards).rewardsDistribution() == dist,
            "StakingRewards/invalid-rewards-distribution"
        );

        require(WardsLike(ngt).wards(vest) == 1, "Ngt/dss-vest-not-ward");

        require(DssVestWithGemLike(vest).gem() == ngt, "DssVest/invalid-gem");
        require(DssVestWithGemLike(vest).valid(vestId), "DssVest/invalid-vest-id");
        require(DssVestWithGemLike(vest).res(vestId) == 1, "DssVest/invalid-vest-res");
        require(DssVestWithGemLike(vest).usr(vestId) == dist, "DssVest/wrong-dist");
        require(DssVestWithGemLike(vest).mgr(vestId) == address(0), "DssVest/mgr-should-not-be-set");

        return true;
    }
}

interface WardsLike {
    function wards(address who) external view returns (uint256);
}

interface VestedRewardsDistributionLike {
    function dssVest() external view returns (address);

    function vestId() external view returns (uint256);

    function stakingRewards() external view returns (address);

    function gem() external view returns (address);
}

interface StakingRewardsLike {
    function owner() external view returns (address);

    function stakingToken() external view returns (address);

    function rewardsToken() external view returns (address);

    function rewardsDistribution() external view returns (address);
}

interface DssVestWithGemLike {
    function gem() external view returns (address);

    function tot(uint256 vestId) external view returns (uint256);

    function bgn(uint256 vestId) external view returns (uint256);

    function clf(uint256 vestId) external view returns (uint256);

    function fin(uint256 vestId) external view returns (uint256);

    function mgr(uint256 vestId) external view returns (address);

    function res(uint256 vestId) external view returns (uint256);

    function usr(uint256 vestId) external view returns (address);

    function valid(uint256 _id) external view returns (bool);
}
