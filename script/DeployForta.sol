// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { FirewallAccess } from "@forta/firewall/FirewallAccess.sol";
import { ISecurityValidator } from "@forta/firewall/SecurityValidator.sol";
import { FirewallRouter } from "@forta/firewall/FirewallRouter.sol";
import { ExternalFirewall } from "@forta/firewall/ExternalFirewall.sol";
import { ICheckpointHook } from "@forta/firewall/interfaces/ICheckpointHook.sol";
import { BaseDeploy } from "./BaseDeploy.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployForta is BaseDeploy {
  function run() external virtual {
    vm.startBroadcast();
    deployForta();
    vm.stopBroadcast();
  }

  function deployForta() public {
    // FORTA
    bytes32 attesterControllerId = bytes32("3");
    ISecurityValidator validator = ISecurityValidator(0x4d4996b53332f2c64dc6699878408b4B5ec80976);

    address firewallAccess =
      deployContract("V2_FACCESS", abi.encodePacked(type(FirewallAccess).creationCode, abi.encode(msg.sender)));
    address externalFirewall = deployContract(
      "V2_FEXTERNAL",
      abi.encodePacked(
        type(ExternalFirewall).creationCode,
        abi.encode(validator, ICheckpointHook(address(0)), attesterControllerId, firewallAccess)
      )
    );
    address firewallRouter = deployContract(
      "V2_FROUTER",
      abi.encodePacked(
        type(FirewallRouter).creationCode,
        abi.encode(ExternalFirewall(externalFirewall), FirewallAccess(firewallAccess))
      )
    );
    console2.log("Firewall access:", firewallAccess);
    console2.log("External firewall:", externalFirewall);
    console2.log("Firewall router:", firewallRouter);
  }
}
