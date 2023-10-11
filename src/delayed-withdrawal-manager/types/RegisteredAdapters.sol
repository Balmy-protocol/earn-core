// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IDelayedWithdrawalAdapter } from "../../interfaces/IDelayedWithdrawalAdapter.sol";

struct RegisteredAdapters {
  IDelayedWithdrawalAdapter[] adapters;
}

/// @notice A key composed of a position id and a token address
type PositionIdTokenKey is bytes32;

library RegisteredAdaptersLibrary {
  /// @notice Get all adapters for a position and token
  function get(
    mapping(PositionIdTokenKey => RegisteredAdapters) storage registeredAdapters,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (IDelayedWithdrawalAdapter[] memory)
  {
    return registeredAdapters[_keyFrom(positionId, token)].adapters;
  }

  /// @notice Checks if an adapter is repeated in the list of registered adapters for a position and token
  function isRepeated(
    mapping(PositionIdTokenKey => RegisteredAdapters) storage registeredAdapters,
    uint256 positionId,
    address token,
    IDelayedWithdrawalAdapter adapter
  )
    internal
    view
    returns (bool)
  {
    IDelayedWithdrawalAdapter[] memory adapters = registeredAdapters[_keyFrom(positionId, token)].adapters;
    for (uint256 i; i < adapters.length;) {
      if (adapters[i] == adapter) return true;
      unchecked {
        ++i;
      }
    }
    return false;
  }

  /// @notice Registers an adapter for a position and token
  function register(
    mapping(PositionIdTokenKey => RegisteredAdapters) storage registeredAdapters,
    uint256 positionId,
    address token,
    IDelayedWithdrawalAdapter adapter
  )
    internal
  {
    registeredAdapters[_keyFrom(positionId, token)].adapters.push(adapter);
  }

  function move(
    mapping(PositionIdTokenKey => RegisteredAdapters) storage registeredAdapters,
    uint256 positionId,
    address token,
    uint256 from,
    uint256 to
  )
    internal
  {
    if (from != to) {
      IDelayedWithdrawalAdapter[] storage adapters = registeredAdapters[_keyFrom(positionId, token)].adapters;
      adapters[to] = adapters[from];
    }
  }

  function pop(
    mapping(PositionIdTokenKey => RegisteredAdapters) storage registeredAdapters,
    uint256 positionId,
    address token,
    uint256 times
  )
    internal
  {
    IDelayedWithdrawalAdapter[] storage adapters = registeredAdapters[_keyFrom(positionId, token)].adapters;
    for (uint256 i; i < times && i < adapters.length;) {
      adapters.pop();
      unchecked {
        ++i;
      }
    }
  }

  function _keyFrom(uint256 positionId, address token) internal pure returns (PositionIdTokenKey) {
    return PositionIdTokenKey.wrap(keccak256(abi.encode(positionId, token)));
  }
}
