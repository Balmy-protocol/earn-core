// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { CustomUintSizeChecks } from "../libraries/CustomUintSizeChecks.sol";

/**
 * @notice Stores yield data for a specific token, for all positions in a specific strategy
 * @dev Occupies 1 slot. Holds:
 *      - Base yield accumulator: the yield accumulator when the position was last updated. Will use 150 bits
 *      - Pre-accounted balance: balance already accounted for. Will use 102 bits
 *      - Position complete loss events: number of complete loss events processed for the position. Will use 4 bits.
 *      To understand why we chose these variable sizes, please refer to the [README](../README.md).
 */
type PositionYieldDataForToken is uint256;

/// @notice A key composed of a position id and a token address
type PositionYieldDataKey is bytes32;

library PositionYieldDataForTokenLibrary {
  using CustomUintSizeChecks for uint256;

  PositionYieldDataForToken private constant EMPTY_DATA = PositionYieldDataForToken.wrap(0);

  /**
   * @notice Reads a position's yield data from storage
   */
  function read(
    mapping(PositionYieldDataKey => PositionYieldDataForToken) storage positionYieldData,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (uint256 baseAccumulator, uint256 preAccountedBalance, uint256 proccessedLossEvents)
  {
    return _decode(positionYieldData[_keyFrom(positionId, token)]);
  }

  /**
   * @notice Updates a position's yield data based on the given values
   */
  function update(
    mapping(PositionYieldDataKey => PositionYieldDataForToken) storage positionYieldData,
    uint256 positionId,
    address token,
    uint256 newPositionYieldAccum,
    uint256 newPositionBalance,
    uint256 newPositionProccessedLossEvents,
    uint256 newShares
  )
    internal
  {
    if (newShares == 0 && newPositionBalance == 0) {
      // This is a small optimization that allows us to clear the slot for gas savings
      positionYieldData[_keyFrom(positionId, token)] = EMPTY_DATA;
    } else {
      // TODO: make some gas tests to understand gas savings if we remember the previous value and compare it before
      // writing
      positionYieldData[_keyFrom(positionId, token)] = _encode({
        baseYieldAccumulator: newPositionYieldAccum,
        preAccountedBalance: newPositionBalance,
        positionProcessedCompleteLossEvents: newPositionProccessedLossEvents
      });
    }
  }

  function _decode(PositionYieldDataForToken encoded)
    private
    pure
    returns (uint256 baseYieldAccumulator, uint256 preAccountedBalance, uint256 positionProcessedCompleteLossEvents)
  {
    uint256 unwrapped = PositionYieldDataForToken.unwrap(encoded);
    baseYieldAccumulator = unwrapped >> 106;
    preAccountedBalance = (unwrapped >> 4) & 0x3fffffffffffffffffffffffff;
    positionProcessedCompleteLossEvents = unwrapped & 0xF;
  }

  function _encode(
    uint256 baseYieldAccumulator,
    uint256 preAccountedBalance,
    uint256 positionProcessedCompleteLossEvents
  )
    private
    pure
    returns (PositionYieldDataForToken)
  {
    baseYieldAccumulator.assertFitsInUint150();
    preAccountedBalance.assertFitsInUint102();
    positionProcessedCompleteLossEvents.assertFitsInUint4();
    return PositionYieldDataForToken.wrap(
      (baseYieldAccumulator << 106) | (preAccountedBalance << 4) | positionProcessedCompleteLossEvents
    );
  }

  function _keyFrom(uint256 positionId, address token) internal pure returns (PositionYieldDataKey) {
    return PositionYieldDataKey.wrap(keccak256(abi.encode(positionId, token)));
  }
}
