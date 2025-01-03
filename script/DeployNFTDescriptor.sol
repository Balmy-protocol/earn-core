// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { EarnNFTDescriptor } from "src/nft-descriptor/EarnNFTDescriptor.sol";
import { BaseDeployCore } from "./BaseDeployCore.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployNFTDescriptor is BaseDeployCore {
  function run() external virtual {
    vm.startBroadcast();
    deployNFTDescriptor();
    vm.stopBroadcast();
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
}
