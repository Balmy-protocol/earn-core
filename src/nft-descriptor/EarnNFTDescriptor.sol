// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IEarnNFTDescriptor } from "../interfaces/IEarnNFTDescriptor.sol";
import { IEarnVault } from "../interfaces/IEarnVault.sol";

/// @title Describes NFT token positions
/// @notice Produces a string containing the data URI for a JSON metadata string
contract EarnNFTDescriptor is IEarnNFTDescriptor, Ownable2Step {
  using Strings for uint256;

  string public baseURL;

  constructor(string memory baseURL_, address firstOwner) Ownable(firstOwner) {
    baseURL = baseURL_;
  }

  /// @inheritdoc IEarnNFTDescriptor
  function tokenURI(IEarnVault vault, uint256 positionId) external view returns (string memory) {
    return string(
      abi.encodePacked(
        baseURL,
        block.chainid.toString(),
        "-",
        Strings.toHexString(uint160(address(vault)), 20),
        "-",
        positionId.toString()
      )
    );
  }

  function setBaseURL(string memory _newBaseURL) external onlyOwner {
    baseURL = _newBaseURL;
  }
}
