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
    returns (bool)
  {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter =
      registeredAdapters[positionId][token];

    uint256 i;
    bool shouldContinue = true;
    while (shouldContinue) {
      RegisteredAdapter memory adapterToCompare = registeredAdapter[i];
      if (adapterToCompare.adapter == adapter) return true;
      shouldContinue = adapterToCompare.isNextFilled;
      unchecked {
        ++i;
      }
    }

    return false;
  }

  /// @notice Registers an adapter for a position and token
  function register(
    mapping(uint256 => mapping(address => mapping(uint256 index => RegisteredAdapter registeredAdapter))) storage
      registeredAdapters,
    uint256 positionId,
    address token,
    IDelayedWithdrawalAdapter adapter
  )
    internal
  {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter =
      registeredAdapters[positionId][token];

    uint256 i;
    RegisteredAdapter memory currentAdapter = registeredAdapter[i];
    bool shouldContinue = address(currentAdapter.adapter) != address(0);
    while (shouldContinue) {
      shouldContinue = currentAdapter.isNextFilled;
      currentAdapter = registeredAdapter[i];
      unchecked {
        ++i;
      }
    }
    if (i > 0) registeredAdapter[i - 1].isNextFilled = true;
    registeredAdapter[i] = RegisteredAdapter({ adapter: adapter, isNextFilled: false });
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
    uint256 amountOfPops
  )
    internal
  {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter =
      registeredAdapters[positionId][token];
    uint256 length;
    bool shouldContinue = address(registeredAdapter[length].adapter) != address(0);
    while (shouldContinue) {
      shouldContinue = registeredAdapter[length].isNextFilled;
      unchecked {
        ++length;
      }
    }
    for (uint256 i = 0; i < amountOfPops;) {
      delete registeredAdapter[length - 1 - i];
      unchecked {
        ++i;
      }
    }
  }
}
