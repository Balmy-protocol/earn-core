// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

library SharesMath {
  using Math for uint256;

  /// @dev To understand this value, please refer to the [README](../README.md).
  uint256 internal constant SHARES_OFFSET_MAGNITUDE = 1e3;

  /**
   * @notice Converts from shares to assets
   */
  function convertToAssets(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares,
    Math.Rounding rounding
  )
    internal
    pure
    returns (uint256)
  {
    return shares.mulDiv(totalAssets + 1, totalShares + SHARES_OFFSET_MAGNITUDE, rounding);
  }

  /**
   * @notice Converts from assets to shares
   */
  function convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares,
    Math.Rounding rounding
  )
    internal
    pure
    returns (uint256)
  {
    // Note: we recommend reading the [README](../README.md) for more information on why this is needed
    if (totalShares == 0) {
      totalAssets = 0;
    }
    return assets.mulDiv(totalShares + SHARES_OFFSET_MAGNITUDE, totalAssets + 1, rounding);
  }
}
