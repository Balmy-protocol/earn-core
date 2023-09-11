// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

library Utils {
  function arrayOf(address account) internal pure returns (address[] memory array) {
    array = new address[](1);
    array[0] = account;
  }
}
