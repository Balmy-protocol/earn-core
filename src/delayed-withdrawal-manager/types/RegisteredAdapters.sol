// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IDelayedWithdrawalAdapter } from "../../interfaces/IDelayedWithdrawalAdapter.sol";

struct RegisteredAdapter {
  IDelayedWithdrawalAdapter adapter;
  bool isFilled;
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

    while (registeredAdapter[i].isFilled) {
      if (registeredAdapter[i].adapter == adapter) return true;
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
    while (registeredAdapter[i].isFilled) {
      unchecked {
        ++i;
      }
    }
    registeredAdapter[i] = RegisteredAdapter({ adapter: adapter, isFilled: true });
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
    registeredAdapters[positionId][token][index] = RegisteredAdapter({ adapter: adapter, isFilled: true });
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

    while (registeredAdapter[length].isFilled) {
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
