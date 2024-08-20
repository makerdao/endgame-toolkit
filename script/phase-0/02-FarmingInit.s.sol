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
import {ScriptTools} from "dss-test/DssTest.sol";

import {Reader} from "../helpers/Reader.sol";
import {FarmingInit, FarmingInitParams, FarmingInitResult} from "../dependencies/phase-0/FarmingInit.sol";
import {VestInit, VestInitParams} from "../dependencies/VestInit.sol";

interface ProxyLike {
    function owner() external view returns (address);

    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

contract FarmingInitSpell {
    function cast(
        FarmingInitParams memory farmingCfg,
        VestInitParams calldata vestInitCfg
    ) public returns (FarmingInitResult memory) {
        VestInit.init(farmingCfg.vest, vestInitCfg);
        return FarmingInit.init(farmingCfg);
    }
}

contract Phase0_FarmingInitScript is Script {
    using ScriptTools for string;

    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    string internal constant NAME = "phase-0/farming-init";

    function run() external {
        Reader config = new Reader(ScriptTools.loadConfig());
        Reader deps = new Reader(ScriptTools.loadDependencies());

        uint256 vestTot = config.envOrReadUint("FOUNDRY_VEST_TOT", ".vestTot");
        uint256 vestBgn = config.envOrReadUint("FOUNDRY_VEST_BGN", ".vestBgn");
        uint256 vestTau = config.envOrReadUint("FOUNDRY_VEST_TAU", ".vestTau");

        address ngt = deps.envOrReadAddress("FOUNDRY_NGT", ".ngt");
        address nst = deps.envOrReadAddress("FOUNDRY_NST", ".nst");
        address dist = deps.envOrReadAddress("FOUNDRY_DIST", ".dist");
        address rewards = deps.envOrReadAddress("FOUNDRY_FARM", ".rewards");
        address vest = deps.envOrReadAddress("FOUNDRY_VEST", ".vest");

        FarmingInitParams memory farmingCfg = FarmingInitParams({
            ngt: ngt,
            nst: nst,
            dist: dist,
            rewards: rewards,
            vest: vest,
            vestTot: vestTot,
            vestBgn: vestBgn,
            vestTau: vestTau
        });

        VestInitParams memory vestInitCfg = VestInitParams({cap: type(uint256).max});

        address pauseProxy = chainlog.getAddress("MCD_PAUSE_PROXY");

        vm.startBroadcast();

        FarmingInitSpell spell = new FarmingInitSpell();
        bytes memory out = ProxyLike(pauseProxy).exec(
            address(spell),
            abi.encodeCall(spell.cast, (farmingCfg, vestInitCfg))
        );

        vm.stopBroadcast();

        FarmingInitResult memory res = abi.decode(out, (FarmingInitResult));

        ScriptTools.exportContract(NAME, "ngt", ngt);
        ScriptTools.exportContract(NAME, "dist", dist);
        ScriptTools.exportContract(NAME, "rewards", rewards);
        ScriptTools.exportContract(NAME, "vest", vest);
        ScriptTools.exportValue(NAME, "vestId", res.vestId);
    }
}

interface ChainlogLike {
    function getAddress(bytes32 _key) external view returns (address addr);
}
