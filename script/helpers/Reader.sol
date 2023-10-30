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

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";

contract Reader {
    using stdJson for string;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    string internal data;

    constructor(string memory _data) {
        data = _data;
    }

    function loadConfig() external {
        data = ScriptTools.loadConfig();
    }

    function loadDependencies() external {
        data = ScriptTools.loadDependencies();
    }

    function loadDependenciesOrConfig() external {
        try this.loadDependencies() {
            if (bytes(data).length == 0) {
                revert("");
            }
        } catch {
            this.loadConfig();
        }
    }

    function readAddress(string memory key) external returns (address) {
        return data.readAddress(key);
    }

    function readUint(string memory key) external returns (uint256) {
        return data.readUint(key);
    }

    function readAddressOptional(string memory key) external returns (address) {
        return readOr(key, address(0));
    }

    function readUintOptional(string memory key) external returns (uint256) {
        return readOr(key, 0);
    }

    function readOr(string memory key, address def) public returns (address) {
        try this.readAddress(key) returns (address result) {
            return result;
        } catch {
            return def;
        }
    }

    function readOr(string memory key, uint256 def) public returns (uint256) {
        try this.readUint(key) returns (uint256 result) {
            return result;
        } catch {
            return def;
        }
    }

    function envOrReadAddress(string memory envKey, string memory key) external returns (address) {
        try vm.envAddress(envKey) returns (address addr) {
            return addr;
        } catch {
            return this.readAddress(key);
        }
    }

    function envOrReadUint(string memory envKey, string memory key) external returns (uint256) {
        try vm.envUint(envKey) returns (uint256 n) {
            return n;
        } catch {
            return this.readUint(key);
        }
    }
}
