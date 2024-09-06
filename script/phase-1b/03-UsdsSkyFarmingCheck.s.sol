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
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {Reader} from "../helpers/Reader.sol";

contract Phase1b_UsdsSkyFarmingCheckScript is Script {
    function run() external returns (bool) {
        Reader config = new Reader(ScriptTools.loadConfig());
        Reader deps = new Reader(ScriptTools.loadDependencies());

        address admin = deps.envOrReadAddress("FOUNDRY_ADMIN", ".admin");
        address sky = deps.envOrReadAddress("FOUNDRY_SKY", ".sky");
        address usds = deps.envOrReadAddress("FOUNDRY_USDS", ".usds");
        address dist = deps.readAddress(".dist");
        address rewards = deps.readAddress(".rewards");
        address vest = deps.readAddress(".vest");
        uint256 vestId = deps.readUint(".vestId");
        uint256 vestBgn = config.readUint(".vestBgn");
        uint256 vestTau = config.readUint(".vestTau");
        uint256 vestTot = config.readUint(".vestTot");

        require(VestedRewardsDistributionLike(dist).dssVest() == vest, "VestedRewardsDistribution/invalid-vest");
        require(VestedRewardsDistributionLike(dist).vestId() == vestId, "VestedRewardsDistribution/invalid-vest-id");
        require(VestedRewardsDistributionLike(dist).gem() == sky, "VestedRewardsDistribution/invalid-gem");
        require(
            VestedRewardsDistributionLike(dist).stakingRewards() == rewards,
            "VestedRewardsDistribution/invalid-staking-rewards"
        );

        require(StakingRewardsLike(rewards).owner() == admin, "StakingRewards/admin-not-owner");
        require(StakingRewardsLike(rewards).rewardsToken() == sky, "StakingRewards/invalid-rewards-token");
        require(StakingRewardsLike(rewards).stakingToken() == usds, "StakingRewards/invalid-staking-token");
        require(
            StakingRewardsLike(rewards).rewardsDistribution() == dist,
            "StakingRewards/invalid-rewards-distribution"
        );

        require(WardsLike(sky).wards(vest) == 1, "Sky/dss-vest-not-ward");

        require(DssVestWithGemLike(vest).gem() == sky, "DssVest/invalid-gem");
        require(DssVestWithGemLike(vest).valid(vestId), "DssVest/invalid-vest-id");
        require(DssVestWithGemLike(vest).res(vestId) == 1, "DssVest/invalid-vest-res");
        require(DssVestWithGemLike(vest).usr(vestId) == dist, "DssVest/wrong-dist");
        require(DssVestWithGemLike(vest).mgr(vestId) == address(0), "DssVest/mgr-should-not-be-set");
        require(DssVestWithGemLike(vest).bgn(vestId) == vestBgn, "DssVest/invalid-bgn");
        require(DssVestWithGemLike(vest).fin(vestId) == vestBgn + vestTau, "DssVest/invalid-tau");
        require(DssVestWithGemLike(vest).tot(vestId) == vestTot, "DssVest/invalid-tot");

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
    function bgn(uint256 _id) external view returns (uint256);

    function fin(uint256 _id) external view returns (uint256);

    function gem() external view returns (address);

    function mgr(uint256 _id) external view returns (address);

    function res(uint256 _id) external view returns (uint256);

    function tot(uint256 _id) external view returns (uint256);

    function usr(uint256 _id) external view returns (address);

    function valid(uint256 _id) external view returns (bool);
}
