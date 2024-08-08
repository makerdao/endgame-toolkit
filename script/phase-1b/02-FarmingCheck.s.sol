// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
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

import {Script} from "forge-std/Script.sol";
import {Reader} from "../helpers/Reader.sol";

contract Phase1b_FarmingCheckScript is Script {
    function run() external returns (bool) {
        Reader deps = new Reader("");
        deps.loadDependenciesOrConfig();

        address nst = deps.envOrReadAddress("FOUNDRY_NST", ".nst");
        address admin = deps.readAddress(".admin");
        address rewards = deps.readAddress(".rewards");

        require(StakingRewardsLike(rewards).owner() == admin, "StakingRewards/admin-not-owner");
        require(StakingRewardsLike(rewards).rewardsToken() == address(0), "StakingRewards/invalid-rewards-token");
        require(StakingRewardsLike(rewards).stakingToken() == nst, "StakingRewards/invalid-rewards-token");
        require(
            StakingRewardsLike(rewards).rewardsDistribution() == address(0),
            "StakingRewards/invalid-rewards-distribution"
        );

        return true;
    }
}

interface StakingRewardsLike {
    function owner() external view returns (address);

    function stakingToken() external view returns (address);

    function rewardsToken() external view returns (address);

    function rewardsDistribution() external view returns (address);
}