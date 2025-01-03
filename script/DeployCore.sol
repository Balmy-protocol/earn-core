// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployCore } from "./BaseDeployCore.sol";
import { DeployStrategyRegistry } from "./DeployStrategyRegistry.sol";
import { DeployNFTDescriptor } from "./DeployNFTDescriptor.sol";
import { DeployForta } from "./DeployForta.sol";
import { DeployVault } from "./DeployVault.sol";

contract DeployCore is BaseDeployCore, DeployStrategyRegistry, DeployNFTDescriptor, DeployForta, DeployVault {
  function run() external override(DeployStrategyRegistry, DeployNFTDescriptor, DeployForta, DeployVault) {
    vm.startBroadcast();
    deployStrategyRegistry();
    deployNFTDescriptor();
    deployForta();
    deployVault();

    vm.stopBroadcast();
  }
}
