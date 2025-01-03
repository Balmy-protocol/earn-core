// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { DeployCore } from "./DeployCore.sol";

contract DeployVault is DeployCore {
  function run() external override {
    vm.startBroadcast();
    DeployCore.deployVault();
    vm.stopBroadcast();
  }
}
