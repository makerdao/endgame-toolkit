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
pragma solidity ^0.8.16;

interface DssVestWithGemLike {
    function valid(uint256 _id) external view returns (bool);

    function usr(uint256 id) external view returns (address);

    function bgn(uint256 id) external view returns (uint256);

    function clf(uint256 id) external view returns (uint256);

    function fin(uint256 id) external view returns (uint256);

    function mgr(uint256 id) external view returns (address);

    function res(uint256 id) external view returns (uint256);

    function tot(uint256 id) external view returns (uint256);

    function rxd(uint256 id) external view returns (uint256);

    function accrued(uint256 id) external view returns (uint256);

    function unpaid(uint256 _id) external view returns (uint256);

    // @dev This function is not part of the DssVest interface, it's only present in the concrete implementations
    // DssVestMintable and DssVestTransferable.
    function gem() external view returns (address);

    function rely(address who) external;

    function deny(address who) external;

    function file(bytes32 what, uint256 data) external;

    function create(
        address _usr,
        uint256 _tot,
        uint256 _bgn,
        uint256 _tau,
        uint256 _eta,
        address _mgr
    ) external returns (uint256 id);

    function restrict(uint256 _id) external;

    function unrestrict(uint256 _id) external;

    function vest(uint256 id) external;

    function vest(uint256 id, uint256 _maxAmt) external;
}
