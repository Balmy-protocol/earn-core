// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IEarnStrategyRegistry, EarnStrategyRegistry } from "src/strategy-registry/EarnStrategyRegistry.sol";
import { FirewalledEarnVault } from "src/vault/FirewalledEarnVault.sol";
import { EarnNFTDescriptor } from "src/nft-descriptor/EarnNFTDescriptor.sol";
import { FirewallAccess } from "@forta/firewall/FirewallAccess.sol";
import { ISecurityValidator } from "@forta/firewall/SecurityValidator.sol";
import { FirewallRouter } from "@forta/firewall/FirewallRouter.sol";
import { ExternalFirewall } from "@forta/firewall/ExternalFirewall.sol";
import { ICheckpointHook } from "@forta/firewall/interfaces/ICheckpointHook.sol";

import { BaseDeployCore } from "./BaseDeployCore.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployCore is BaseDeployCore {
  function run() external virtual {
    vm.startBroadcast();
    deployStrategyRegistry();
    deployNFTDescriptor();
    deployForta();
    deployVault();

    vm.stopBroadcast();
  }

  function deployStrategyRegistry() public returns (address) {
    address strategyRegistry =
      deployContract("V1_STRATEGY_REGISTRY", abi.encodePacked(type(EarnStrategyRegistry).creationCode));
    console2.log("Strategy registry:", strategyRegistry);
    return strategyRegistry;
  }

  function deployNFTDescriptor() public returns (address) {
    address nftDescriptor = deployContract(
      "V1_NFT_DESCRIPTOR",
      abi.encodePacked(
        type(EarnNFTDescriptor).creationCode, abi.encode("https://api.balmy.xyz/v1/earn/metadata/", admin)
      )
    );
    console2.log("NFT descriptor:", nftDescriptor);
    return nftDescriptor;
  }

  function deployVault() public returns (address) {
    address strategyRegistry = getDeployedAddress("V1_STRATEGY_REGISTRY");
    address nftDescriptor = getDeployedAddress("V1_NFT_DESCRIPTOR");
    address firewallRouter = getDeployedAddress("V1_FROUTER");
    address[] memory initialPauseAdmins = new address[](1);
    initialPauseAdmins[0] = governor;
    address vault = deployContract(
      "V1_VAULT",
      abi.encodePacked(
        type(FirewalledEarnVault).creationCode,
        abi.encode(IEarnStrategyRegistry(strategyRegistry), admin, initialPauseAdmins, nftDescriptor, firewallRouter)
      )
    );
    console2.log("Vault:", vault);
    return vault;
  }

  function deployForta() public {
    // FORTA
    bytes32 attesterControllerId = bytes32("3");
    ISecurityValidator validator = ISecurityValidator(0x4d4996b53332f2c64dc6699878408b4B5ec80976);

    address firewallAccess =
      deployContract("V1_FACCESS", abi.encodePacked(type(FirewallAccess).creationCode, abi.encode(msg.sender)));
    address externalFirewall = deployContract(
      "V1_FEXTERNAL",
      abi.encodePacked(
        type(ExternalFirewall).creationCode,
        abi.encode(validator, ICheckpointHook(address(0)), attesterControllerId, firewallAccess)
      )
    );
    deployContract(
      "V1_FROUTER",
      abi.encodePacked(
        type(FirewallRouter).creationCode,
        abi.encode(ExternalFirewall(externalFirewall), FirewallAccess(firewallAccess))
      )
    );
  }
}
