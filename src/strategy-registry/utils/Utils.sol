  // SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

library Utils {
  function isSubset(address[] memory array1, address[] memory array2) public pure returns (bool) {
    if (array2.length < array1.length) return false;

    for (uint256 i = 0; i < array1.length;) {
      address token1 = array1[i];
      bool exists = false;
      for (uint256 j = 0; j < array2.length;) {
        if (token1 == array2[j]) {
          exists = true;
          break;
        }
        unchecked {
          ++j;
        }
      }
      if (!exists) return false;
      unchecked {
        ++i;
      }
    }

    return true;
  }
}
