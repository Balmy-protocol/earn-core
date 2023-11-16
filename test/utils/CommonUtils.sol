// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

library CommonUtils {
  function arrayOf(address account) internal pure returns (address[] memory array) {
    array = new address[](1);
    array[0] = account;
  }

  function arrayOf(address account1, address account2) internal pure returns (address[] memory array) {
    array = new address[](2);
    array[0] = account1;
    array[1] = account2;
  }

  function arrayOf(uint256 amount) internal pure returns (uint256[] memory array) {
    array = new uint256[](1);
    array[0] = amount;
  }

  function arrayOf(uint256 amount1, uint256 amount2) internal pure returns (uint256[] memory array) {
    array = new uint256[](2);
    array[0] = amount1;
    array[1] = amount2;
  }
}
