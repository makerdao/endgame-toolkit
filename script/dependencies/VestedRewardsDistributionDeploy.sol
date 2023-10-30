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
import {VestedRewardsDistribution} from "../../src/VestedRewardsDistribution.sol";

struct VestedRewardsDistributionDeployParams {
    address deployer;
    address owner;
    address vest;
    address rewards;
}

library VestedRewardsDistributionDeploy {
    function deploy(VestedRewardsDistributionDeployParams memory p) internal returns (address dist) {
        dist = address(new VestedRewardsDistribution(p.vest, p.rewards));

        ScriptTools.switchOwner(dist, p.deployer, p.owner);
    }
}
