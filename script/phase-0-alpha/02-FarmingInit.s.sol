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
import {FarmingInit, FarmingInitParams} from "../dependencies/phase-0-alpha/FarmingInit.sol";

contract Phase0Alpha_FarmingInitScript is Script {
    string internal constant NAME = "phase-0-alpha/farming-init";

    function run() external {
        Reader deps = new Reader(ScriptTools.loadDependencies());

        address ngt = deps.envOrReadAddress("FOUNDRY_NGT", ".ngt");
        address nst = deps.envOrReadAddress("FOUNDRY_NST", ".nst");
        address dist = deps.envOrReadAddress("FOUNDRY_DIST", ".dist");
        address rewards = deps.envOrReadAddress("FOUNDRY_FARM", ".rewards");
        address vest = deps.envOrReadAddress("FOUNDRY_VEST", ".vest");

        Reader config = new Reader(ScriptTools.loadConfig());

        uint256 vestId = config.readUint(".vestId");

        vm.startBroadcast();

        FarmingInit.init(
            FarmingInitParams({ngt: ngt, nst: nst, dist: dist, rewards: rewards, vest: vest, vestId: vestId})
        );

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "ngt", ngt);
        ScriptTools.exportContract(NAME, "dist", dist);
        ScriptTools.exportContract(NAME, "rewards", rewards);
        ScriptTools.exportContract(NAME, "vest", vest);
        ScriptTools.exportValue(NAME, "vestId", vestId);
    }
}
