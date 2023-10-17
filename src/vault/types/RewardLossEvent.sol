// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StrategyId } from "../../types/StrategyId.sol";

/**
 * @notice Stores a loss event that happened in the past, to be able to correctly calculate a position's balance in the
 * future
 * @dev Occupies 2 slot
 */
struct RewardLossEvent {
  /// @notice The yield accumulator prior to the loss event
  uint152 accumPriorToLoss;
  /// @notice The reward token's total balance last recorded before the loss
  uint104 totalBalanceBeforeLoss;
  /// @notice The reward token's total balance after the loss was detected
  uint104 totalBalanceAfterLoss;
}

/// @notice A key composed of a strategy id, token address and event index
type RewardLossEventKey is bytes32;

library RewardLossEventLibrary {
  using SafeCast for uint256;

  /**
   * @notice Reads a loss event from storage
   */
  function read(
    mapping(RewardLossEventKey => RewardLossEvent) storage lossEvents,
    StrategyId strategyId,
    address token,
    uint256 eventIndex
  )
    internal
    view
    returns (RewardLossEvent memory)
  {
    return lossEvents[_keyFrom(strategyId, token, eventIndex)];
  }

  /**
   * @notice Registers a new loss event
   */
  function registerNew(
    mapping(RewardLossEventKey => RewardLossEvent) storage lossEvents,
    StrategyId strategyId,
    address token,
    uint256 eventIndex,
    uint256 accumPriorToLoss,
    uint256 totalBalanceBeforeLoss,
    uint256 totalBalanceAfterLoss
  )
    internal
  {
    lossEvents[_keyFrom(strategyId, token, eventIndex)] = RewardLossEvent({
      accumPriorToLoss: accumPriorToLoss.toUint152(),
      totalBalanceBeforeLoss: totalBalanceBeforeLoss.toUint104(),
      totalBalanceAfterLoss: totalBalanceAfterLoss.toUint104()
    });
  }

  function _keyFrom(
    StrategyId strategyId,
    address token,
    uint256 eventIndex
  )
    internal
    pure
    returns (RewardLossEventKey)
  {
    return RewardLossEventKey.wrap(keccak256(abi.encode(strategyId, token, eventIndex)));
  }
}
