// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

library CommonUtils {
  function arrayOf(address account) internal pure returns (address[] memory array) {
    array = new address[](1);
    array[0] = account;
  }

  function arrayOf(uint256 amount) internal pure returns (uint256[] memory array) {
    array = new uint256[](1);
    array[0] = amount;
  }
}
