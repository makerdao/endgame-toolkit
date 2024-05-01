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

struct Result {
    address nst;
    address ngt;
    address vest;
}

contract Phase0Alpha_VestAndTokensDeployScript is Script {
    string internal constant NAME = "phase-0-alpha/vest-and-tokens-deploy";

    function run() external returns (Result memory res) {
        vm.startBroadcast();

        res.nst = deployCode("./out/StakingRewards.t.sol:TestToken", abi.encode("NST", 18));
        res.ngt = deployCode("./out/StakingRewards.t.sol:TestToken", abi.encode("NGT", 18));
        res.vest = deployCode("./out/DssVest.sol:DssVestMintable", abi.encode(address(res.ngt)));

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "nst", res.nst);
        ScriptTools.exportContract(NAME, "ngt", res.ngt);
        ScriptTools.exportContract(NAME, "vest", res.vest);
    }
}
