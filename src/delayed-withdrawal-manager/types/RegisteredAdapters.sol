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
    returns (bool result, uint256 length)
  {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter =
      registeredAdapters[positionId][token];

    result = false;
    RegisteredAdapter memory adapterToCompare = registeredAdapter[length];
    bool shouldContinue = address(adapterToCompare.adapter) != address(0);
    while (shouldContinue) {
      adapterToCompare = registeredAdapter[length];
      if (adapterToCompare.adapter == adapter) result = true;
      shouldContinue = adapterToCompare.isNextFilled;
      unchecked {
        length++;
      }
    }
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
    mapping(uint256 => mapping(address => mapping(uint256 index => RegisteredAdapter registeredAdapter))) storage
      registeredAdapters,
    uint256 positionId,
    address token,
    uint256 index,
    IDelayedWithdrawalAdapter adapter
  )
    internal
  {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter =
      registeredAdapters[positionId][token];
    if (index != 0) registeredAdapter[index - 1].isNextFilled = true;
    registeredAdapter[index] =
      RegisteredAdapter({ adapter: adapter, isNextFilled: address(registeredAdapter[index + 1].adapter) != address(0) });
  }

  function pop(
    mapping(uint256 => mapping(address => mapping(uint256 index => RegisteredAdapter registeredAdapter))) storage
      registeredAdapters,
    uint256 positionId,
    address token,
    uint256 start,
    uint256 end
  )
    internal
  {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter =
      registeredAdapters[positionId][token];

    for (uint256 i = start; i <= end;) {
      delete registeredAdapter[i];
      unchecked {
        ++i;
      }
    }
  }
}
