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

import {StakingRewardsInit, StakingRewardsInitParams} from "../StakingRewardsInit.sol";
import {VestedRewardsDistributionInit, VestedRewardsDistributionInitParams} from "../VestedRewardsDistributionInit.sol";
import {VestInit, VestCreateParams} from "../VestInit.sol";

struct FarmingInitParams {
    address nst;
    address ngt;
    address rewards;
    address dist;
    address vest;
    uint256 vestTot;
    uint256 vestBgn;
    uint256 vestTau;
}

struct FarmingInitResult {
    uint256 vestId;
}

library FarmingInit {
    function init(FarmingInitParams memory p) internal returns (FarmingInitResult memory r) {
        address stakingToken = StakingRewardsLike(p.rewards).stakingToken();
        address rewardsToken = StakingRewardsLike(p.rewards).rewardsToken();

        require(stakingToken != rewardsToken, "FarmingInit/rewards-token-same-as-staking-token");

        require(DssVestWithGemLike(p.vest).gem() == p.ngt, "FarmingInit/vest-gem-mismatch");

        require(stakingToken == p.nst, "FarmingInit/rewards-staking-token-mismatch");
        require(rewardsToken == p.ngt, "FarmingInit/rewards-rewards-token-mismatch");
        require(StakingRewardsLike(p.rewards).lastUpdateTime() == 0, "FarmingInit/rewards-last-update-time-invalid");

        require(VestedRewardsDistributionLike(p.dist).gem() == p.ngt, "FarmingInit/dist-gem-mismatch");
        require(VestedRewardsDistributionLike(p.dist).dssVest() == p.vest, "FarmingInit/dist-dss-vest-mismatch");
        require(
            VestedRewardsDistributionLike(p.dist).stakingRewards() == p.rewards,
            "FarmingInit/dist-staking-rewards-mismatch"
        );

        // `vest` is expected to be an instance of `DssVestMintable`.
        // Check if minting rights on `ngt` were granted to `vest`.
        require(WardsLike(p.ngt).wards(p.vest) == 1, "FarmingInit/missing-ngt-rely-vest");

        // Set `dist` with  `rewardsDistribution` role in `rewards`.
        StakingRewardsInit.init(p.rewards, StakingRewardsInitParams({dist: p.dist}));

        // Create the proper vesting stream for rewards distribution.
        uint256 vestId = VestInit.create(
            p.vest,
            VestCreateParams({usr: p.dist, tot: p.vestTot, bgn: p.vestBgn, tau: p.vestTau, eta: 0})
        );

        // Set the `vestId` in `dist`
        VestedRewardsDistributionInit.init(p.dist, VestedRewardsDistributionInitParams({vestId: vestId}));

        r.vestId = vestId;
    }
}

interface WardsLike {
    function wards(address who) external view returns (uint256);
}

interface DssVestWithGemLike {
    function gem() external view returns (address);
}

interface StakingRewardsLike {
    function lastUpdateTime() external view returns (uint256);

    function rewardsToken() external view returns (address);

    function stakingToken() external view returns (address);
}

interface VestedRewardsDistributionLike {
    function dssVest() external view returns (address);

    function gem() external view returns (address);

    function stakingRewards() external view returns (address);
}
