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
pragma solidity =0.8.19;

import "forge-std/Test.sol";
import {PauseProxy} from "./PauseProxy.sol";

contract PauseProxyTest is Test {
    PauseProxy internal proxy = new PauseProxy();
    Target internal target = new Target();

    function testProxyUsesDelegateCall() public {
        bytes memory out = proxy.exec(address(target), abi.encodeWithSelector(Target.getSender.selector));
        address sender = abi.decode(out, (address));
        assertEq(sender, address(this), "msg.sender is not the original caller");
    }

    function testProxyHandlesSentEther() public {
        uint256 sentValue = 0.1 ether;
        bytes memory out = proxy.exec{value: sentValue}(
            address(target),
            abi.encodeWithSelector(Target.getValue.selector)
        );
        uint256 receivedValue = abi.decode(out, (uint256));
        assertEq(receivedValue, sentValue, "msg.value is not the original provided");
    }

    function testProxyForwardsArguments() public {
        bytes memory sentArgs = "arbitrary args";
        bytes memory out = proxy.exec(address(target), abi.encodeWithSelector(Target.getArgs.selector, sentArgs));
        bytes memory receivedArgs = abi.decode(out, (bytes));
        assertEq(receivedArgs, sentArgs, "arguments have not been forwarded properly");
    }

    function testRelyDeny() public {
        assertEq(proxy.wards(address(0)), 0);

        // --------------------
        vm.expectEmit(true, false, false, false);
        emit Rely(address(0));

        proxy.rely(address(0));

        assertEq(proxy.wards(address(0)), 1);

        // --------------------
        vm.expectEmit(true, false, false, false);
        emit Deny(address(0));

        proxy.deny(address(0));

        assertEq(proxy.wards(address(0)), 0);
    }

    event Rely(address indexed usr);
    event Deny(address indexed usr);
}

contract Target {
    function getSender() external view returns (address) {
        return msg.sender;
    }

    function getValue() external payable returns (uint256) {
        return msg.value;
    }

    function getArgs(bytes calldata args) external pure returns (bytes memory) {
        return args;
    }
}
