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

import {stdJson} from "forge-std/StdJson.sol";

contract ConfigReader {
    using stdJson for string;

    string internal config;
    OptionalReader internal immutable opReader;

    constructor(string memory _config) {
        config = _config;
        opReader = new OptionalReader();
    }

    function readAddressOptional(string memory key) external returns (address) {
        return this.readOr(key, address(0));
    }

    function readOr(string memory key, address def) external returns (address) {
        try opReader.readAddress(config, key) returns (address result) {
            return result;
        } catch {
            return def;
        }
    }
}

contract OptionalReader {
    function readAddress(string memory data, string memory key) external returns (address) {
        return stdJson.readAddress(data, key);
    }
}

struct Exports {
    address gov;
    address subProxy;
}

struct Imports {
    address dist;
    address farm;
    address gov;
    address subProxy;
    address vest;
}
