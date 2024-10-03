// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { IEarnVault } from "./IEarnVault.sol";

/**
 * @title The interface for generating a description for a position in a Earn Vault
 * @notice Contracts that implement this interface must return a base64 JSON with the entire description
 */
interface IEarnNFTDescriptor {
  /**
   * @notice Generates a positions's description, both the JSON and the image inside
   * @param vault The address of the Earn Vault
   * @param positionId The position id
   * @return description The position's description
   */
  function tokenURI(IEarnVault vault, uint256 positionId) external view returns (string memory description);
}
