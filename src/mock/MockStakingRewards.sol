// SPDX-FileCopyrightText: © 2017, 2018, 2019 dbrock, rain, mrchico
// SPDX-FileCopyrightText: © 2023 SDAO Foundation <www.sdaofoundation.org>
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

import {StakingRewardsLike} from "../interfaces/StakingRewardsLike.sol";

contract MockStakingRewards is StakingRewardsLike {
    address public rewardsToken;
    uint256 public lastUpdateTime;
    uint256 public rewardsDuration;

    event RewardAdded(uint256 reward);

    constructor(address _rewardsToken, uint256 _rewardsDuration) {
        rewardsToken = _rewardsToken;
        rewardsDuration = _rewardsDuration;
        lastUpdateTime = block.timestamp;
    }

    function notifyRewardAmount(uint256 amt) external {
        lastUpdateTime = block.timestamp;

        emit RewardAdded(amt);
    }
}
