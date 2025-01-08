// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { FirewalledEarnVault } from "src/vault/FirewalledEarnVault.sol";
import { ExternalFirewall } from "@forta/firewall/ExternalFirewall.sol";
import {
  FirewallAccess,
  FIREWALL_ADMIN_ROLE,
  PROTOCOL_ADMIN_ROLE,
  CHECKPOINT_EXECUTOR_ROLE,
  TRUSTED_ATTESTER_ROLE
} from "@forta/firewall/FirewallAccess.sol";
import { Checkpoint, Activation } from "@forta/firewall/interfaces/Checkpoint.sol";
import { BaseDeploy } from "./BaseDeploy.sol";
import { DeployStrategyRegistry } from "./DeployStrategyRegistry.sol";
import { DeployNFTDescriptor } from "./DeployNFTDescriptor.sol";
import { DeployForta } from "./DeployForta.sol";
import { DeployVault } from "./DeployVault.sol";

contract DeployCore is BaseDeploy, DeployStrategyRegistry, DeployNFTDescriptor, DeployForta, DeployVault {
  function run() external override(DeployStrategyRegistry, DeployNFTDescriptor, DeployForta, DeployVault) {
    vm.startBroadcast();
    deployStrategyRegistry();
    deployNFTDescriptor();
    deployForta();
    deployVault();
    configureCheckpoints();
    vm.stopBroadcast();
  }

  function configureCheckpoints() private {
    address firewallRouter = getDeployedAddress("V1_FROUTER");
    FirewallAccess firewallAccess = FirewallAccess(getDeployedAddress("V1_FACCESS"));
    ExternalFirewall externalFirewall = ExternalFirewall(getDeployedAddress("V1_FEXTERNAL"));
    address vault = getDeployedAddress("V1_VAULT");
    bytes32 DEFAULT_ADMIN_ROLE = firewallAccess.DEFAULT_ADMIN_ROLE();

    /// will renounce later below
    firewallAccess.grantRole(FIREWALL_ADMIN_ROLE, msg.sender);
    firewallAccess.grantRole(PROTOCOL_ADMIN_ROLE, msg.sender);

    firewallAccess.grantRole(DEFAULT_ADMIN_ROLE, admin);
    firewallAccess.grantRole(PROTOCOL_ADMIN_ROLE, admin);
    firewallAccess.grantRole(FIREWALL_ADMIN_ROLE, admin);

    /// let protected contract execute checkpoints on the external firewall
    firewallAccess.grantRole(CHECKPOINT_EXECUTOR_ROLE, vault);
    firewallAccess.grantRole(CHECKPOINT_EXECUTOR_ROLE, firewallRouter);

    // Forta needs this address to be a trusted attester
    firewallAccess.grantRole(TRUSTED_ATTESTER_ROLE, 0x6988Da4A0600cd9472e2CaF9F6cD9Ee4412A273e);

    Checkpoint memory checkpoint =
      Checkpoint({ threshold: 0, refStart: 4, refEnd: 36, activation: Activation.AlwaysActive, trustedOrigin: false });

    externalFirewall.setCheckpoint(FirewalledEarnVault(payable(vault)).createPosition.selector, checkpoint);
    externalFirewall.setCheckpoint(FirewalledEarnVault(payable(vault)).increasePosition.selector, checkpoint);
    externalFirewall.setCheckpoint(FirewalledEarnVault(payable(vault)).withdraw.selector, checkpoint);
    externalFirewall.setCheckpoint(FirewalledEarnVault(payable(vault)).specialWithdraw.selector, checkpoint);

    firewallAccess.renounceRole(FIREWALL_ADMIN_ROLE, msg.sender);
    firewallAccess.renounceRole(PROTOCOL_ADMIN_ROLE, msg.sender);
    firewallAccess.renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }
}
