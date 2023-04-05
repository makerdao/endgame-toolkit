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

contract PauseProxy {
    /// @notice Addresses with owner access on this contract. `wards[usr]`
    mapping(address => uint256) public wards;

    /**
     * @notice `usr` was granted oner access.
     * @param usr The user address.
     */
    event Rely(address indexed usr);
    /**
     * @notice `usr` owner access was revoked.
     * @param usr The user address.
     */
    event Deny(address indexed usr);

    modifier auth() {
        require(wards[msg.sender] == 1, "PauseProxy/not-authorized");
        _;
    }

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

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
     * @notice Executes a calldata-encoded call `args` in the context of `target`.
     * @dev This function attempts to bubble-up potential execution errors.
     * @param target The target contract.
     * @param args The calldata-encoded call.
     * @return out The result of the execution.
     */
    function exec(address target, bytes calldata args) external payable auth returns (bytes memory out) {
        bool ok;
        (ok, out) = target.delegatecall(args);

        if (!ok) {
            _revertFromReturnData(out);
        }
    }

    /// @dev ref: https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require)
    bytes4 internal constant PANIC_SELECTOR = bytes4(keccak256(bytes("Panic(uint256)")));

    /**
     * @notice Bubble up the revert from the returnData (supports Panic, Error & Custom Errors).
     * @dev This is needed in order to provide some human-readable revert message from a call.
     * @param returnData Response of the call.
     **/
    function _revertFromReturnData(bytes memory returnData) internal pure {
        // @see https://ethereum.stackexchange.com/a/123588
        if (returnData.length < 4) {
            // case 1: catch all
            revert("PauseProxy/target-reverted");
        } else {
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(returnData, 0x20))
            }
            if (errorSelector == PANIC_SELECTOR) {
                // case 2: Panic(uint256) (Defined since 0.8.0)
                string memory reason = "PauseProxy/target-panicked: 0x__";
                uint256 errorCode;
                assembly {
                    errorCode := mload(add(returnData, 0x24))
                    let reasonWord := mload(add(reason, 0x20))
                    // [0..9] is converted to ['0'..'9']
                    // [0xa..0xf] is not correctly converted to ['a'..'f']
                    // but since panic code doesn't have those cases, we will ignore them for now!
                    let e1 := add(and(errorCode, 0xf), 0x30)
                    let e2 := shl(8, add(shr(4, and(errorCode, 0xf0)), 0x30))
                    reasonWord := or(
                        and(reasonWord, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000),
                        or(e2, e1)
                    )
                    mstore(add(reason, 0x20), reasonWord)
                }
                revert(reason);
            } else {
                // case 3: Error(string) (Defined at least since 0.7.0)
                // case 4: Custom errors (Defined since 0.8.0)
                uint256 len = returnData.length;
                assembly {
                    revert(add(returnData, 0x20), len)
                }
            }
        }
    }
}
