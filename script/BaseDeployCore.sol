// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { CreateXScript } from "createx-forge/script/CreateXScript.sol";
import { console2 } from "forge-std/console2.sol";

contract BaseDeployCore is CreateXScript {
  address internal governor = vm.envAddress("GOVERNOR");
  address internal admin = getMsig();

  // solhint-disable-next-line no-empty-blocks
  function setUp() public virtual withCreateX {
    //
    // `withCreateX` modifier checks there is a CreateX factory deployed
    // If not, etch it when running within a Forge testing environment (chainID = 31337)
    //
    // This sets `CreateX` for the scripting usage with functions:
    //      https://github.com/pcaversaccio/createx#available-versatile-functions
    //
    // WARNING - etching is not supported towards local explicit Anvil execution with default chainID
    //      This leads to a strange behaviour towards Anvil when Anvil does not have CreateX predeployed
    //      (seamingly correct transactions in the forge simulation even when broadcasted).
    //      Start Anvil with a different chainID, e.g. `anvil --chain-id 1982` to simulate a correct behaviour
    //      of missing CreateX.
    //
    // Behaviour towards external RPCs - this works as expected, i.e. continues if CreateX is deployed
    // and stops when not. (Tested with Tenderly devnets and BuildBear private testnets)
    //
  }

  function deployContract(bytes32 guard, bytes memory creationCode) public returns (address) {
    bytes32 salt = bytes32(abi.encodePacked(msg.sender, hex"00", guard));
    address computedAddress = computeCreate3Address(salt, msg.sender);
    if (computedAddress.code.length > 0) {
      console2.log("Contract already deployed at", computedAddress);
      return computedAddress;
    }
    address deployedAddress = create3(salt, creationCode);
    // solhint-disable-next-line reason-string
    require(computedAddress == deployedAddress, "Computed and deployed address do not match!");
    return deployedAddress;
  }

  function getDeployedAddress(bytes32 guard) public view returns (address) {
    bytes32 salt = bytes32(abi.encodePacked(msg.sender, hex"00", guard));
    address computedAddress = computeCreate3Address(salt, msg.sender);
    require(computedAddress.code.length > 0, "Contract not deployed!");
    return computedAddress;
  }

  // solhint-disable-next-line code-complexity
  function getMsig() public view returns (address) {
    if (block.chainid == 1) {
      // Ethereum
      return 0xEC864BE26084ba3bbF3cAAcF8F6961A9263319C4;
    } else if (block.chainid == 10) {
      // Optimism
      return 0x308810881807189cAe91950888b2cB73A1CC5920;
    } else if (block.chainid == 137) {
      // Polygon
      return 0xCe9F6991b48970d6c9Ef99Fffb112359584488e3;
    } else if (block.chainid == 42_161) {
      // Arbitrum
      return 0x84F4836e8022765Af9FBCE3Bb2887fD826c668f1;
    } else if (block.chainid == 56) {
      // BNB
      return 0x10a5D3b1C0F3639CfB0E554F29c3eFFD912d0C64;
    } else if (block.chainid == 84_531) {
      // Base Goerli
      return 0xD5b9C9c14b3a535C41D385007309DB5d0a6cF57c;
    } else if (block.chainid == 8453) {
      // Base
      return 0x58EDd2E9bCC7eFa5205d5a73Efa160A05dbAC95D;
    } else if (block.chainid == 100) {
      // Gnosis
      return 0xFD7598B46aC9e7B9201B06FF014F22085e155B60;
    } else if (block.chainid == 122) {
      // Fuse
      return 0x5C4fE9D48b6B8938206B47343329572064fdebe2;
    } else if (block.chainid == 1284) {
      // Moonbeam
      return 0xa1667E34fc9a602C38E19246176D28831c5794EB;
    } else if (block.chainid == 42_220) {
      // Celo
      return 0x94F96A6A7bF34e85bfdfeE13987001CAE3A47EEB;
    } else if (block.chainid == 43_114) {
      // Avalanche
      return 0xcD736597565fcdcF85cb9f0b6759bF2E4eab38D2;
    } else if (block.chainid == 59_144) {
      // Linea
      return 0xfCCCba57aa4a51026E3b50ecB377Fc7382aCD9E2;
    }
    return governor;
  }
}
