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

import {IStakingRewards} from "./synthetix/interfaces/IStakingRewards.sol";
import {DssVestWithGemLike} from "./interfaces/DssVestWithGemLike.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/**
 * @title VestedRewardsDistribution: A permissionless bridge between {DssVest} and {StakingRewards}.
 * @author @amusingaxl
 */
contract VestedRewardsDistribution {
    /// @notice Addresses with owner access on this contract. `wards[usr]`
    mapping(address => uint256) public wards;

    /// @notice DssVest instance for token rewards.
    DssVestWithGemLike public immutable dssVest;
    /// @notice StakingRewards instance to enable farming.
    IStakingRewards public immutable stakingRewards;
    /// @notice Token in which rewards are being paid.
    IERC20 public immutable gem;

    /// @dev Vest IDs are sequential, but they are incremented before usage, meaning `0` is not a valid vest ID.
    uint256 internal constant INVALID_VEST_ID = 0;
    /// @notice The vest ID managed by this contract.
    /// @dev It is initialized to an invalid value to prevent calls before the vest ID being set.
    /// The reason this is not a required constructor parameter is that there is a circular dependency
    /// between this contract and the creation of the vest: the address of this contract must be the vest `usr`.
    uint256 public vestId = INVALID_VEST_ID;
    /// @notice Tracks the last time a distribution was made.
    uint256 public lastDistributedAt;

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
     * @notice A distribution of tokens was made.
     * @param amount The total tokens in the current distribution.
     */
    event Distribute(uint256 amount);

    modifier auth() {
        require(wards[msg.sender] == 1, "VestedRewardsDistribution/not-authorized");
        _;
    }

    /**
     * @dev The token `gem` used in DssVest must be the same as `rewardsToken` in StakingRewards.
     * @param _dssVest The DssVest instance as the source of the funds.
     * @param _stakingRewards The farming contract.
     */
    constructor(address _dssVest, address _stakingRewards) {
        address _gem = DssVestWithGemLike(_dssVest).gem();
        require(
            _gem == address(IStakingRewards(_stakingRewards).rewardsToken()),
            "VestedRewardsDistribution/invalid-gem"
        );

        dssVest = DssVestWithGemLike(_dssVest);
        stakingRewards = IStakingRewards(_stakingRewards);
        gem = IERC20(_gem);

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
            _setVestId(data);
        } else {
            revert("VestedRewardsDistribution/file-unrecognized-param");
        }

        emit File(what, data);
    }

    /**
     * @notice Updates the `vestId` managed by this contract.
     * @dev The `_vestId` must be valid, in favor of this contract.
     * @dev Vesting streams whose `clf > bgn` are not supported.
     * @dev Unrestricted vesting streams are not supported.
     * @param _vestId The new vest ID.
     */
    function _setVestId(uint256 _vestId) internal {
        require(dssVest.valid(_vestId), "VestedRewardsDistribution/invalid-vest-id");
        require(dssVest.res(_vestId) == 1, "VestedRewardsDistribution/invalid-vest-res");
        require(dssVest.usr(_vestId) == address(this), "VestedRewardsDistribution/invalid-vest-usr");
        require(dssVest.clf(_vestId) == dssVest.bgn(_vestId), "VestedRewardsDistribution/invalid-vest-cliff");

        vestId = _vestId;
        lastDistributedAt = 0;
    }

    /**
     * @notice Distributes the amount of rewards due since the last distribution.
     * @dev Notice we don't need to wait for the current distribution `periodFinish` to be over in the
     * `RewardsDistribution` contract because it can handle new rewards being sent at any given time.
     * @return amount The amount being distributed.
     */
    function distribute() external returns (uint256 amount) {
        require(vestId != INVALID_VEST_ID, "VestedRewardsDistribution/invalid-vest-id");

        amount = dssVest.unpaid(vestId);
        require(amount > 0, "VestedRewardsDistribution/no-pending-amount");

        lastDistributedAt = block.timestamp;
        dssVest.vest(vestId, amount);

        require(gem.transfer(address(stakingRewards), amount), "VestedRewardsDistribution/transfer-failed");
        stakingRewards.notifyRewardAmount(amount);

        emit Distribute(amount);
    }
}
