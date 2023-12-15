// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

/**
 * @title Custom Uint Size Checks
 * @notice A small library to make sure that uint values can fit in custom sizes
 */
library CustomUintSizeChecks {
  /// @notice Thrown when a value overflows
  error UintOverflowed(uint256 value, uint256 max);

  uint256 private constant MAX_UINT_151 = 0x7fffffffffffffffffffffffffffffffffffff;

  function assertFitsInUint151(uint256 value) internal pure {
    _verifySize(value, MAX_UINT_151);
  }

  function _verifySize(uint256 value, uint256 max) private pure {
    if (value > max) revert UintOverflowed(value, max);
  }
}
