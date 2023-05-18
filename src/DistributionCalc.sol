// SPDX-FileCopyrightText: © 2017, 2018, 2019 dbrock, rain, mrchico
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
pragma solidity 0.8.19;

/**
 * @title Calculates the distribution amount given distribution and vesting parameters.
 * @author amusingaxl
 */
interface DistributionCalc {
    /**
     * @notice Gets the amount to be distributed from a vesting stream.
     * @param when The time when the distribution should be made.
     * @param prev The time when the last distribution was made.
     * @param tot The total amount of the vesting stream.
     * @param fin The time when the the vesting stream ends.
     * @param clf The time when the cliff of the vesting stream ends.
     * @return The amount to be distributed.
     */
    function getMaxAmount(
        uint256 when,
        uint256 prev,
        uint256 tot,
        uint256 fin,
        uint256 clf
    ) external view returns (uint256);
}

/**
 * @title Calculates the reward amount from a linear function with a positive slope.
 * @author amusingaxl
 */
contract LinearRampUp is DistributionCalc {
    /// @dev The starting rate of the the distribution.
    uint256 public immutable startingRate;

    /**
     * @param _startingRate The starting rate of the distribution.
     */
    constructor(uint256 _startingRate) {
        startingRate = _startingRate;
    }

    /**
     * @inheritdoc DistributionCalc
     */
    function getMaxAmount(
        uint256 when,
        uint256 prev,
        uint256 tot,
        uint256 fin,
        uint256 clf
    ) external view returns (uint256) {
        uint256 duration = fin - clf;
        uint256 interval = when - prev;
        uint256 divisor = duration ** 2;

        return
            ((tot - startingRate * duration) *
                ((when - clf) ** 2 - (prev - clf) ** 2) +
                (startingRate * interval * divisor)) / (divisor);
    }
}
