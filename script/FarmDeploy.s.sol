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
import {VestedRewardsDistributionDeploy, VestedRewardsDistributionDeployParams} from "./dependencies/VestedRewardsDistributionDeploy.sol";
import {StakingRewardsInit, StakingRewardsInitParams} from "./dependencies/StakingRewardsInit.sol";
import {VestedRewardsDistributionInit, VestedRewardsDistributionInitParams} from "./dependencies/VestedRewardsDistributionInit.sol";
import {VestInit, VestInitParams, VestCreateParams} from "./dependencies/VestInit.sol";

struct Exports {
    address dist;
    address farm;
    address ngt;
    address nst;
    address vest;
    uint256 vestId;
}

struct Imports {
    address dist;
    address farm;
    address ngt;
    address nst;
    address vest;
    uint256 vestTot;
    uint256 vestBgn;
    uint256 vestTau;
    uint256 vestEta;
}

contract FarmDeployScript is Script {
    string internal constant NAME = "Farm";

    using stdJson for string;
    using ScriptTools for string;

    string internal config;

    Imports internal imports;
    Exports internal exports;

    function run() external {
        config = ScriptTools.loadConfig();

        address admin = config.readAddress(".admin");

        ConfigReader reader = new ConfigReader(config);

        imports = Imports({
            dist: reader.readAddressOptional(string.concat(".imports.dist")),
            farm: reader.readAddressOptional(string.concat(".imports.farm")),
            ngt: reader.readAddressOptional(string.concat(".imports.ngt")),
            nst: reader.readAddressOptional(string.concat(".imports.nst")),
            vest: reader.readAddressOptional(string.concat(".imports.vest")),
            vestTot: reader.readUintOptional(string.concat(".imports.vestTot")),
            vestBgn: reader.readUintOptional(string.concat(".imports.vestBgn")),
            vestTau: reader.readUintOptional(string.concat(".imports.vestTau")),
            vestEta: reader.readUintOptional(string.concat(".imports.vestEta"))
        });

        exports.dist = imports.dist;
        exports.ngt = imports.ngt;
        exports.nst = imports.nst;
        exports.vest = imports.vest;

        vm.startBroadcast();

        require(imports.ngt != address(0), "imports.ngt is mandatory");
        require(imports.nst != address(0), "imports.nst is mandatory");

        if (imports.vest == address(0)) {
            exports.vest = deployCode("DssVest.sol:DssVestMintable", abi.encode(exports.ngt));
            VestInit.init(VestInitParams({vest: exports.vest, cap: type(uint256).max}));
        }

        if (imports.farm == address(0)) {
            exports.farm = StakingRewardsDeploy.deploy(
                StakingRewardsDeployParams({owner: admin, stakingToken: exports.nst, rewardsToken: exports.ngt})
            );
        }

        if (imports.dist == address(0)) {
            exports.dist = VestedRewardsDistributionDeploy.deploy(
                VestedRewardsDistributionDeployParams({
                    deployer: msg.sender,
                    owner: admin,
                    vest: exports.vest,
                    farm: exports.farm
                })
            );
        }

        StakingRewardsInit.init(StakingRewardsInitParams({farm: exports.farm, dist: exports.dist}));

        exports.vestId = VestInit
            .create(
                VestCreateParams({
                    vest: exports.vest,
                    usr: exports.dist,
                    tot: imports.vestTot,
                    bgn: imports.vestBgn,
                    tau: imports.vestTau,
                    eta: imports.vestEta
                })
            )
            .vestId;

        VestedRewardsDistributionInit.init(
            VestedRewardsDistributionInitParams({dist: exports.dist, vestId: exports.vestId})
        );

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "dist", exports.dist);
        ScriptTools.exportContract(NAME, "farm", exports.farm);
        ScriptTools.exportContract(NAME, "ngt", exports.ngt);
        ScriptTools.exportContract(NAME, "nst", exports.nst);
        ScriptTools.exportContract(NAME, "vest", exports.vest);
    }
}
