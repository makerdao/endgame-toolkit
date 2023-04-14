# Endgame Toolkit

A set of components for the [SubDAO](https://endgame.makerdao.com/subdaos/overview) stack in the context of the
[MakerDAO Endgame](https://endgame.makerdao.com/).

<!-- vim-markdown-toc GFM -->

- [Components](#components)
  - [`SubProxy`](#subproxy)
    - [Interface](#interface)
      - [`rely(address usr)`](#relyaddress-usr)
      - [`deny(address usr)`](#denyaddress-usr)
      - [`exec(address target, bytes memory args) payable returns (bytes memory out)`](#execaddress-target-bytes-memory-args-payable-returns-bytes-memory-out)
  - [`RewardsDistribution`](#rewardsdistribution)
    - [Interface](#interface-1)
- [Contributing](#contributing)
  - [Requirements](#requirements)
  - [Install dependencies](#install-dependencies)
  - [Build](#build)
  - [Run tests](#run-tests)

<!-- vim-markdown-toc -->

## Components

### `SubProxy`

The `SubProxy` is the SubDAO level counter-party of the MakerDAO level [`MCD_PAUSE_PROXY`][mcd-pause-proxy]

The reason a Proxy is required is to isolate the context of execution for spells from the main governance contract to
avoid potential exploits messing with the original contract storage.

This module is heavily inspired by the original [`DSPauseProxy`][ds-pause-proxy] contract, with a few modifications:

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

### `RewardsDistribution`

Rewards are going to be generated through a [`DssVestMintable`][dss-vest] contract and distributed to final users
through a [`StakingRewards`] contract (adapted from [Synthetix][staking-rewards]).

`RewardsDistribution` is the "glue" between these two very distinct contracts. It controls the vesting stream from
`DssVest` and permissionlessly allows for distributing rewards on a predefined schedule controlled by a
`DistributionCalc` contract.

The reason `DistributionCalc` exists is that the reward distribution schedule will not always match the vesting
schedule.

`DssVest` streams can only have a constant distribution rate, while it might be desirable to ramp-up the
rewards so early birds don't have an unfair advantage. Another complicating factor is the presence of a cliff period,
which would cause the tokens accrued from the beginning of the stream up until the cliff to be distributed all at once.

#### Interface

TODO.

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

[mcd-pause-proxy]: https://etherscan.io/address/0xbe8e3e3618f7474f8cb1d074a26affef007e98fb#code
[dss-vest]: https://github.com/makerdao/dss-vest/blob/19a9d663bb3a2737f1f0c763365f1dfc6788aad2/src/DssVest.sol#L223-L225
[ds-pause-proxy]: https://github.com/makerdao/ds-pause/blob/5e798dd96bfaac978cd9fe3c0259b486e8afd213/src/pause.sol#L139-L154
[staking-rewards]: https://github.com/Synthetixio/synthetix/blob/098b7f58a65fab5c2608d1d7e9c8bd56fdcc50d3/contracts/StakingRewards.sol#L9
