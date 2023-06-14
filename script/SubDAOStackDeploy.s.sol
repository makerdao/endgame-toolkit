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
import {MCD, DssInstance} from "dss-test/MCD.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";

import {ConfigReader, Exports, Imports} from "./helpers/Config.sol";
import {SubProxyDeploy} from "../src/deploy/SubProxyDeploy.sol";
import {SDAODeploy} from "../src/deploy/SDAODeploy.sol";

contract SubDAOStackDeployScript is Script {
    string internal constant NAME_PREFIX = "SubDAO-";

    using stdJson for string;
    using ScriptTools for string;

    string internal config;
    DssInstance internal mcd;

    Imports internal imports;
    Exports internal exports;

    function run() external {
        config = ScriptTools.loadConfig();

        address admin = config.readAddress(".admin");
        string[] memory names = config.readStringArray(".names");
        mcd = MCD.loadFromChainlog(config.readAddress(".chainlog"));

        ConfigReader reader = new ConfigReader(config);

        vm.startBroadcast();

        for (uint256 i = 0; i < names.length; i++) {
            imports = Imports({
                dist: reader.readAddressOptional(string.concat(".imports.", names[i], ".dist")),
                farm: reader.readAddressOptional(string.concat(".imports.", names[i], ".farm")),
                gov: reader.readAddressOptional(string.concat(".imports.", names[i], ".gov")),
                subProxy: reader.readAddressOptional(string.concat(".imports.", names[i], ".subProxy")),
                vest: reader.readAddressOptional(string.concat(".imports.", names[i], ".vest"))
            });

            exports.gov = imports.gov;
            exports.subProxy = imports.subProxy;

            if (imports.subProxy == address(0)) {
                exports.subProxy = SubProxyDeploy.deploy(msg.sender, admin);
            }

            if (imports.gov == address(0)) {
                exports.gov = SDAODeploy.deploy(msg.sender, admin, names[i], names[i]);
            }

            ScriptTools.exportContract(string.concat(NAME_PREFIX, names[i]), "gov", exports.gov);
            ScriptTools.exportContract(string.concat(NAME_PREFIX, names[i]), "subProxy", exports.subProxy);
        }

        vm.stopBroadcast();
    }
}
