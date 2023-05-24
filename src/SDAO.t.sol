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

import {TokenFuzzTests} from "token-tests/TokenFuzzTests.sol";
import {DssTest} from "dss-test/DssTest.sol";
import {GodMode} from "dss-test/MCD.sol";
import {SDAO} from "./SDAO.sol";

/**
 * @dev Adapted from Solmate ERC20 test suite:
 * https://github.com/transmissions11/solmate/blob/2001af43aedb46fdc2335d2a7714fb2dae7cfcd1/src/test/ERC20.t.sol
 */
contract SDAOTest is TokenFuzzTests {
    SDAO token;

    function setUp() public {
        token = new SDAO("Token", "TKN");

        _token_ = address(token);
        _tokenName_ ="Token";
        _contractName_ = "SDAO";
        _symbol_ = "TKN";
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);
    }

    function testRevertFileUnsupportedMetadata() public {
        vm.expectRevert("SDAO/file-unrecognized-param");
        token.file("decimals", "18");
    }

    function testMetadataFuzz(string calldata name, string calldata symbol) public {
        SDAO tkn = new SDAO(name, symbol);
        assertEq(tkn.name(), name);
        assertEq(tkn.symbol(), symbol);
        assertEq(tkn.decimals(), 18);
    }

    function testFile() public {
        checkFileString(address(token), "SDAO", ["name", "symbol"]);
    }

    // There are no checkFileString on DssTest, so we need to implement it here.

    event File(bytes32 indexed what, string data);

    /// @dev This is forge-only due to event checking
    function checkFileString(address _base, string memory _contractName, string[] memory _values) internal {
        FileStringLike base = FileStringLike(_base);
        uint256 ward = base.wards(address(this));

        // Ensure we have admin access
        GodMode.setWard(_base, address(this), 1);

        // First check an invalid value
        vm.expectRevert(abi.encodePacked(_contractName, "/file-unrecognized-param"));
        base.file("an invalid value", "");

        // Next check each value is valid and updates the target storage slot
        for (uint256 i = 0; i < _values.length; i++) {
            string memory value = _values[i];
            bytes32 valueB32;
            assembly {
                valueB32 := mload(add(value, 32))
            }

            // Read original value
            (bool success, bytes memory result) = _base.call(
                abi.encodeWithSignature(string(abi.encodePacked(value, "()")))
            );
            assertTrue(success);
            string memory origData = abi.decode(result, (string));
            string memory newData;
            newData = string.concat(newData, " - NEW");

            // Update value
            vm.expectEmit(true, false, false, true);
            emit File(valueB32, newData);
            base.file(valueB32, newData);

            // Confirm it was updated successfully
            (success, result) = _base.call(abi.encodeWithSignature(string(abi.encodePacked(value, "()"))));
            assertTrue(success);
            string memory data = abi.decode(result, (string));
            assertEq(data, newData);

            // Reset value to original
            vm.expectEmit(true, false, false, true);
            emit File(valueB32, origData);
            base.file(valueB32, origData);
        }

        // Finally check that file is authed
        base.deny(address(this));
        vm.expectRevert(abi.encodePacked(_contractName, "/not-authorized"));
        base.file("some value", "");

        // Reset admin access to what it was
        GodMode.setWard(_base, address(this), ward);
    }

    function checkFileString(address _base, string memory _contractName, string[1] memory _values) internal {
        string[] memory values = new string[](1);
        values[0] = _values[0];
        checkFileString(_base, _contractName, values);
    }

    function checkFileString(address _base, string memory _contractName, string[2] memory _values) internal {
        string[] memory values = new string[](2);
        values[0] = _values[0];
        values[1] = _values[1];
        checkFileString(_base, _contractName, values);
    }
}

interface AuthLike {
    function wards(address) external view returns (uint256);

    function rely(address) external;

    function deny(address) external;
}

interface FileStringLike is AuthLike {
    function file(bytes32, string memory) external;
}

contract SDAOInvariants is DssTest {
    BalanceSum balanceSum;
    SDAO token;

    function setUp() public {
        token = new SDAO("Token", "TKN");
        balanceSum = new BalanceSum(token);
    }

    function invariantBalanceSum() public {
        assertEq(token.totalSupply(), balanceSum.sum());
    }
}

contract BalanceSum {
    SDAO token;
    uint256 public sum;

    constructor(SDAO _token) {
        token = _token;
    }

    function mint(address from, uint256 amount) public {
        token.mint(from, amount);
        sum += amount;
    }

    function burn(address from, uint256 amount) public {
        token.burn(from, amount);
        sum -= amount;
    }

    function approve(address to, uint256 amount) public {
        token.approve(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public {
        token.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public {
        token.transfer(to, amount);
    }
}
