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
pragma solidity =0.8.19;

import {DistributionCalc} from "./DistributionCalc.sol";

interface StakingRewardsLike {
    function rewardsToken() external view returns (address);

    function lastUpdateTime() external view returns (uint256);

    function rewardsDuration() external view returns (uint256);

    function notifyRewardAmount(uint256 amt) external;
}

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

    function vest(uint256 id) external;

    function vest(uint256 id, uint256 _maxAmt) external;
}

contract RewardsDistribution {
    /// @notice Addresses with owner access on this contract. `wards[usr]`
    mapping(address => uint256) public wards;

    /// @notice DssVest instance for token rewards.
    DssVestWithGemLike public immutable dssVest;
    /// @notice StakingRewards instance to enable farming.
    StakingRewardsLike public immutable stakingRewards;

    /// @notice Distribution calculation strategy.
    DistributionCalc public calc;

    /// @dev Vest IDs are sequential. Realistically a DssVest instance will never 2**256 - 1 vests created.
    uint256 internal constant INVALID_VEST_ID = type(uint256).max;
    /// @notice The vest ID managed by this contract.
    /// @dev It is initialized to an invalid value to prevent calls before the vest ID being set.
    /// The reason this is not a required constructor parameter is that there is a circular dependency
    /// between this contract and the creation of the vest: the address of this contract must be the vest `mgr`.
    uint256 public vestId = INVALID_VEST_ID;

    /**
     * @dev `usr` was granted owner access.
     * @param usr The user address.
     */
    event Rely(address indexed usr);
    /**
     * @notice `usr` owner access was revoked.
     * @param usr The user address.
     */
    event Deny(address indexed usr);
    /**
     * @notice A contract parameter was updated.
     * @param what The changed parameter name. Currently the supported values are: "vestID"
     * @param data The new value of the parameter.
     */
    event File(bytes32 indexed what, uint256 data);
    /**
     * @notice A contract parameter was updated.
     * @param what The changed parameter name. Currently the supported values are: "calc"
     * @param data The new value of the parameter.
     */
    event File(bytes32 indexed what, address data);
    /**
     * @notice A distribution of tokens was made.
     * @param amount The total tokens in the current distribution.
     */
    event Distribute(uint256 amount);

    modifier auth() {
        require(wards[msg.sender] == 1, "RewardsDistribution/not-authorized");
        _;
    }

    /**
     * @dev The token `gem` used in DssVest must be the same as `rewardsToken` in StakingRewards.
     * @param _dssVest The DssVest instance as the source of the funds.
     * @param _stakingRewards The farming contract.
     * @param _calc The contract the function to calculate how the rewards distribution must be done.
     */
    constructor(address _dssVest, address _stakingRewards, address _calc) {
        require(
            DssVestWithGemLike(_dssVest).gem() == StakingRewardsLike(_stakingRewards).rewardsToken(),
            "RewardsDistribution/invalid-gem"
        );

        dssVest = DssVestWithGemLike(_dssVest);
        stakingRewards = StakingRewardsLike(_stakingRewards);

        calc = DistributionCalc(_calc);
        emit File("calc", _calc);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Administration ---

    /**
     * @notice Grants `usr` admin access to this contract.
     * @param usr The user address.
     */
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    /**
     * @notice Revokes `usr` admin access from this contract.
     * @param usr The user address.
     */
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    /**
     * @notice Updates a contract parameter.
     * @param what The changed parameter name. `"vestId"
     * @param data The new value of the parameter.
     */
    function file(bytes32 what, uint256 data) external auth {
        if (what == "vestId") {
            setVestId(data);
        } else {
            revert("RewardsDistribution/file-unrecognized-param");
        }

        emit File(what, data);
    }

    /**
     * @notice Updates a contract parameter.
     * @param what The changed parameter name. `"calc"
     * @param data The new value of the parameter.
     */
    function file(bytes32 what, address data) external auth {
        if (what == "calc") {
            setCalc(data);
        } else {
            revert("RewardsDistribution/file-unrecognized-param");
        }

        emit File(what, data);
    }

    /**
     * @notice Updates the `vestId` managed by this contract.
     * @dev The vest must be valid, in favor of `stakingRewards` and managed by this contract.
     * @param _vestId The new vest ID.
     */
    function setVestId(uint256 _vestId) internal {
        require(dssVest.valid(_vestId), "RewardsDistribution/invalid-vest-id");
        require(dssVest.usr(_vestId) == address(stakingRewards), "RewardsDistribution/invalid-vest-usr");
        require(dssVest.mgr(_vestId) == address(this), "RewardsDistribution/invalid-vest-mgr");
        vestId = _vestId;
    }

    /**
     * @notice Updates the reward distribution strategy `calc`>
     * @param _calc The new calc contract.
     */
    function setCalc(address _calc) internal {
        require(_calc != address(0), "RewardsDistribution/invalid-address");
        calc = DistributionCalc(_calc);
    }

    /**
     * @notice Distributes the amount of rewards due since the last distribution.
     */
    function distribute() external {
        require(vestId != INVALID_VEST_ID, "RewardsDistribution/invalid-vest-id");
        require(dssVest.unpaid(vestId) > 0, "RewardsDistribution/empty-vest");

        uint256 when = block.timestamp;
        uint256 prev = stakingRewards.lastUpdateTime();
        uint256 tot = dssVest.tot(vestId);
        uint256 fin = dssVest.fin(vestId);
        uint256 clf = dssVest.clf(vestId);

        uint256 amount = calc.getAmount(when, prev, tot, fin, clf);
        require(amount > 0, "RewardsDistribution/no-pending-amount");

        dssVest.vest(vestId, amount);
        stakingRewards.notifyRewardAmount(amount);

        emit Distribute(amount);
    }
}
