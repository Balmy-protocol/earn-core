// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { YieldMath } from "../libraries/YieldMath.sol";

/**
 * @notice Stores yield loss data for a specific token and position
 * @dev Occupies 1 slot. Holds:
 *      - Loss accumulator: the yield loss accumulator when the position was last updated. Will use 248 bits
 *      - Position complete loss events: number of complete loss events processed for the position. Will use 8 bits.
 */

struct PositionYieldLossDataForToken {
  uint248 positionLossAccum;
  uint8 positionCompleteLossEvents;
}

/// @notice A key composed of a position id and a token address
type PositionYieldLossDataKey is bytes32;

library PositionYieldLossDataForTokenLibrary {
  using SafeCast for uint256;

  /**
   * @notice Reads a position's yield data from storage
   */
  function read(
    mapping(PositionYieldLossDataKey => PositionYieldLossDataForToken) storage positionYieldLossData,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (uint256, uint256)
  {
    PositionYieldLossDataForToken memory positionYieldLossDataForToken =
      positionYieldLossData[_keyFrom(positionId, token)];
    if (positionYieldLossDataForToken.positionLossAccum == 0) {
      positionYieldLossDataForToken.positionLossAccum = YieldMath.LOSS_ACCUM_INITIAL;
    }
    return (positionYieldLossDataForToken.positionLossAccum, positionYieldLossDataForToken.positionCompleteLossEvents);
  }

  /**
   * @notice Updates a position's yield data based on the given values
   */
  function update(
    mapping(PositionYieldLossDataKey => PositionYieldLossDataForToken) storage positionYieldLossData,
    uint256 positionId,
    address token,
    uint256 newPositionLossAccum,
    uint256 newPositionCompleteLossEvents
  )
    internal
  {
    positionYieldLossData[_keyFrom(positionId, token)] =
      PositionYieldLossDataForToken(newPositionLossAccum.toUint248(), newPositionCompleteLossEvents.toUint8());
  }

  function _keyFrom(uint256 positionId, address token) internal pure returns (PositionYieldLossDataKey) {
    return PositionYieldLossDataKey.wrap(keccak256(abi.encode(positionId, token)));
  }
}
