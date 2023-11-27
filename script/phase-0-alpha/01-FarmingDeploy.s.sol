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
import {StakingRewardsDeploy, StakingRewardsDeployParams} from "../dependencies/StakingRewardsDeploy.sol";
import {
    VestedRewardsDistributionDeploy,
    VestedRewardsDistributionDeployParams
} from "../dependencies/VestedRewardsDistributionDeploy.sol";

contract Phase0Alpha_FarmingDeployScript is Script {
    string internal constant NAME = "phase-0-alpha/farming-deploy";

    function run() external {
        Reader reader = new Reader(ScriptTools.loadConfig());

        address admin = reader.envOrReadAddress("FOUNDRY_ADMIN", ".admin");
        address ngt = reader.envOrReadAddress("FOUNDRY_NGT", ".ngt");
        address nst = reader.envOrReadAddress("FOUNDRY_NST", ".nst");
        address vest = reader.envOrReadAddress("FOUNDRY_VEST", ".vest");
        address dist = reader.readAddressOptional(".dist");
        address rewards = reader.readAddressOptional(".rewards");

        vm.startBroadcast();

        if (rewards == address(0)) {
            rewards = StakingRewardsDeploy.deploy(
                StakingRewardsDeployParams({owner: admin, stakingToken: nst, rewardsToken: ngt})
            );
        }

        if (dist == address(0)) {
            dist = VestedRewardsDistributionDeploy.deploy(
                VestedRewardsDistributionDeployParams({
                    deployer: msg.sender,
                    owner: admin,
                    vest: vest,
                    rewards: rewards
                })
            );
        }

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "admin", admin);
        ScriptTools.exportContract(NAME, "ngt", ngt);
        ScriptTools.exportContract(NAME, "nst", nst);
        ScriptTools.exportContract(NAME, "dist", dist);
        ScriptTools.exportContract(NAME, "rewards", rewards);
        ScriptTools.exportContract(NAME, "vest", vest);
    }
}
