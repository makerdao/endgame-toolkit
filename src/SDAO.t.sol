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

import {TokenFuzzTests} from "token-tests/TokenFuzzTests.sol";
import {DssTest} from "dss-test/DssTest.sol";
import {SDAO} from "./SDAO.sol";

/**
 * @dev Adapted from Solmate ERC20 test suite:
 * https://github.com/transmissions11/solmate/blob/2001af43aedb46fdc2335d2a7714fb2dae7cfcd1/src/test/ERC20.t.sol
 */
contract SDAOTest is TokenFuzzTests {
    SDAO internal token;
    BalanceSum internal balanceSum;

    function setUp() public {
        token = new SDAO("Token", "TKN");
        _token_ = address(token);
        _tokenName_ = "Token";
        _contractName_ = "SDAO";
        _symbol_ = "TKN";

        balanceSum = new BalanceSum(token);
        token.rely(address(balanceSum));
        excludeSender(address(0));
        targetContract(address(balanceSum));
    }

    function invariantBalanceSum() public {
        assertEq(token.totalSupply(), balanceSum.sum());
    }

    function testRevertFileUnsupportedMetadata() public {
        vm.expectRevert("SDAO/file-unrecognized-param");
        token.file("decimals", "18");
    }

    function testFile() public {
        checkFileString(address(token), "SDAO", ["name", "symbol"]);
    }
}

contract BalanceSum is DssTest {
    SDAO internal token;
    uint256 public sum;

    constructor(SDAO _token) {
        token = _token;
    }

    function mint(address to, uint256 amount) public {
        // We cannot use vm.assume() because it causes the call to fail.
        if (to == address(0) || to == address(token)) return;

        amount = bound(amount, 1, type(uint248).max);

        token.mint(to, amount);
        sum += amount;
    }

    function burn(address from, uint256 mintedAmount, uint256 burntAmount) public {
        if (from == address(0) || from == address(token)) return;

        mintedAmount = bound(mintedAmount, 1, type(uint248).max);
        burntAmount = bound(burntAmount, 1, mintedAmount);

        token.mint(from, mintedAmount);
        sum += mintedAmount;

        vm.prank(address(from));
        token.burn(from, burntAmount);
        sum -= burntAmount;
    }

    function approve(address to, uint256 amount) public {
        token.approve(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public {
        if (to == address(0) || to == address(token)) return;
        if (from == address(0) || from == address(token)) return;

        amount = bound(amount, 1, type(uint248).max);

        token.mint(from, amount);
        sum += amount;

        vm.prank(from);
        token.approve(address(this), amount);

        token.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public {
        if (to == address(0) || to == address(token)) return;

        amount = bound(amount, 1, type(uint248).max);

        token.mint(address(this), amount);
        sum += amount;

        token.transfer(to, amount);
    }
}
