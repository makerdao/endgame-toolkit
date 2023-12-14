// SPDX-FileCopyrightText: © 2019-2021 Synthetix
// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: MIT AND AGPL-3.0-or-later
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

import {IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

// https://docs.synthetix.io/contracts/source/interfaces/istakingrewards
interface IStakingRewards {
    // Views

    function balanceOf(address account) external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function getRewardForDuration() external view returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function rewardsDistribution() external view returns (address);

    function rewardsToken() external view returns (IERC20);

    function stakingToken() external view returns (IERC20);

    function totalSupply() external view returns (uint256);

    // Mutative

    function exit() external;

    function getReward() external;

    function stake(uint256 amount) external;

    function stake(uint256 amount, uint16 referral) external;

    function withdraw(uint256 amount) external;

    function notifyRewardAmount(uint256 reward) external;

    function setRewardsDistribution(address _rewardsDistribution) external;

    function setRewardsDuration(uint256 _rewardsDuration) external;

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
}
