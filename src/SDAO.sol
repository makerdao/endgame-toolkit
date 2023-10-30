// SPDX-FileCopyrightText: © 2017, 2018, 2019 dbrock, rain, mrchico
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

/// @dev Smart Contract signature validation interface.
interface IERC1271 {
    function isValidSignature(bytes32, bytes memory) external view returns (bytes4);
}

/**
 * @title SDAO: SubDAO-level governance token.
 * @dev This is a port from X-Domain Dai implementation: https://www.diffchecker.com/XeqEiDcn/ with additional features:
 *      - Actors with owner access (`wards`) can update `name` and `symbol`.
 * @author @amusingaxl
 */
contract SDAO {
    /// @notice Addresses with owner access on this contract. `wards[usr]`
    mapping(address => uint256) public wards;

    // --- ERC20 Data ---

    /// @dev The name of the token.
    string public name;
    /// @dev The symbol of the token.
    string public symbol;
    /// @dev The version of the token.
    string public constant version = "1";
    /// @dev The number of decimal places for the token.
    uint8 public constant decimals = 18;
    /// @notice Returns the amount of tokens in existence.
    uint256 public totalSupply;

    /// @notice Returns the amount of tokens owned by `account`. balanceOf[account]
    mapping(address => uint256) public balanceOf;
    /// @notice The remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through {transferFrom}. allowance[owner][spender]
    mapping(address => mapping(address => uint256)) public allowance;
    /**
     * @notice Provides replay attack protection for ERC20 Permits. nonces[owner]
     * @dev This value must be included whenever a signature is generated for {permit}.
     * @dev Every successful call to {permit} increases `owner`'s nonce by one.
     */
    mapping(address => uint256) public nonces;

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
     * @param what The parameter being changed. One of: "name", "symbol".
     * @param data The new value of the parameter.
     */
    event File(bytes32 indexed what, string data);

    /**
     * @notice Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}.
     * @param owner The account setting the allowance.
     * @param spender The account receiving the allowance.
     * @param value The new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
    /**
     * @notice Emitted when `value` tokens are moved from one account (`from`) to another (`to`).
     * @param from The source of the funds.
     * @param to The destination of the funds.
     * @param value The amount transfered. Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    // --- EIP712 niceties ---
    /// @dev The chain ID of the chain in which the token has been deployed.
    uint256 public immutable deploymentChainId;
    /// @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
    bytes32 private immutable _DOMAIN_SEPARATOR;
    /// @dev ERC-712 typehash for permits.
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    modifier auth() {
        require(wards[msg.sender] == 1, "SDAO/not-authorized");
        _;
    }

    /**
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     */
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        deploymentChainId = block.chainid;
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
    }

    /**
     * @dev Calculates the EIP-712 domain separator for permits.
     * @param chainId The required chain ID.
     * @return The keccak256 hash of the EIP-712 identifier.
     */
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256(bytes(version)),
                    chainId,
                    address(this)
                )
            );
    }

    /**
     * @notice Calculates the EIP-712 domain separator for permits.
     * @dev To prevent replay attacks after potential chain splits, the cached domain separator is used only if the
     * current chain ID matches the cached chain ID. Otherwise, the domain separator is recalculated every time.
     * @return The keccak256 hash of the EIP-712 identifier.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid);
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
     * @notice Updates token parameters.
     * @dev There are no mechanisms to prevent governance from changing token parameters more than once.
     *      We assume that the enforcement will be handled off-chain through governance artifacts.
     * @param what The parameter being changed. One of: "name", "symbol".
     * @param data The updated value for the parameter.
     */
    function file(bytes32 what, string calldata data) external auth {
        if (what == "name") {
            name = data;
        } else if (what == "symbol") {
            symbol = data;
        } else {
            revert("SDAO/file-unrecognized-param");
        }

        emit File(what, data);
    }

    // --- ERC20 Mutations ---

    /**
     * @notice Moves `amount` tokens from `msg.sender` to `to`.
     * @dev Emits a {Transfer} event.
     * @param to The destination for the tokens.
     * @param value The amount of tokens to transfer.
     * @return Always `true` if the transaction did not revert.
     */
    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0) && to != address(this), "SDAO/invalid-address");
        uint256 balance = balanceOf[msg.sender];
        require(balance >= value, "SDAO/insufficient-balance");

        unchecked {
            balanceOf[msg.sender] = balance - value;
            // Note: safe as the sum of all balances is equal to `totalSupply`;
            // any overflow would have occurred already when increasing `totalSupply`
            balanceOf[to] += value;
        }

        emit Transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism.
     * @dev Emits a {Transfer} event.
     * @param from The origin of the tokens.
     * @param to The destination for the tokens.
     * @param value The amount of tokens to transfer.
     * @return Always `true` if the transaction did not revert.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(to != address(0) && to != address(this), "SDAO/invalid-address");
        uint256 balance = balanceOf[from];
        require(balance >= value, "SDAO/insufficient-balance");

        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value, "SDAO/insufficient-allowance");

                unchecked {
                    allowance[from][msg.sender] = allowed - value;
                }
            }
        }

        unchecked {
            balanceOf[from] = balance - value;
            // Note: safe as the sum of all balances is equal to `totalSupply`;
            // any overflow would have occurred already when increasing `totalSupply`
            balanceOf[to] += value;
        }

        emit Transfer(from, to, value);

        return true;
    }

    /**
     * @notice Sets `amount` as the allowance of `spender` over `msg.sender` tokens.
     * @dev Emits an {Approval} event.
     * @param spender The account receiving the allowance.
     * @param value The amount for allowance.
     * @return Always `true` if the transaction did not revert.
     *
     * @dev IMPORTANT: Beware that changing an allowance with this method brings the risk that someone may use both the
     * old and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     */
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    // --- Mint/Burn ---

    /**
     * @notice Creates `amount` tokens and assigns them to `to`, increasing the total supply.
     * @dev Only authorized parties can call this function.
     * @dev `to` must not be the zero address.
     * @dev Emits a {Transfer} event with `from` set to the zero address.
     * @param to The destination for the minted tokens.
     * @param value The amount of tokens to mint.
     */
    function mint(address to, uint256 value) external auth {
        require(to != address(0) && to != address(this), "SDAO/invalid-address");
        unchecked {
            // Note: safe as the sum of all balances is equal to `totalSupply`;
            // there is already an overvlow check below
            balanceOf[to] = balanceOf[to] + value;
        }
        totalSupply = totalSupply + value;

        emit Transfer(address(0), to, value);
    }

    /**
     * @notice Destroys `amount` tokens and assigns them to `to`, decreasing the total supply.
     * @dev If `from` != `msg.sender`, it uses the allowance mechanism.
     * @dev Emits a {Transfer} event with `to` set to the zero address.
     * @param from The origin for the burnt tokens.
     * @param value The amount of tokens to burn.
     */
    function burn(address from, uint256 value) external {
        uint256 balance = balanceOf[from];
        require(balance >= value, "SDAO/insufficient-balance");

        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value, "SDAO/insufficient-allowance");

                unchecked {
                    allowance[from][msg.sender] = allowed - value;
                }
            }
        }

        unchecked {
            // Note: we don't need an underflow check here b/c `balance >= value`
            balanceOf[from] = balance - value;
            // Note: we don't need an underflow check here b/c `totalSupply >= balance >= value`
            totalSupply = totalSupply - value;
        }

        emit Transfer(from, address(0), value);
    }

    // --- Approve by signature ---

    /**
     * @notice Validates a `signature` of `digest` from `signer`.
     * @dev This function supports both EOA signature validation through ecrecover and EIP-1271 style smart contract
     * signature validation.
     * @param signer The signer account or smart contract.
     * @param digest The hash of the message being signed.
     * @param signature The signature.
     * @return Whether the signature is valid or not.
     */
    function _isValidSignature(address signer, bytes32 digest, bytes memory signature) internal view returns (bool) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            if (signer == ecrecover(digest, v, r, s)) {
                return true;
            }
        }

        if (signer.code.length > 0) {
            (bool success, bytes memory result) = signer.staticcall(
                abi.encodeCall(IERC1271.isValidSignature, (digest, signature))
            );
            return (success &&
                result.length == 32 &&
                abi.decode(result, (bytes4)) == IERC1271.isValidSignature.selector);
        }

        return false;
    }

    /**
     * @notice Sets `value` as the allowance of `spender` over `owner`'s tokens, given `owner`'s signed approval.
     * @dev Emits an {Approval} event.
     * @param owner The account setting the allowance through permit.
     * @param spender The account receiving the allowance through permit. CANNOT be the zero address.
     * @param value The amount for allowance through permit.
     * @param deadline Until when the permit is valid. MUST be a timestamp in the future.
     * @param signature The signature for the permit. MUST use `owner`'s current nonce (see {nonces}).
     *
     * @dev IMPORTANT: The same issues {IERC20-approve} has related to transaction ordering also apply here.
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, bytes memory signature) public {
        require(block.timestamp <= deadline, "SDAO/permit-expired");
        require(owner != address(0), "SDAO/invalid-owner");

        uint256 nonce;
        unchecked {
            nonce = nonces[owner]++;
        }

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                block.chainid == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid),
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline))
            )
        );

        require(_isValidSignature(owner, digest, signature), "SDAO/invalid-permit");

        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice Sets `value` as the allowance of `spender` over `owner`'s tokens, given `owner`'s signed approval.
     * @dev Emits an {Approval} event.
     * @param owner The account setting the allowance through permit.
     * @param spender The account receiving the allowance through permit. CANNOT be the zero address.
     * @param value The amount for allowance through permit.
     * @param deadline Until when the permit is valid. MUST be a timestamp in the future.
     * @param v Ethereum signature recovery ID.
     * @param r Ethereum ECDSA signature output.
     * @param s Ethereum ECDSA signature output.
     *
     * @dev IMPORTANT: The same issues {IERC20-approve} has related to transaction ordering also apply here.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        permit(owner, spender, value, deadline, abi.encodePacked(r, s, v));
    }
}
