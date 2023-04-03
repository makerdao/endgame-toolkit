// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {PauseProxy} from "../src/PauseProxy.sol";

contract DeployPauseProxy is Script {
    function run() public returns (PauseProxy) {
        address owner = vm.envAddress("MCD_PAUSE_PROXY");
        console2.log("Owner:", owner);
        require(owner != address(0), "Deploy: MCD_PAUSE_PROXY not properly set");

        vm.broadcast();

        PauseProxy proxy = new PauseProxy();

        // Rely the pause Proxy
        proxy.rely(owner);
        // Deny the deployer
        proxy.deny(msg.sender);

        return proxy;
    }
}
