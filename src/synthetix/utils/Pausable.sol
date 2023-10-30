/**
 * NOTICE: This contract has been adapted from the original Synthetix source code:
 *  - Upgrade Solidity version from 0.5.x to 0.8.x.
 *
 * Original: https://github.com/Synthetixio/synthetix/blob/5e9096ac4aea6c4249828f1e8b95e3fb9be231f8/contracts/Pausable.sol
 *     Diff: https://www.diffchecker.com/ZxqWAZxN/
 */

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

// Inheritance
import {Owned} from "./Owned.sol";

// https://developer.synthetix.io/contracts/source/contracts/Pausable/
abstract contract Pausable is Owned {
    uint public lastPauseTime;
    bool public paused;

    constructor(address _owner) Owned(_owner) {}

    /**
     * @notice Change the paused state of the contract
     * @dev Only the contract owner may call this.
     */
    function setPaused(bool _paused) external onlyOwner {
        // Ensure we're actually changing the state before we do anything
        if (_paused == paused) {
            return;
        }

        // Set our paused state.
        paused = _paused;

        // If applicable, set the last pause time.
        if (paused) {
            lastPauseTime = block.timestamp;
        }

        // Let everyone know that our pause state has changed.
        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused() {
        require(!paused, "This action cannot be performed while the contract is paused");
        _;
    }
}
