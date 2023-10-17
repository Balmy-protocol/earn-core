// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StrategyId } from "../../types/StrategyId.sol";
// solhint-disable no-unused-import
import { RewardLossEventKey, RewardLossEvent, RewardLossEventLibrary } from "../types/RewardLossEvent.sol";
import {
  PositionYieldDataKey,
  PositionYieldDataForToken,
  PositionYieldDataForTokenLibrary
} from "../types/PositionYieldDataForToken.sol";
// solhint-enable no-unused-import

library YieldMath {
  using SafeCast for uint256;
  using Math for uint256;
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);
  using RewardLossEventLibrary for mapping(RewardLossEventKey => RewardLossEvent);

  /**
   * @dev We are increasing the precision when storing the yield accumulator, to prevent data loss. We will reduce the
   *      precision back to normal when reading it, so the rest of the code doesn't need to know what we are doing. To
   *      understand why we chose this particular amount, please refer refer to the [README](../README.md).
   */
  uint256 internal constant ACCUM_PRECISION = 1e33;

  /// @dev Used to represent a position being created
  uint256 internal constant POSITION_BEING_CREATED = 0;

  /**
   * @dev The maximum amount of loss events supported per strategy and token. After this threshold is met, then all
   *      balances will for that strategy and token will be reported as zero.
   */
  uint256 internal constant MAX_LOSS_EVENTS = 15;

  /**
   * @notice Calculates the new yield accum based on the yielded amount and amount of shares
   * @param currentBalance The current balance for a specific token
   * @param lastRecordedBalance The last recorded balance for a specific token
   * @param previousAccum The previous value of the accum
   * @param totalShares The current total amount of shares
   * @return The new value of the accum
   */
  function calculateAccum(
    uint256 currentBalance,
    uint256 lastRecordedBalance,
    uint256 previousAccum,
    uint256 totalShares
  )
    internal
    pure
    returns (uint256)
  {
    if (totalShares == 0) return 0;
    uint256 yieldPerShare =
      ACCUM_PRECISION.mulDiv(currentBalance - lastRecordedBalance, totalShares, Math.Rounding.Floor);
    return previousAccum + yieldPerShare;
  }

  /**
   * @notice Calculates a position's for a specific token, based on past events and current balance
   * @param positionId The position's id
   * @param strategyId The position's strategy
   * @param token The token to calculate the balance for
   * @param positionShares The amount of shares owned by the position
   * @param lastRecordedBalance The last recorded total balance for the token
   * @param totalBalance The current total balance for the token
   * @param totalLossEvents The total amount of loss events that happened for this strategy and token
   * @param newAccumulator The new value for the yield accumulator
   * @param positionRegistry A registry for yield data for each position
   * @param lossEventRegistry A registry for loss events
   */
  function calculateBalance(
    uint256 positionId,
    StrategyId strategyId,
    address token,
    uint256 positionShares,
    uint256 lastRecordedBalance,
    uint256 totalBalance,
    uint256 totalLossEvents,
    uint256 newAccumulator,
    mapping(PositionYieldDataKey => PositionYieldDataForToken) storage positionRegistry,
    mapping(RewardLossEventKey => RewardLossEvent lossEvent) storage lossEventRegistry
  )
    internal
    view
    returns (uint256)
  {
    if (
      totalLossEvents == MAX_LOSS_EVENTS
        || (totalLossEvents == MAX_LOSS_EVENTS - 1 && totalBalance < lastRecordedBalance)
    ) {
      // We've reached the max amount of loss events. We'll simply report all balances as 0
      return 0;
    }

    (uint256 initialAccum, uint256 positionBalance, uint256 processedLossEvents) =
      positionRegistry.read(positionId, token);

    // The first step of the balance calculation process is to calculate how the balance evolved over time, through loss
    // events. We will calculate how much was earned up until a loss event, and then apply such loss to the position's
    // balance
    while (processedLossEvents < totalLossEvents && processedLossEvents < 15) {
      RewardLossEvent memory lossEvent = lossEventRegistry.read(strategyId, token, processedLossEvents);
      positionBalance += YieldMath.calculateEarned({
        initialAccum: initialAccum,
        finalAccum: lossEvent.accumPriorToLoss,
        positionShares: positionShares
      });
      positionBalance = YieldMath.applyLoss({
        earnedBeforeLoss: positionBalance,
        totalBalanceBeforeLoss: lossEvent.totalBalanceBeforeLoss,
        totalBalanceAfterLoss: lossEvent.totalBalanceAfterLoss
      });
      initialAccum = lossEvent.accumPriorToLoss;
      unchecked {
        ++processedLossEvents;
      }
    }

    // Once we calculated the balance through all losses, we will calculate earned since the last processed loss
    positionBalance += YieldMath.calculateEarned({
      initialAccum: initialAccum,
      finalAccum: newAccumulator,
      positionShares: positionShares
    });

    if (totalBalance < lastRecordedBalance) {
      // If current balance is higher than last recorded, then we are at a new loss event
      positionBalance = YieldMath.applyLoss({
        earnedBeforeLoss: positionBalance,
        totalBalanceBeforeLoss: lastRecordedBalance,
        totalBalanceAfterLoss: totalBalance
      });
    }

    return positionBalance;
  }

  /**
   * @notice Calculates how much was earned by a position in a specific time window, delimited by the given
   *         yield accumulated values
   * @param initialAccum The initial value of the accumulator
   * @param finalAccum The final value of the accumulator
   * @param positionShares The amount of the position's shares
   * @return The balance earned by the position
   */
  function calculateEarned(
    uint256 initialAccum,
    uint256 finalAccum,
    uint256 positionShares
  )
    internal
    pure
    returns (uint256)
  {
    return positionShares.mulDiv(finalAccum - initialAccum, ACCUM_PRECISION, Math.Rounding.Floor);
  }

  /**
   * @notice Applies a loss event to a position's balance
   * @param earnedBeforeLoss How much the position had earned before the loss event
   * @param totalBalanceBeforeLoss The token's total balance before the loss
   * @param totalBalanceAfterLoss The token's total balance after the loss
   * @return The balance earned by the position, after considering the loss
   */
  function applyLoss(
    uint256 earnedBeforeLoss,
    uint256 totalBalanceBeforeLoss,
    uint256 totalBalanceAfterLoss
  )
    internal
    pure
    returns (uint256)
  {
    return earnedBeforeLoss.mulDiv(totalBalanceAfterLoss, totalBalanceBeforeLoss, Math.Rounding.Floor);
  }
}
