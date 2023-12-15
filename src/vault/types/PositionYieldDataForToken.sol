// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { CustomUintSizeChecks } from "../libraries/CustomUintSizeChecks.sol";

/**
 * @notice Stores yield data for a specific token and position
 * @dev Occupies 1 slot. Holds:
 *      - Base yield accumulator: the yield accumulator when the position was last updated. Will use 151 bits
 *      - Pre-accounted balance: balance already accounted for. Will use 104 bits
 *      - Position had loss: indicates if the position ever had a loss. Will use 1 bit
 *      To understand why we chose these variable sizes, please refer to the [README](../README.md).
 */
type PositionYieldDataForToken is uint256;

/// @notice A key composed of a position id and a token address
type PositionYieldDataKey is bytes32;

library PositionYieldDataForTokenLibrary {
  using CustomUintSizeChecks for uint256;
  using SafeCast for uint256;

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
    returns (uint256 baseAccumulator, uint256 preAccountedBalance, bool positionHadLoss)
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
    bool newPositionHadLoss,
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
        newPositionHadLoss: newPositionHadLoss ? 1 : 0
      });
    }
  }

  function _decode(PositionYieldDataForToken encoded)
    private
    pure
    returns (uint256 baseYieldAccumulator, uint256 preAccountedBalance, bool positionHadLoss)
  {
    uint256 unwrapped = PositionYieldDataForToken.unwrap(encoded);
    baseYieldAccumulator = unwrapped >> 105;
    preAccountedBalance = (unwrapped >> 1) & 0xffffffffffffffffffffffffff;
    positionHadLoss = unwrapped & 0x1 == 1;
  }

  function _encode(
    uint256 baseYieldAccumulator,
    uint256 preAccountedBalance,
    uint256 newPositionHadLoss
  )
    private
    pure
    returns (PositionYieldDataForToken)
  {
    baseYieldAccumulator.assertFitsInUint151();
    // slither-disable-next-line unused-return
    preAccountedBalance.toUint104();
    return
      PositionYieldDataForToken.wrap((baseYieldAccumulator << 105) | (preAccountedBalance << 1) | newPositionHadLoss);
  }

  function _keyFrom(uint256 positionId, address token) internal pure returns (PositionYieldDataKey) {
    return PositionYieldDataKey.wrap(keccak256(abi.encode(positionId, token)));
  }
}
