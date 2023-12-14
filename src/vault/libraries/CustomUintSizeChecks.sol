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
  uint256 private constant MAX_UINT_104 = 0xffffffffffffffffffffffffff;
  uint256 private constant MAX_UINT_1 = 0x1;

  function assertFitsInUint151(uint256 value) internal pure {
    _verifySize(value, MAX_UINT_151);
  }

  function assertFitsInUint104(uint256 value) internal pure {
    _verifySize(value, MAX_UINT_104);
  }

  function assertFitsInUint1(uint256 value) internal pure {
    _verifySize(value, MAX_UINT_1);
  }

  function _verifySize(uint256 value, uint256 max) private pure {
    if (value > max) revert UintOverflowed(value, max);
  }
}
