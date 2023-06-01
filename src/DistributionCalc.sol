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
     * @dev Here is a summary of the mathematical model behind the formula in the code.
     *
     * A linear ramp-up distribution looks like the following chart:
     *
     * ```
     *   rate
     *
     *     ┤                                                         ╭─────────+
     *     ┤                                              ╭──────────╯         |
     *     ┤                                    ╭─────────╯                    |
     *     ┤                         ╭──────────╯                              |
     *     ┤               ╭─────────╯                                         |
     *   s ┤- - - - - -+───╯                                                   |
     *     ┤           |                                                       |
     *     ┤           |                                                       |
     *     ┤           |                                                       |
     *     ┼───────────+───────────────────────────────────────────────────────+─ time
     *                clf                                                     fin
     * ```
     *
     * A `DssVest` stream can be represented like:
     *
     * ```
     *   rate
     *
     *     ┤
     *     ┤
     *     ┤
     *   r ┤- - - - - -+───────────────────────────────────────────────────────+
     *     ┤           |                                                       |
     *     ┤           |                                                       |
     *     ┤           |                         tot                           |
     *     ┤           |                                                       |
     *     ┤           |                                                       |
     *     ┼───────────+───────────────────────────────────────────────────────+─ time
     *             bgn = clf                                                  fin
     * ```
     *
     * To make sure the total vested amount `tot` is distributed by the end of the period, we must ensure that:
     *
     * ```
     *       _                        _
     *      /  fin  -  clf           /  fin - clf
     *      |              r dt  =   |            kt  +  s dt
     *     _/  0                    _/  0
     * ```
     *
     * Where:
     * - `clf` is the vesting cliff timestamp
     * - `bgn` is the vesting beginning timestamp
     * - `fin` is the vesting final timestamp
     * - `r` is the vesting rate
     * - `k` is the current distribution rate linear factor
     * - `s` is the starting distribution rate
     *
     * Expanding the integrals above, we have:
     *
     * ```
     *                          2
     *           k (fin  -  clf)
     *     tot = ----------------  +  s(fin  -  clf)
     *                   2
     * ```
     *
     * Where:
     * - `tot = r(fin - bgn)` is the total amount vested.
     *
     * Isolating `k` above:
     *
     * ```
     *           2 [tot  -  s(fin  -  clf)]
     *     k  =  --------------------------
     *                             2
     *                (fin  -  clf)
     * ```
     *
     * Now we can define the amount distributed `r` at any interval in time `]prev, when]` can be given by:
     *
     * ```
     *                        _                               _
     *                       /  when - clf                   /  prev - clf
     *     r(prev,when)  =   |              kt  +  s dt  -   |              kt  +  s dt
     *                      _/  0                           _/  0
     *                        _                                        _       _                                      _
     *                       |  1                2                      |     |  1              2                      |
     *     r(prev, when)  =  |  - k(when  -  clf)   +  s(when  -  clf)  |  -  |  - k(prev - clf)   +  s(prev  -  clf)  |
     *                       |_ 2                                      _|     |_ 2                                    _|
     * ```
     *
     *
     * Substituting `k` from above and transforming the expression, we can define the max amount to be distributed
     * between `when` and `prev` as:
     *
     * ```
     *     r(prev, when)  =  tot - s(fin  -  clf)                2                   2
     *                       -------------------- [(when  -  clf)   -  (prev  -  clf)  ]  +  s(when  -  prev)
     *                                       2
     *                          (fin  -  clf)
     * ```
     *
     * We need to tweak the expression above to have divisions as the last step to avoid rounding errors in Solidity:
     *
     * ```
     *                                                                 2                   2                                      2
     *                       [ tot  -  s(fin  -  clf) ] [(when  -  clf)   -  (prev  -  clf)  ]  +  s (when  -  prev) (fin  -  clf)
     *     r(prev, when)  =  ------------------------------------------------------------------------------------------------------
     *                                                                                2
     *                                                                   (fin  -  clf)
     * ```
     *
     * ---
     *
     * Now lets consider that a linear ramp-up distribution can be split into 2 parts:
     *
     * ```
     *   rate
     *
     *     ┤                                                         ╭─────────+
     *     ┤                                              ╭──────────╯OOOOOOOOO|
     *     ┤                                    ╭─────────╯OOOOOOOOOOOOOOOOOOOO|
     *     ┤                         ╭──────────╯OOOOOOOOOOOOOOOOOOOOOOOOOOOOOO|
     *     ┤               ╭─────────╯OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO|
     *   s ┤- - - - - -+───╯OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO|
     *     ┤           |XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX|
     *     ┤           |XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX|
     *     ┤           |XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX|
     *     ┼───────────+───────────────────────────────────────────────────────+── time
     *                clf                                                     fin
     *                  \______________________________________________________/
     *                                           v
     *                                        duration
     * ```
     *
     * From the chart above:
     * - `constantAcc` is the area hatched with "X", given by `s * duration`.
     * - `linearAcc` is the area hatched with "O".
     * - `tot` is the total amount to be distributed, given by `constantAcc + linearAcc`.
     *
     * Notice that in order for the distribution to be possible, the following condition must hold true:
     *
     * ```
     *     tot >= constantAcc
     * ```
     *
     * Otherwise the linear coeficient of the distribution would have to be negative. When this happens, it most likely
     * means that the total vesting amount was not properly set.
     *
     * In the special case where `tot == constantAcc`, the linear ramp-up distribution degrades into a constant
     * distribution with rate `s`.
     */
    function getMaxAmount(
        uint256 when,
        uint256 prev,
        uint256 tot,
        uint256 fin,
        uint256 clf
    ) external view returns (uint256) {
        uint256 duration = fin - clf;
        uint256 constantAcc = startingRate * duration;
        require(tot >= constantAcc, "LinearRampUp/total-vesting-too-low");

        uint256 interval = when - prev;
        uint256 divisor = duration ** 2;
        uint256 linearAcc;
        unchecked {
            // This is guaranteed to not overflow due to the require statement above.
            linearAcc = tot - constantAcc;
        }

        return (linearAcc * ((when - clf) ** 2 - (prev - clf) ** 2) + (startingRate * interval * divisor)) / divisor;
    }
}
