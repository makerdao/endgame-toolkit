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

import {ConfigReader} from "./helpers/Config.sol";
import {StakingRewardsDeploy, StakingRewardsDeployParams} from "./dependencies/StakingRewardsDeploy.sol";
import {
    VestedRewardsDistributionDeploy,
    VestedRewardsDistributionDeployParams
} from "./dependencies/VestedRewardsDistributionDeploy.sol";
import {StakingRewardsInit, StakingRewardsInitParams} from "./dependencies/StakingRewardsInit.sol";
import {
    VestedRewardsDistributionInit,
    VestedRewardsDistributionInitParams
} from "./dependencies/VestedRewardsDistributionInit.sol";
import {VestInit, VestInitParams, VestCreateParams} from "./dependencies/VestInit.sol";

contract StakingRewardsDeployScript is Script {
    using stdJson for string;
    using ScriptTools for string;

    string internal constant NAME = "StakingRewards";

    function run() external {
        ConfigReader reader = new ConfigReader(ScriptTools.loadConfig());

        address admin = reader.readAddress(".admin");
        address ngt = reader.readAddress(".ngt");
        address nst = reader.readAddress(".nst");
        address dist = reader.readAddressOptional(".dist");
        address farm = reader.readAddressOptional(".farm");
        address vest = reader.readAddressOptional(".vest");
        uint256 vestTot = reader.readUintOptional(".vestTot");
        uint256 vestBgn = reader.readUintOptional(".vestBgn");
        uint256 vestTau = reader.readUintOptional(".vestTau");

        vm.startBroadcast();

        if (vest == address(0)) {
            vest = deployCode("DssVest.sol:DssVestMintable", abi.encode(ngt));
            VestInit.init(VestInitParams({vest: vest, cap: type(uint256).max}));
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

        StakingRewardsInit.init(StakingRewardsInitParams({farm: farm, dist: dist}));

        uint256 vestId;

        if (vestTot > 0) {
            vestId = VestInit.create(
                VestCreateParams({vest: vest, usr: dist, tot: vestTot, bgn: vestBgn, tau: vestTau, eta: 0})
            );

            VestedRewardsDistributionInit.init(VestedRewardsDistributionInitParams({dist: dist, vestId: vestId}));
        }

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "admin", admin);
        ScriptTools.exportContract(NAME, "dist", dist);
        ScriptTools.exportContract(NAME, "farm", farm);
        ScriptTools.exportContract(NAME, "ngt", ngt);
        ScriptTools.exportContract(NAME, "nst", nst);
        ScriptTools.exportContract(NAME, "vest", vest);
        ScriptTools.exportContract(NAME, "vestId", address(uint160(vestId)));
    }
}
