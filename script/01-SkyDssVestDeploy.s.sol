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
import {Reader} from "./helpers/Reader.sol";

contract SkyDssVestDeployScript is Script {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    string internal constant NAME = "sky-dss-vest-deploy";

    function run() external {
        address deployer = msg.sender;
        address admin = chainlog.getAddress("MCD_PAUSE_PROXY");

        Reader reader = new Reader(ScriptTools.loadConfig());
        address sky = reader.envOrReadAddress("FOUNDRY_SKY", ".sky");

        vm.startBroadcast();
        address vest = deployCode("DssVest.sol:DssVestMintable", abi.encode(sky));
        ScriptTools.switchOwner(vest, deployer, admin);
        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "vest", vest);
    }
}

interface ChainlogLike {
    function getAddress(bytes32 _key) external view returns (address addr);
}
