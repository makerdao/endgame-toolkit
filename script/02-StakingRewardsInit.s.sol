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
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";

import {Reader} from "./helpers/Reader.sol";
import {StakingRewardsInit, StakingRewardsInitParams} from "./dependencies/StakingRewardsInit.sol";
import {
    VestedRewardsDistributionInit,
    VestedRewardsDistributionInitParams
} from "./dependencies/VestedRewardsDistributionInit.sol";
import {VestInit, VestInitParams, VestCreateParams} from "./dependencies/VestInit.sol";

interface RelyLike {
    function rely(address who) external;
}

interface DssVestWithGemLike {
    function gem() external view returns (address);
}

interface StakingRewardsLike {
    function rewardsToken() external view returns (address);

    function stakingToken() external view returns (address);
}

interface VestedRewardsDistributionLike {
    function dssVest() external view returns (address);

    function gem() external view returns (address);

    function stakingRewards() external view returns (address);
}

contract Phase0StakingRewardsInitScript is Script {
    using stdJson for string;
    using ScriptTools for string;

    string internal constant NAME = "Phase0StakingRewardsInit";

    function run() external {
        Reader deps = new Reader(ScriptTools.loadDependencies());

        address ngt = deps.envOrReadAddress(".ngt", "FOUNDRY_NGT");
        address nst = deps.envOrReadAddress(".nst", "FOUNDRY_NST");
        address dist = deps.envOrReadAddress(".dist", "FOUNDRY_DIST");
        address farm = deps.envOrReadAddress(".farm", "FOUNDRY_FARM");
        address vest = deps.envOrReadAddress(".vest", "FOUNDRY_VEST");

        Reader config = new Reader(ScriptTools.loadConfig());

        uint256 vestCap = config.readUint(".vestCap");
        uint256 vestTot = config.readUint(".vestTot");
        uint256 vestBgn = config.readUint(".vestBgn");
        uint256 vestTau = config.readUint(".vestTau");

        vm.startBroadcast();

        require(DssVestWithGemLike(vest).gem() == ngt, "DssVest/invalid-gem");

        require(StakingRewardsLike(farm).rewardsToken() == ngt, "StakingRewards/invalid-rewards-token");
        require(StakingRewardsLike(farm).stakingToken() == nst, "StakingRewards/invalid-staking-token");

        require(VestedRewardsDistributionLike(dist).gem() == ngt, "VestedRewardsDistribution/invalid-gem");
        require(VestedRewardsDistributionLike(dist).dssVest() == vest, "VestedRewardsDistribution/invalid-dss-vest");
        require(
            VestedRewardsDistributionLike(dist).stakingRewards() == farm,
            "VestedRewardsDistribution/invalid-staking-rewards"
        );

        // Grant minting rights on `ngt` to `vest`.
        RelyLike(ngt).rely(vest);

        // Define global max vesting ratio on `vest`.
        VestInit.init(vest, VestInitParams({cap: vestCap}));

        // Set `dist` with  `rewardsDistribution` role in `farm`.
        StakingRewardsInit.init(farm, StakingRewardsInitParams({dist: dist}));

        // Create the proper vesting stream for rewards distribution.
        uint256 vestId = VestInit.create(
            vest,
            VestCreateParams({usr: dist, tot: vestTot, bgn: vestBgn, tau: vestTau, eta: 0})
        );

        // Set the `vestId` in `dist`
        VestedRewardsDistributionInit.init(dist, VestedRewardsDistributionInitParams({vestId: vestId}));

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "ngt", ngt);
        ScriptTools.exportContract(NAME, "dist", dist);
        ScriptTools.exportContract(NAME, "farm", farm);
        ScriptTools.exportContract(NAME, "vest", vest);
        ScriptTools.exportContract(NAME, "vestId", address(uint160(vestId)));
        ScriptTools.exportContract(NAME, "vestTot", address(uint160(vestTot)));
        ScriptTools.exportContract(NAME, "vestBgn", address(uint160(vestBgn)));
        ScriptTools.exportContract(NAME, "vestTau", address(uint160(vestTau)));
    }
}
