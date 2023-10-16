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
import {ScriptTools} from "dss-test/ScriptTools.sol";

import {Reader} from "../helpers/Reader.sol";
import {StakingRewardsDeploy, StakingRewardsDeployParams} from "../dependencies/StakingRewardsDeploy.sol";
import {
    VestedRewardsDistributionDeploy,
    VestedRewardsDistributionDeployParams
} from "../dependencies/VestedRewardsDistributionDeploy.sol";

contract Phase0Alpha_StakingRewardsDeployScript is Script {
    string internal constant NAME = "phase-0-alpha/staking-rewards-deploy";

    function run() external {
        Reader reader = new Reader(ScriptTools.loadConfig());

        address admin = reader.envOrReadAddress(".admin", "FOUNDRY_ADMIN");
        address ngt = reader.envOrReadAddress(".ngt", "FOUNDRY_NGT");
        address nst = reader.envOrReadAddress(".nst", "FOUNDRY_NST");
        address dist = reader.readAddressOptional(".dist");
        address farm = reader.readAddressOptional(".farm");
        address vest = reader.readAddressOptional(".vest");

        vm.startBroadcast();

        if (vest == address(0)) {
            vest = deployCode("DssVest.sol:DssVestMintable", abi.encode(ngt));
            ScriptTools.switchOwner(vest, msg.sender, admin);
        }

        if (farm == address(0)) {
            farm = StakingRewardsDeploy.deploy(
                StakingRewardsDeployParams({owner: admin, stakingToken: nst, rewardsToken: ngt})
            );
        }

        if (dist == address(0)) {
            dist = VestedRewardsDistributionDeploy.deploy(
                VestedRewardsDistributionDeployParams({deployer: msg.sender, owner: admin, vest: vest, farm: farm})
            );
        }

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "admin", admin);
        ScriptTools.exportContract(NAME, "ngt", ngt);
        ScriptTools.exportContract(NAME, "nst", nst);
        ScriptTools.exportContract(NAME, "dist", dist);
        ScriptTools.exportContract(NAME, "farm", farm);
        ScriptTools.exportContract(NAME, "vest", vest);
    }
}
