// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/TUSDI.sol";

contract DeployTUSDI is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        new TUSDI(1_000_000_000 ether);
        vm.stopBroadcast();
    }
}
