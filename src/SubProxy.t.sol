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

import {DssTest} from "dss-test/DssTest.sol";
import {SubProxy} from "./SubProxy.sol";

contract SubProxyTest is DssTest {
    SubProxy internal proxy = new SubProxy();
    Target internal target = new Target();

    function testExecUsesDelegateCall() public {
        bytes memory out = proxy.exec(address(target), abi.encodeWithSelector(Target.getSender.selector));
        address sender = abi.decode(out, (address));
        assertEq(sender, address(this), "msg.sender is not the original caller");
    }

    function testExecIsPayable() public {
        uint256 sentValue = 0.1 ether;
        bytes memory out = proxy.exec{value: sentValue}(
            address(target),
            abi.encodeWithSelector(Target.getValue.selector)
        );
        uint256 receivedValue = abi.decode(out, (uint256));
        assertEq(receivedValue, sentValue, "msg.value is not the original provided");
    }

    function testExecForwardsArguments() public {
        bytes memory sentArgs = "arbitrary args";
        bytes memory out = proxy.exec(address(target), abi.encodeWithSelector(Target.getArgs.selector, sentArgs));
        bytes memory receivedArgs = abi.decode(out, (bytes));
        assertEq(receivedArgs, sentArgs, "arguments have not been forwarded properly");
    }

    function testRevertExec() public {
        vm.expectRevert("SubProxy/delegatecall-error");
        proxy.exec(address(target), abi.encodeWithSelector(Target.revertWithoutMessage.selector));
    }

    function testRevertExecWithMessage() public {
        vm.expectRevert("SubProxy/delegatecall-error");
        proxy.exec(address(target), abi.encodeWithSelector(Target.revertWithMessage.selector));
    }

    function testRevertExecWithCustomError() public {
        vm.expectRevert("SubProxy/delegatecall-error");
        proxy.exec(address(target), abi.encodeWithSelector(Target.revertWithCustomError.selector));
    }

    function testRevertExecWithPanic() public {
        vm.expectRevert("SubProxy/delegatecall-error");
        proxy.exec(address(target), abi.encodeWithSelector(Target.revertWithPanic.selector));
    }

    function testRevertExecWhenNotAuthorized() public {
        assertEq(proxy.wards(address(0)), 0);

        vm.expectRevert("SubProxy/not-authorized");
        vm.prank(address(0));
        proxy.exec(address(target), abi.encodeWithSelector(Target.getSender.selector));
    }

    function testRelyDeny() public {
        assertEq(proxy.wards(address(0)), 0);

        // --------------------
        vm.expectEmit(true, false, false, false);
        emit Rely(address(0));
        proxy.rely(address(0));

        assertEq(proxy.wards(address(0)), 1);

        vm.prank(address(0));
        proxy.exec(address(target), abi.encodeWithSelector(Target.getSender.selector));

        // --------------------
        vm.expectEmit(true, false, false, false);
        emit Deny(address(0));
        proxy.deny(address(0));

        assertEq(proxy.wards(address(0)), 0);

        vm.prank(address(0));
        vm.expectRevert("SubProxy/not-authorized");
        proxy.exec(address(target), abi.encodeWithSelector(Target.getSender.selector));
    }
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

    function revertWithoutMessage() external pure {
        revert();
    }

    function revertWithMessage() external pure {
        revert("error-msg");
    }

    error Failed();

    function revertWithCustomError() external pure {
        revert Failed();
    }

    function revertWithPanic() external pure {
        uint256 b = 0;
        1 / b;
    }
}
