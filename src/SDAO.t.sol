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
pragma solidity 0.8.19;

import {DssTest} from "dss-test/DssTest.sol";
import {SDAO} from "./SDAO.sol";

/**
 * @dev Adapted from Solmate ERC20 test suite:
 * https://github.com/transmissions11/solmate/blob/2001af43aedb46fdc2335d2a7714fb2dae7cfcd1/src/test/ERC20.t.sol
 */
contract SDAOTest is DssTest {
    SDAO token;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        token = new SDAO("Token", "TKN");
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);
    }

    function testMint() public {
        token.mint(address(0xBEEF), 1e18);

        assertEq(token.totalSupply(), 1e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testBurn() public {
        token.mint(address(0xBEEF), 1e18);
        vm.prank(address(0xBEEF));
        token.approve(address(this), type(uint256).max);

        token.burn(address(0xBEEF), 0.9e18);

        assertEq(token.totalSupply(), 1e18 - 0.9e18);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testApprove() public {
        assertTrue(token.approve(address(0xBEEF), 1e18));

        assertEq(token.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        token.mint(address(this), 1e18);

        assertTrue(token.transfer(address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom() public {
        address from = address(0xABCD);
        token.mint(from, 1e18);
        vm.prank(from);
        token.approve(address(this), 1e18);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));

        assertEq(token.totalSupply(), 1e18);
        assertEq(token.allowance(from, address(this)), 0);
        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testInfiniteApproveTransferFrom() public {
        address from = address(0xABCD);
        token.mint(from, 1e18);
        vm.prank(from);
        token.approve(address(this), type(uint256).max);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));

        assertEq(token.totalSupply(), 1e18);
        assertEq(token.allowance(from, address(this)), type(uint256).max);
        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, token.nonces(owner), block.timestamp)
                    )
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(token.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(token.nonces(owner), 1);
    }

    function testRevertTransferInsufficientBalance() public {
        token.mint(address(this), 0.9e18);

        vm.expectRevert("SDAO/insufficient-balance");
        token.transfer(address(0xBEEF), 1e18);
    }

    function testRevertTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);
        token.mint(from, 1e18);
        vm.prank(from);
        token.approve(address(this), 0.9e18);

        vm.expectRevert("SDAO/insufficient-allowance");
        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testRevertTransferFromInsufficientBalance() public {
        address from = address(0xABCD);
        token.mint(from, 0.9e18);
        vm.prank(from);
        token.approve(address(this), 1e18);

        vm.expectRevert("SDAO/insufficient-balance");
        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testRevertPermitBadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 1, block.timestamp))
                )
            )
        );

        vm.expectRevert("SDAO/invalid-permit");
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testRevertPermitBadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        vm.expectRevert("SDAO/invalid-permit");
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp + 1, v, r, s);
    }

    function testRevertPermitPastDeadline() public {
        uint256 oldTimestamp = block.timestamp;
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, oldTimestamp))
                )
            )
        );

        vm.warp(block.timestamp + 1);
        vm.expectRevert("SDAO/permit-expired");
        token.permit(owner, address(0xCAFE), 1e18, oldTimestamp, v, r, s);
    }

    function testRevertPermitReplay() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        vm.expectRevert("SDAO/invalid-permit");
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testMetadataFuzz(string calldata name, string calldata symbol) public {
        SDAO tkn = new SDAO(name, symbol);
        assertEq(tkn.name(), name);
        assertEq(tkn.symbol(), symbol);
        assertEq(tkn.decimals(), 18);
    }

    function testMintFuzz(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(token));

        token.mint(to, amount);

        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(to), amount);
    }

    function testBurnFuzz(address from, uint256 mintedAmount, uint256 burntAmount) public {
        vm.assume(from != address(0) && from != address(token));
        burntAmount = bound(burntAmount, 0, mintedAmount);

        token.mint(from, mintedAmount);
        vm.prank(from);
        token.approve(address(this), type(uint256).max);

        token.burn(from, burntAmount);

        assertEq(token.totalSupply(), mintedAmount - burntAmount);
        assertEq(token.balanceOf(from), mintedAmount - burntAmount);
    }

    function testApproveFuzz(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(token));

        assertTrue(token.approve(to, amount));

        assertEq(token.allowance(address(this), to), amount);
    }

    function testTransferFuzz(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(token));

        token.mint(address(this), amount);

        assertTrue(token.transfer(to, amount));

        assertEq(token.totalSupply(), amount);
        if (address(this) == to) {
            assertEq(token.balanceOf(address(this)), amount);
        } else {
            assertEq(token.balanceOf(address(this)), 0);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function testTransferFromFuzz(address to, uint256 allowance, uint256 amount) public {
        vm.assume(to != address(0) && to != address(token));
        amount = bound(amount, 0, allowance);

        address from = address(0xABCD);
        token.mint(from, amount);
        vm.prank(from);
        token.approve(address(this), allowance);

        assertTrue(token.transferFrom(from, to, amount));

        assertEq(token.totalSupply(), amount);

        uint256 newAllowance = from == address(this) || allowance == type(uint256).max ? allowance : allowance - amount;
        assertEq(token.allowance(from, address(this)), newAllowance);

        if (from == to) {
            assertEq(token.balanceOf(from), amount);
        } else {
            assertEq(token.balanceOf(from), 0);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function testPermitFuzz(uint248 privateKey, address to, uint256 amount, uint256 deadline) public {
        deadline = bound(deadline, block.timestamp, block.timestamp + type(uint80).max);
        privateKey = uint248(bound(privateKey, 1, type(uint248).max));

        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline, v, r, s);

        assertEq(token.allowance(owner, to), amount);
        assertEq(token.nonces(owner), 1);
    }

    function testRevertBurnInsufficientBalanceFuzz(address to, uint256 mintedAmount, uint256 burntAmount) public {
        vm.assume(to != address(0) && to != address(token));
        mintedAmount = bound(mintedAmount, 0, type(uint256).max - 1);
        burntAmount = bound(burntAmount, mintedAmount + 1, type(uint256).max);

        token.mint(to, mintedAmount);

        vm.expectRevert("SDAO/insufficient-balance");
        token.burn(to, burntAmount);
    }

    function testRevertTransferInsufficientBalanceFuzz(address to, uint256 mintedAmount, uint256 sendAmount) public {
        vm.assume(to != address(0) && to != address(token));
        mintedAmount = bound(mintedAmount, 0, type(uint256).max - 1);
        sendAmount = bound(sendAmount, mintedAmount + 1, type(uint256).max);

        token.mint(address(this), mintedAmount);

        vm.expectRevert("SDAO/insufficient-balance");
        token.transfer(to, sendAmount);
    }

    function testRevertTransferFromInsufficientAllowanceFuzz(address to, uint256 allowance, uint256 amount) public {
        vm.assume(to != address(0) && to != address(token));
        allowance = bound(allowance, 0, type(uint256).max - 1);
        amount = bound(amount, allowance + 1, type(uint256).max);

        address from = address(0xABCD);
        token.mint(from, amount);
        vm.prank(from);
        token.approve(address(this), allowance);

        vm.expectRevert("SDAO/insufficient-allowance");
        token.transferFrom(from, to, amount);
    }

    function testRevertTransferFromInsufficientBalanceFuzz(
        address to,
        uint256 mintedAmount,
        uint256 sendAmount
    ) public {
        vm.assume(to != address(0) && to != address(token));
        mintedAmount = bound(mintedAmount, 0, type(uint256).max - 1);
        sendAmount = bound(sendAmount, mintedAmount + 1, type(uint256).max);

        address from = address(0xABCD);
        token.mint(from, mintedAmount);
        vm.prank(from);
        token.approve(address(this), sendAmount);

        vm.expectRevert("SDAO/insufficient-balance");
        token.transferFrom(from, to, sendAmount);
    }

    function testRevertPermitBadNonceFuzz(
        uint248 privateKey,
        address to,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) public {
        deadline = bound(deadline, block.timestamp, block.timestamp + type(uint80).max);
        privateKey = uint248(bound(privateKey, 1, type(uint248).max));
        nonce = bound(nonce, 1, type(uint256).max - 1);

        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, nonce, deadline))
                )
            )
        );

        vm.expectRevert("SDAO/invalid-permit");
        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testRevertPermitBadDeadlineFuzz(uint248 privateKey, address to, uint256 amount, uint256 deadline) public {
        deadline = bound(deadline, block.timestamp, block.timestamp + type(uint80).max);
        privateKey = uint248(bound(privateKey, 1, type(uint248).max));

        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        vm.expectRevert("SDAO/invalid-permit");
        token.permit(owner, to, amount, deadline + 1, v, r, s);
    }

    function testRevertPermitPastDeadlineFuzz(uint248 privateKey, address to, uint256 amount, uint256 deadline) public {
        deadline = bound(deadline, 0, block.timestamp - 1);
        privateKey = uint248(bound(privateKey, 1, type(uint248).max));

        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        vm.expectRevert("SDAO/permit-expired");
        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testRevertPermitReplayFuzz(uint248 privateKey, address to, uint256 amount, uint256 deadline) public {
        deadline = bound(deadline, block.timestamp, block.timestamp + type(uint80).max);
        privateKey = uint248(bound(privateKey, 1, type(uint248).max));

        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );
        token.permit(owner, to, amount, deadline, v, r, s);

        vm.expectRevert("SDAO/invalid-permit");
        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testAuth() public {
        checkAuth(address(token), "SDAO");
    }

    function testModifiers(address sender) public {
        vm.assume(sender != address(this));

        bytes4[] memory authedMethods = new bytes4[](1);
        authedMethods[0] = SDAO.mint.selector;

        vm.startPrank(sender);
        checkModifier(address(token), "SDAO/not-authorized", authedMethods);
    }
}

contract SDAOInvariants is DssTest {
    BalanceSum balanceSum;
    SDAO token;

    function setUp() public {
        token = new SDAO("Token", "TKN");
        balanceSum = new BalanceSum(token);

        token.rely(address(balanceSum));

        targetContract(address(balanceSum));
    }

    function invariantBalanceSum() public {
        assertEq(token.totalSupply(), balanceSum.sum());
    }
}

contract BalanceSum is DssTest {
    SDAO public token;
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
