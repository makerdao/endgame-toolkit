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
import {
    Nst$PlaceholderPreFarmingInit,
    Nst$PlaceholderPreFarmingInitParams
} from "../dependencies/phase-1b/Nst$PlaceholderPreFarmingInit.sol";

interface ProxyLike {
    function owner() external view returns (address);

    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

contract Nst$PlaceholderPreFarmingInitSpell {
    function cast(Nst$PlaceholderPreFarmingInitParams memory farmingCfg) public {
        Nst$PlaceholderPreFarmingInit.init(farmingCfg);
    }
}

contract Phase1b_Nst$PlaceholderPreFarmingInitScript is Script {
    using ScriptTools for string;

    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    string internal constant NAME = "phase-1b/nst-$placeholder-pre-farming-init";

    function run() external {
        Reader deps = new Reader(ScriptTools.loadDependencies());

        address nst = deps.envOrReadAddress("FOUNDRY_NST", ".nst");
        address rewards = deps.envOrReadAddress("FOUNDRY_REWARDS", ".rewards");

        Nst$PlaceholderPreFarmingInitParams memory farmingCfg = Nst$PlaceholderPreFarmingInitParams({
            nst: nst,
            rewards: rewards,
            rewardsKey: "FARM_NST_$PLACEHOLDER"
        });

        address pauseProxy = chainlog.getAddress("MCD_PAUSE_PROXY");

        vm.startBroadcast();

        Nst$PlaceholderPreFarmingInitSpell spell = new Nst$PlaceholderPreFarmingInitSpell();
        ProxyLike(pauseProxy).exec(address(spell), abi.encodeCall(spell.cast, (farmingCfg)));

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "nst", nst);
        ScriptTools.exportContract(NAME, "rewards", rewards);
    }
}

interface ChainlogLike {
    function getAddress(bytes32 _key) external view returns (address addr);
}
