// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IDelayedWithdrawalAdapter } from "../../interfaces/IDelayedWithdrawalAdapter.sol";

struct RegisteredAdapter {
  IDelayedWithdrawalAdapter adapter;
  bool isNextFilled;
}

/// @notice A key composed of a position id and a token address
type PositionIdTokenKey is bytes32;

library RegisteredAdaptersLibrary {
  /// @notice Get all adapters for a position and token
  function get(
    mapping(uint256 => mapping(address => mapping(uint256 index => RegisteredAdapter registeredAdapter))) storage
      registeredAdapters,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter)
  {
    return registeredAdapters[positionId][token];
  }

  /// @notice Checks if an adapter is repeated in the list of registered adapters for a position and token
  function isRepeated(
    mapping(uint256 => mapping(address => mapping(uint256 index => RegisteredAdapter registeredAdapter))) storage
      registeredAdapters,
    uint256 positionId,
    address token,
    IDelayedWithdrawalAdapter adapter
  )
    internal
    view
    returns (bool, uint256)
  {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter =
      registeredAdapters[positionId][token];

    uint256 length = 0;
    bool shouldContinue = true;
    while (shouldContinue) {
      RegisteredAdapter memory adapterToCompare = registeredAdapter[length];
      if (adapterToCompare.adapter == adapter) {
        return (true, 0);
      }
      if (address(adapterToCompare.adapter) != address(0)) {
        unchecked {
          length++;
        }
      }
      shouldContinue = adapterToCompare.isNextFilled;
    }

    return (false, length);
  }

  /// @notice Registers an adapter for a position and token
  function register(
    mapping(uint256 => mapping(address => mapping(uint256 index => RegisteredAdapter registeredAdapter))) storage
      registeredAdapters,
    uint256 positionId,
    address token,
    IDelayedWithdrawalAdapter adapter,
    uint256 length
  )
    internal
  {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter =
      registeredAdapters[positionId][token];

    if (length > 0) registeredAdapter[length - 1].isNextFilled = true;
    registeredAdapter[length] = RegisteredAdapter({ adapter: adapter, isNextFilled: false });
  }

  function set(
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters,
    uint256 index,
    IDelayedWithdrawalAdapter adapter
  )
    internal
  {
    if (index != 0) registeredAdapters[index - 1].isNextFilled = true;
    registeredAdapters[index] = RegisteredAdapter({ adapter: adapter, isNextFilled: false });
  }

  function pop(
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters,
    uint256 start,
    uint256 end
  )
    internal
  {
    for (uint256 i = start; i < end;) {
      delete registeredAdapters[i];
      unchecked {
        ++i;
      }
    }
  }
}
