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

struct FarmingInitParams {
    address nst;
    address ngt;
    address rewards;
    address dist;
    address vest;
    uint256 vestId;
}

library FarmingInit {
    function init(FarmingInitParams memory p) internal {
        address stakingToken = StakingRewardsLike(p.rewards).stakingToken();
        address rewardsToken = StakingRewardsLike(p.rewards).rewardsToken();

        require(stakingToken != rewardsToken, "FarmingInit/rewards-token-same-as-staking-token");

        require(DssVestWithGemLike(p.vest).gem() == p.ngt, "FarmingInit/vest-gem-mismatch");
        require(DssVestWithGemLike(p.vest).valid(p.vestId), "FarmingInit/vest-invalid-id");
        require(DssVestWithGemLike(p.vest).usr(p.vestId) == p.dist, "FarmingInit/vest-invalid-usr");
        require(DssVestWithGemLike(p.vest).res(p.vestId) == 1, "FarmingInit/vest-not-restricted");
        require(DssVestWithGemLike(p.vest).mgr(p.vestId) == address(0), "FarmingInit/vest-invalid-mgr");
        require(
            DssVestWithGemLike(p.vest).bgn(p.vestId) == DssVestWithGemLike(p.vest).clf(p.vestId),
            "FarmingInit/vest-bgn-clf-mismatch"
        );

        require(stakingToken == p.nst, "FarmingInit/rewards-staking-token-mismatch");
        require(rewardsToken == p.ngt, "FarmingInit/rewards-rewards-token-mismatch");
        require(StakingRewardsLike(p.rewards).lastUpdateTime() == 0, "FarmingInit/rewards-last-update-time-invalid");

        require(VestedRewardsDistributionLike(p.dist).gem() == p.ngt, "FarmingInit/dist-gem-mismatch");
        require(VestedRewardsDistributionLike(p.dist).dssVest() == p.vest, "FarmingInit/dist-dss-vest-mismatch");
        require(
            VestedRewardsDistributionLike(p.dist).stakingRewards() == p.rewards,
            "FarmingInit/dist-staking-rewards-mismatch"
        );

        require(WardsLike(p.ngt).wards(p.vest) == 1, "FarmingInit/missing-ngt-rely-vest");

        // Set `dist` with  `rewardsDistribution` role in `rewards`.
        StakingRewardsInit.init(p.rewards, StakingRewardsInitParams({dist: p.dist}));

        // Set the `vestId` in `dist`
        VestedRewardsDistributionInit.init(p.dist, VestedRewardsDistributionInitParams({vestId: p.vestId}));
    }
}

interface WardsLike {
    function wards(address usr) external view returns (uint256);
}

interface DssVestWithGemLike {
    function gem() external view returns (address);

    function bgn(uint256 vestId) external view returns (uint256);

    function clf(uint256 vestId) external view returns (uint256);

    function mgr(uint256 vestId) external view returns (address);

    function res(uint256 vestId) external view returns (uint256);

    function usr(uint256 vestId) external view returns (address);

    function valid(uint256 vestId) external view returns (bool);
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
