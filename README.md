# SubDAO Pause Proxy

A SubDAO from [MakerDAO Endgame](https://endgame.makerdao.com/subdaos/overview) is a semi-independent and specialized
DAO, with its own governance token, process and workforce.

The SubDAO Pause Proxy is the SubDAO level counter-party of the MakerDAO level
[`MCD_PAUSE_PROXY`](https://etherscan.io/address/0xbe8e3e3618f7474f8cb1d074a26affef007e98fb#code).

The reason a Proxy is required is to isolate the context of execution for spells from the main governance contract to
avoid attempts of exploits.

This module is heavily inspired by the original
[`DSPauseProxy`](https://github.com/makerdao/ds-pause/blob/5e798dd96bfaac978cd9fe3c0259b486e8afd213/src/pause.sol#L139-L154)
contract, with some quality of life improvements:

1. Instead of a single `owner`, it uses the now classic `wards`/`rely`/`deny` pattern from MCD.
2. When the underlying contract call reverts, the original `DSPauseProxy` will revert with a not very informative
   message `ds-pause-delegatecall-error`. This module improves on that by bubbling-up the underlying execution error.

## Interface

### `rely(address usr)`

Grants `usr` access to execute calls through this contract.

### `deny(address usr)`

Revokes `usr` access to execute calls through this contract.

### `exec(address target, bytes memory args) returns (bytes memory out)`

Executes a calldata-encoded call `args` on `target` through `delegatecall`.  
The caller must have been `rely`ed before.
