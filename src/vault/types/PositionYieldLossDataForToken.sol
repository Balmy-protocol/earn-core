// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { YieldMath } from "../libraries/YieldMath.sol";

/// @notice A key composed of a position id and a token address
type PositionYieldLossDataKey is bytes32;

library PositionYieldLossDataForTokenLibrary {
  /**
   * @notice Reads a position's yield data from storage
   */
  function read(
    mapping(PositionYieldLossDataKey => uint256) storage positionYieldLossData,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (uint256)
  {
    uint256 positionLossAccum = positionYieldLossData[_keyFrom(positionId, token)];
    return (positionLossAccum == 0) ? YieldMath.LOSS_ACCUM_INITIAL : positionLossAccum;
  }

  /**
   * @notice Updates a position's yield data based on the given values
   */
  function update(
    mapping(PositionYieldLossDataKey => uint256) storage positionYieldLossData,
    uint256 positionId,
    address token,
    uint256 newPositionLossAccum
  )
    internal
  {
    positionYieldLossData[_keyFrom(positionId, token)] = newPositionLossAccum;
  }

  function _keyFrom(uint256 positionId, address token) internal pure returns (PositionYieldLossDataKey) {
    return PositionYieldLossDataKey.wrap(keccak256(abi.encode(positionId, token)));
  }
}
