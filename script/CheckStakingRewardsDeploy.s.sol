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
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";

import {ConfigReader} from "./helpers/Config.sol";

interface WardsLike {
    function wards(address who) external view returns (uint256);
}

interface VestedRewardsDistributionLike {
    function vestId() external view returns (uint256);
}

interface StakingRewardsLike {
    function owner() external view returns (address);

    function stakingToken() external view returns (address);

    function rewardsToken() external view returns (address);

    function rewardsDistribution() external view returns (address);
}

interface DssVestWithGemLike {
    function gem() external view returns (address);

    function tot(uint256 vestId) external view returns (uint256);

    function bgn(uint256 vestId) external view returns (uint256);

    function clf(uint256 vestId) external view returns (uint256);

    function fin(uint256 vestId) external view returns (uint256);

    function usr(uint256 vestId) external view returns (address);

    function valid(uint256 _id) external view returns (bool);
}

contract CheckStakingRewardsDeployScript is Script {
    using stdJson for string;
    using ScriptTools for string;

    function run() external returns (bool) {
        ConfigReader reader = new ConfigReader(ScriptTools.loadConfig());

        address admin = reader.readAddress(".admin");
        address ngt = reader.readAddress(".ngt");
        address nst = reader.readAddress(".nst");
        address dist = reader.readAddress(".dist");
        address farm = reader.readAddress(".farm");
        address vest = reader.readAddress(".vest");
        uint256 vestId = reader.readUint(".vestId");
        uint256 vestTot = reader.readUint(".vestTot");
        uint256 vestBgn = reader.readUint(".vestBgn");
        uint256 vestTau = reader.readUint(".vestTau");
        uint256 vestEta = reader.readUint(".vestEta");

        require(WardsLike(dist).wards(admin) == 1, "vested-rewards-distribution/pause-proxy-not-relied");
        require(VestedRewardsDistributionLike(dist).vestId() == vestId, "vested-rewards-distribution/invalid-vest-id");

        require(StakingRewardsLike(farm).owner() == admin, "staking-rewards/pause-proxy-not-owner");
        require(StakingRewardsLike(farm).rewardsToken() == ngt, "staking-rewards/invalid-rewards-token");
        require(StakingRewardsLike(farm).stakingToken() == nst, "staking-rewards/invalid-rewards-token");
        require(StakingRewardsLike(farm).rewardsDistribution() == dist, "staking-rewards/invalid-rewards-distribution");

        require(WardsLike(ngt).wards(vest) == 1, "ngt/dss-vest-not-ward");

        require(WardsLike(vest).wards(admin) == 1, "dss-vest/pause-proxy-not-relied");
        require(DssVestWithGemLike(vest).gem() == ngt, "dss-vest/invalid-gem");
        require(DssVestWithGemLike(vest).valid(vestId), "dss-vest/invalid-vest-id");
        require(DssVestWithGemLike(vest).usr(vestId) == dist, "dss-vest/wrong-dist");
        require(DssVestWithGemLike(vest).tot(vestId) == vestTot, "dss-vest/invalid-tot");
        require(DssVestWithGemLike(vest).bgn(vestId) == vestBgn, "dss-vest/invalid-bgn");
        require(DssVestWithGemLike(vest).clf(vestId) == vestBgn + vestEta, "dss-vest/invalid-eta");
        require(DssVestWithGemLike(vest).fin(vestId) == vestBgn + vestTau, "dss-vest/invalid-tau");

        return true;
    }
}
