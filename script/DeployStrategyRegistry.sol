// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { DeployCore } from "./DeployCore.sol";

contract DeployStrategyRegistry is DeployCore {
  function run() external override {
    vm.startBroadcast();
    DeployCore.deployStrategyRegistry();
    vm.stopBroadcast();
  }
}
