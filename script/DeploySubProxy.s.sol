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
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {SubProxy} from "../src/SubProxy.sol";

contract DeploySubProxy is Script {
    function run() public returns (address) {
        address changelog = vm.envAddress("CHANGELOG");
        address owner = ChangelogLike(changelog).getAddress("MCD_PAUSE_PROXY");
        require(owner != address(0), "Deploy: MCD_PAUSE_PROXY not set");

        vm.startBroadcast();

        SubProxy proxy = new SubProxy();
        // Rely the pause Proxy
        proxy.rely(owner);
        // Deny the deployer
        proxy.deny(msg.sender);

        return address(proxy);
    }
}

interface ChangelogLike {
    function getAddress(bytes32 key) external view returns (address);
}
