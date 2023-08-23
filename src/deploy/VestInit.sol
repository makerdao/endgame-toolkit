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
import {DssVestWithGemLike} from "../interfaces/DssVestWithGemLike.sol";

struct VestInitParams {
    address vest;
    address usr;
    uint256 tot;
    uint256 bgn;
    uint256 tau;
    uint256 eta;
}

struct VestInitResult {
    uint256 vestId;
}

library VestInit {
    using ScriptTools for string;

    function init(VestInitParams memory p) internal returns (VestInitResult memory res) {
        res.vestId = DssVestWithGemLike(p.vest).create(
            p.usr,
            p.tot,
            p.bgn,
            p.tau,
            p.eta,
            address(0) // mgr
        );

        DssVestWithGemLike(p.vest).restrict(res.vestId);
    }
}
