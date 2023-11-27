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

import {ScriptTools} from "dss-test/ScriptTools.sol";
import {SubProxy} from "../../src/SubProxy.sol";

struct SubProxyDeployParams {
    address deployer;
    address owner;
}

library SubProxyDeploy {
    function deploy(SubProxyDeployParams memory p) internal returns (address subProxy) {
        subProxy = address(new SubProxy());

        ScriptTools.switchOwner(subProxy, p.deployer, p.owner);
    }
}
