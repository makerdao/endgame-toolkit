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
import {Nst01PreFarmingInit, Nst01PreFarmingInitParams} from "../dependencies/phase-1b/Nst01PreFarmingInit.sol";

interface ProxyLike {
    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

contract Nst01PreFarmingInitSpell {
    function cast(Nst01PreFarmingInitParams memory farmingCfg) public {
        Nst01PreFarmingInit.init(farmingCfg);
    }
}

contract Phase1b_Nst01PreFarmingInitScript is Script {
    using ScriptTools for string;

    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    string internal constant NAME = "phase-1b/nst-01-pre-farming-init";

    function run() external {
        Reader deps = new Reader(ScriptTools.loadDependencies());

        address nst = deps.envOrReadAddress("FOUNDRY_NST", ".nst");
        address rewards = deps.envOrReadAddress("FOUNDRY_REWARDS", ".rewards");

        Nst01PreFarmingInitParams memory farmingCfg = Nst01PreFarmingInitParams({
            nst: nst,
            rewards: rewards,
            rewardsKey: "FARM_NST_01"
        });

        address pauseProxy = chainlog.getAddress("MCD_PAUSE_PROXY");

        vm.startBroadcast();

        Nst01PreFarmingInitSpell spell = new Nst01PreFarmingInitSpell();
        ProxyLike(pauseProxy).exec(address(spell), abi.encodeCall(spell.cast, (farmingCfg)));

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "nst", nst);
        ScriptTools.exportContract(NAME, "rewards", rewards);
    }
}

interface ChainlogLike {
    function getAddress(bytes32 _key) external view returns (address addr);
}
