// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { DeployCore } from "./DeployCore.sol";

contract DeployNFTDescriptor is DeployCore {
  function run() external override {
    vm.startBroadcast();
    DeployCore.deployNFTDescriptor();
    vm.stopBroadcast();
  }
}
