// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { FirewallAccess } from "@forta/firewall/FirewallAccess.sol";
import { ISecurityValidator } from "@forta/firewall/SecurityValidator.sol";
import { FirewallRouter } from "@forta/firewall/FirewallRouter.sol";
import { ExternalFirewall } from "@forta/firewall/ExternalFirewall.sol";
import { ICheckpointHook } from "@forta/firewall/interfaces/ICheckpointHook.sol";
import { BaseDeployCore } from "./BaseDeployCore.sol";

contract DeployForta is BaseDeployCore {
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
