// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { CreateXScript } from "createx-forge/script/CreateXScript.sol";
import { console2 } from "forge-std/console2.sol";

contract BaseDeploy is CreateXScript {
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
    if (
      block.chainid == 1 // Ethereum
        || block.chainid == 10 // Optimism
        || block.chainid == 137 // Polygon
        || block.chainid == 42_161 // Arbitrum
        || block.chainid == 56 // BNB
        || block.chainid == 8453 // Base
        || block.chainid == 100 // Gnosis
        || block.chainid == 43_114 // Avalanche
        || block.chainid == 252 // Fraxtal
        || block.chainid == 1101 // Polygon zkEVM
        || block.chainid == 5000 // Mantle
        || block.chainid == 34_443 // Mode Mainnet
        || block.chainid == 42_220 // Celo
        || block.chainid == 59_144 // Linea Mainnet
        || block.chainid == 81_457 // Blast
        || block.chainid == 534_352 // Scroll
        || block.chainid == 7_777_777 // Zora
        || block.chainid == 1_313_161_554 // Aurora
        || block.chainid == 196 // X Layer
        || block.chainid == 480 // Worldchain
    ) {
      return 0x0D946b7Fd00c9277c558710693076a592c2be27F;
    }
    revert("Unsupported chain");
  }
}
