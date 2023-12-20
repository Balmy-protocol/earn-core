  // SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

library Utils {
  /**
   * @notice Checks if the potential `superset` array is a superset of the potential `subset` array.
   * @param superset The array to be checked as a potential superset.
   * @param subset The array to be checked as a potential subset.
   * @return if `superset` is a superset of `subset`
   */
  function isSupersetOf(address[] memory superset, address[] memory subset) public pure returns (bool) {
    if (superset.length < subset.length) return false;

    for (uint256 i = 0; i < subset.length; ++i) {
      address token1 = subset[i];
      bool exists = false;
      for (uint256 j = 0; j < superset.length; ++j) {
        if (token1 == superset[j]) {
          exists = true;
          break;
        }
      }
      if (!exists) return false;
    }

    return true;
  }
}
