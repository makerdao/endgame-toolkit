# Endgame Toolkit

A set of components for the [SubDAO](https://endgame.makerdao.com/subdaos/overview) stack in the context of the
[MakerDAO Endgame](https://endgame.makerdao.com/).

- [Components](#components)
  - [`SubProxy`](#subproxy)
    - [Interface](#interface)
      - [`rely(address usr)`](#relyaddress-usr)
      - [`deny(address usr)`](#denyaddress-usr)
      - [`exec(address target, bytes memory args) payable returns (bytes memory out)`](#execaddress-target-bytes-memory-args-payable-returns-bytes-memory-out)
- [Contributing](#contributing)
  - [Requirements](#requirements)
  - [Install dependencies](#install-dependencies)
  - [Run tests](#run-tests)

## Components

### `SubProxy`

The `SubProxy` is the SubDAO level counter-party of the MakerDAO level
[`MCD_PAUSE_PROXY`](https://etherscan.io/address/0xbe8e3e3618f7474f8cb1d074a26affef007e98fb#code).

The reason a Proxy is required is to isolate the context of execution for spells from the main governance contract to
avoid potential exploits messing with the original contract storage.

This module is heavily inspired by the original
[`DSPauseProxy`](https://github.com/makerdao/ds-pause/blob/5e798dd96bfaac978cd9fe3c0259b486e8afd213/src/pause.sol#L139-L154)
contract, with a few modifications:

1. Instead of a single `owner`, it uses the now classic `wards`/`rely`/`deny` pattern from MCD.
2. The `exec` function is `payable`.

#### Interface

##### `rely(address usr)`

Grants `usr` access to execute calls through this contract.

##### `deny(address usr)`

Revokes `usr` access to execute calls through this contract.

##### `exec(address target, bytes memory args) payable returns (bytes memory out)`

Executes a calldata-encoded call `args` on `target` through `delegatecall`.  
The caller must have been `rely`ed before.

## Contributing

### Requirements

- [Foundry](https://github.com/foundry-rs/foundry)
- [Node.js](https://nodejs.org/)
- [Yarn 1.x](https://classic.yarnpkg.com/lang/en/)

We use Foundry for all Solidity things and Node.js + Yarn to manage devtools, such as linting and formatting.

### Install dependencies

After cloning the repo, run:

```bash
# 1. Install solhint, prettier, husky and other tools
yarn install
# 2. Install Foundry dependencies
forge update
```

### Build

**⚠️ ATTENTION:** The order of execution is important here.

```bash
# 1. Build the Solidity 0.6.x contract
FOUNDRY_PROFILE=0_6_x forge build
# 2. Build the default Solidity 0.8.x contracts
forge build
```

Notice that if you use `forge build --force`, the `out/` directory is going to be erased.

### Run tests

```bash
forge test -vvv
```
