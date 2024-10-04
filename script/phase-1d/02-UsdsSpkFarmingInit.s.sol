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
    UsdsSpkFarmingInit,
    UsdsSpkFarmingInitParams,
    UsdsSpkFarmingInitResult
} from "../dependencies/phase-1d/UsdsSpkFarmingInit.sol";

contract Phase1d_UsdsSpkFarmingInitScript is Script {
    using ScriptTools for string;

    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    string internal constant NAME = "phase-1d/usds-spk-farming-init";

    function run() external {
        Reader config = new Reader(ScriptTools.loadConfig());
        Reader deps = new Reader(ScriptTools.loadDependencies());

        uint256 vestTot = config.envOrReadUint("FOUNDRY_VEST_TOT", ".vestTot");
        uint256 vestBgn = config.envOrReadUint("FOUNDRY_VEST_BGN", ".vestBgn");
        uint256 vestTau = config.envOrReadUint("FOUNDRY_VEST_TAU", ".vestTau");

        address usds = deps.envOrReadAddress("FOUNDRY_USDS", ".usds");
        address spk = deps.envOrReadAddress("FOUNDRY_SPK", ".spk");
        address dist = deps.envOrReadAddress("FOUNDRY_DIST", ".dist");
        address rewards = deps.envOrReadAddress("FOUNDRY_FARM", ".rewards");
        address vest = deps.envOrReadAddress("FOUNDRY_VEST", ".vest");

        UsdsSpkFarmingInitParams memory farmingCfg = UsdsSpkFarmingInitParams({
            spk: spk,
            usds: usds,
            dist: dist,
            distKey: "REWARDS_DISTRIBUTION_USDS_SPK",
            rewards: rewards,
            rewardsKey: "FARM_USDS_SPK",
            vest: vest,
            vestTot: vestTot,
            vestBgn: vestBgn,
            vestTau: vestTau
        });

        address pauseProxy = chainlog.getAddress("MCD_PAUSE_PROXY");

        vm.startBroadcast();

        UsdsSpkFarmingInitSpell spell = new UsdsSpkFarmingInitSpell();
        bytes memory out = ProxyLike(pauseProxy).exec(address(spell), abi.encodeCall(spell.cast, (farmingCfg)));

        vm.stopBroadcast();

        UsdsSpkFarmingInitResult memory res = abi.decode(out, (UsdsSpkFarmingInitResult));

        ScriptTools.exportContract(NAME, "spk", spk);
        ScriptTools.exportContract(NAME, "dist", dist);
        ScriptTools.exportContract(NAME, "rewards", rewards);
        ScriptTools.exportContract(NAME, "vest", vest);
        ScriptTools.exportValue(NAME, "vestId", res.vestId);
    }
}

contract UsdsSpkFarmingInitSpell {
    uint256 internal constant CAP = type(uint256).max;

    function cast(UsdsSpkFarmingInitParams memory farmingCfg) public returns (UsdsSpkFarmingInitResult memory) {
        DssVestLike(farmingCfg.vest).file("cap", CAP);
        return UsdsSpkFarmingInit.init(farmingCfg);
    }
}

interface ProxyLike {
    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

interface ChainlogLike {
    function getAddress(bytes32 _key) external view returns (address addr);
}

interface DssVestLike {
    function file(bytes32 _what, uint256 _data) external;
}
