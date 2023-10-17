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
import {FarmingInit, FarmingInitParams} from "../dependencies/phase-0-alpha/FarmingInit.sol";

contract Phase0Alpha_StakingRewardsInitScript is Script {
    string internal constant NAME = "phase-0-alpha/staking-rewards-init";

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

        uint256 vestId = FarmingInit
            .init(
                FarmingInitParams({
                    ngt: ngt,
                    nst: nst,
                    dist: dist,
                    farm: farm,
                    vest: vest,
                    vestCap: vestCap,
                    vestTot: vestTot,
                    vestBgn: vestBgn,
                    vestTau: vestTau
                })
            )
            .vestId;

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
