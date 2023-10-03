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

interface StakingRewardsLike {
    function setRewardsDistribution(address _rewardsDistribution) external;

    function acceptOwnership() external;

    function nominateNewOwner(address _owner) external;
}

struct StakingRewardsInitParams {
    address dist;
}

struct StakingRewardsNominateNewOwnerParams {
    address newOwner;
}

library StakingRewardsInit {
    function init(address farm, StakingRewardsInitParams memory p) internal {
        StakingRewardsLike(farm).setRewardsDistribution(p.dist);
    }

    /// @dev `StakingRewards` ownership transfer is a 2-step process: nominate + acceptance.
    function nominateNewOwner(address farm, StakingRewardsNominateNewOwnerParams memory p) internal {
        StakingRewardsLike(farm).nominateNewOwner(p.newOwner);
    }

    /// @dev `StakingRewards` ownership transfer requires the new owner to explicitly accept it.
    function acceptOwnership(address farm) internal {
        StakingRewardsLike(farm).acceptOwnership();
    }
}
