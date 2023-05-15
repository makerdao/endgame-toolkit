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
    function getAmount(
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
contract LinearIncreasingDistribution is DistributionCalc {
    /// @dev The starting rate to start the distribution.
    uint256 public immutable startingRate;

    /**
     * @param _initialRate The initial rate to start the distribution.
     */
    constructor(uint256 _initialRate) {
        startingRate = _initialRate;
    }

    /**
     * @inheritdoc DistributionCalc
     */
    function getAmount(
        uint256 when,
        uint256 prev,
        uint256 tot,
        uint256 fin,
        uint256 clf
    ) external view returns (uint256) {
        uint256 streamDuration = (fin - clf);
        uint256 distributionInterval = (when - prev);
        uint256 divisor = (fin + clf) * streamDuration;

        return
            (((tot - (startingRate * streamDuration)) * ((when + prev) * distributionInterval)) +
                (startingRate * distributionInterval * divisor)) / divisor;
    }
}

/**
 * @title Calculates the reward amount as a constant function.
 * @author amusingaxl
 */
contract ConstantDistribution is DistributionCalc {
    /**
     * @inheritdoc DistributionCalc
     */
    function getAmount(
        uint256 when,
        uint256 prev,
        uint256 tot,
        uint256 fin,
        uint256 clf
    ) external pure returns (uint256) {
        return (tot * (when - prev)) / (fin - clf);
    }
}
