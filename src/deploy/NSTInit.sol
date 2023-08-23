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

import {Nst} from "nst/Nst.sol";

struct NSTInitParams {
    address token;
    address receiver;
    uint256 amount;
}

library NSTInit {
    function init(NSTInitParams memory p) internal {
        if (Nst(p.token).wards(msg.sender) == 1) {
            Nst(p.token).mint(p.receiver, p.amount);
        }
    }
}
