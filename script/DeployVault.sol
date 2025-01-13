// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeploy } from "./BaseDeploy.sol";
import { IEarnStrategyRegistry } from "src/strategy-registry/EarnStrategyRegistry.sol";
import { FirewalledEarnVault } from "src/vault/FirewalledEarnVault.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployVault is BaseDeploy {
  function run() external virtual {
    vm.startBroadcast();
    deployVault();
    vm.stopBroadcast();
  }

  function deployVault() public returns (address) {
    address strategyRegistry = getDeployedAddress("V2_STRATEGY_REGISTRY");
    address nftDescriptor = getDeployedAddress("V1_NFT_DESCRIPTOR");
    address firewallRouter = getDeployedAddress("V2_FROUTER");
    address[] memory initialPauseAdmins = new address[](1);
    initialPauseAdmins[0] = governor;
    address vault = deployContract(
      "V2_VAULT",
      abi.encodePacked(
        type(FirewalledEarnVault).creationCode,
        abi.encode(IEarnStrategyRegistry(strategyRegistry), admin, initialPauseAdmins, nftDescriptor, firewallRouter)
      )
    );
    console2.log("Vault:", vault);
    return vault;
  }
}
