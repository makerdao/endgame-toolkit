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

import {ScriptTools} from "dss-test/ScriptTools.sol";
import {SubProxy} from "../SubProxy.sol";
import {DssInstance, MCD} from "dss-test/MCD.sol";

library SubProxyInit {
    using ScriptTools for string;

    function init(address chainlog, address subProxy, string memory name) internal {
        DssInstance memory mcd = MCD.loadFromChainlog(chainlog);
        init(mcd, subProxy, name);
    }

    function init(DssInstance memory mcd, address subProxy, string memory name) internal {
        // Rely on `MCD_END` to allow `deny`ing `MCD_PAUSE_PROXY` after Emergency Shutdown.
        SubProxy(subProxy).rely(address(mcd.end));
        // Add `SUBPROXY_{NAME}` to the chainlog.
        mcd.chainlog.setAddress(string.concat("SUBPROXY_", name).stringToBytes32(), subProxy);
    }
}
