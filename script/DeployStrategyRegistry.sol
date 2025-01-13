// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { EarnStrategyRegistry } from "src/strategy-registry/EarnStrategyRegistry.sol";
import { BaseDeploy } from "./BaseDeploy.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployStrategyRegistry is BaseDeploy {
  function run() external virtual {
    vm.startBroadcast();
    deployStrategyRegistry();
    vm.stopBroadcast();
  }

  function deployStrategyRegistry() public returns (address) {
    address strategyRegistry =
      deployContract("V2_STRATEGY_REGISTRY", abi.encodePacked(type(EarnStrategyRegistry).creationCode));
    console2.log("Strategy registry:", strategyRegistry);
    return strategyRegistry;
  }
}
