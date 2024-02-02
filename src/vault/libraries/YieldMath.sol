// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
// solhint-disable no-unused-import
import {
  PositionYieldDataKey,
  PositionYieldDataForToken,
  PositionYieldDataForTokenLibrary
} from "../types/PositionYieldDataForToken.sol";
import {
  PositionYieldLossDataKey,
  PositionYieldLossDataForToken,
  PositionYieldLossDataForTokenLibrary
} from "../types/PositionYieldLossDataForToken.sol";
// solhint-enable no-unused-import

library YieldMath {
  using SafeCast for uint256;
  using Math for uint256;
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);
  using PositionYieldLossDataForTokenLibrary for mapping(PositionYieldLossDataKey => PositionYieldLossDataForToken);

  /**
   * @dev We are increasing the precision when storing the yield accumulator, to prevent data loss. We will reduce the
   *      precision back to normal when reading it, so the rest of the code doesn't need to know what we are doing. To
   *      understand why we chose this particular amount, please refer refer to the [README](../README.md).
   */
  uint256 internal constant ACCUM_PRECISION = 1e33;
  // slither-disable-next-line unused-state
  uint248 internal constant LOSS_ACCUM_INITIAL = type(uint248).max;

  /// @dev Used to represent a position being created
  uint256 internal constant POSITION_BEING_CREATED = 0;

  /**
   * @dev The maximum amount of loss events supported per strategy and token. After this threshold is met, then all
   *      balances will be reported as zero for that strategy and token.
   */
  uint8 internal constant MAX_COMPLETE_LOSS_EVENTS = type(uint8).max;

  /**
   * @notice Calculates the new yield accum based on the yielded amount and amount of shares
   * @param currentBalance The current balance for a specific token
   * @param lastRecordedBalance The last recorded balance for a specific token
   * @param previousStrategyYieldAccum The previous value of the yield accum
   * @param totalShares The current total amount of shares
   * @param previousStrategyLossAccum The previous total loss accum
   * @return newStrategyYieldAccum The new value of the yield accum
   * @return newStrategyLossAccum The new value of the loss accum
   */
  function calculateAccum(
    uint256 currentBalance,
    uint256 lastRecordedBalance,
    uint256 previousStrategyYieldAccum,
    uint256 totalShares,
    uint256 previousStrategyLossAccum,
    uint256 previousStrategyCompleteLossEvents
  )
    internal
    pure
    returns (uint256 newStrategyYieldAccum, uint256 newStrategyLossAccum, uint256 newStrategyCompleteLossEvents)
  {
    if (
      (currentBalance == 0 && lastRecordedBalance != 0)
        || previousStrategyCompleteLossEvents == YieldMath.MAX_COMPLETE_LOSS_EVENTS
    ) {
      // If we have just produced a complete loss, or we already reached the max allowed complete losses, then we reset
      // the accumulators
      newStrategyYieldAccum = 0;
      newStrategyLossAccum = YieldMath.LOSS_ACCUM_INITIAL;
      newStrategyCompleteLossEvents = previousStrategyCompleteLossEvents == YieldMath.MAX_COMPLETE_LOSS_EVENTS
        ? previousStrategyCompleteLossEvents
        : previousStrategyCompleteLossEvents + 1;
    } else if (currentBalance < lastRecordedBalance) {
      newStrategyLossAccum = previousStrategyLossAccum.mulDiv(currentBalance, lastRecordedBalance, Math.Rounding.Floor);

      /* 
      The yield accumulator is calculated by multiplying the previous value by currentBalance / lastRecordedBalance,
      same formula for the loss accumulator.
      In this case, to avoid losing rounding, we do the following math:
        newStrategyYieldAccum = previousStrategyYieldAccum * (currentBalance / lastRecordedBalance)
      and:
        newStrategyLossAccum = previousStrategyLossAccum * (currentBalance / lastRecordedBalance)
        newStrategyLossAccum / previousStrategyLossAccum = currentBalance / lastRecordedBalance
      replacing:
        newStrategyYieldAccum = previousStrategyYieldAccum * (currentBalance / lastRecordedBalance)
        newStrategyYieldAccum = previousStrategyYieldAccum * (newStrategyLossAccum / previousStrategyLossAccum)
       */
      newStrategyYieldAccum =
        previousStrategyYieldAccum.mulDiv(newStrategyLossAccum, previousStrategyLossAccum, Math.Rounding.Floor);
    } else if (totalShares == 0) {
      return (previousStrategyYieldAccum, previousStrategyLossAccum, previousStrategyCompleteLossEvents);
    } else {
      uint256 yieldPerShare =
        ACCUM_PRECISION.mulDiv(currentBalance - lastRecordedBalance, totalShares, Math.Rounding.Floor);
      newStrategyYieldAccum = previousStrategyYieldAccum + yieldPerShare;
      newStrategyLossAccum = previousStrategyLossAccum;
      newStrategyCompleteLossEvents = previousStrategyCompleteLossEvents;
    }
  }

  /**
   * @notice Calculates a position's balance for a specific token, based on past events and current strategy's balance
   * @param positionId The position's id
   * @param token The token to calculate the balance for
   * @param positionShares The amount of shares owned by the position
   * @param newStrategyLossAccum The total amount of loss that happened for this strategy and token
   * @param newStrategyCompleteLossEvents The total amount of complete loss events that happened for this strategy and
   * token
   * @param newStrategyYieldAccum The new value for the yield accumulator
   * @param positionRegistry A registry for yield data for each position
   */
  function calculateBalance(
    uint256 positionId,
    address token,
    uint256 positionShares,
    uint256 lastRecordedBalance,
    uint256 totalBalance,
    uint256 newStrategyLossAccum,
    uint256 newStrategyCompleteLossEvents,
    uint256 newStrategyYieldAccum,
    mapping(PositionYieldDataKey => PositionYieldDataForToken) storage positionRegistry,
    mapping(PositionYieldLossDataKey => PositionYieldLossDataForToken) storage positionLossRegistry
  )
    internal
    view
    returns (uint256)
  {
    if (
      positionId == POSITION_BEING_CREATED || newStrategyCompleteLossEvents == MAX_COMPLETE_LOSS_EVENTS
        || (
          totalBalance == 0 && lastRecordedBalance != 0 && newStrategyCompleteLossEvents == MAX_COMPLETE_LOSS_EVENTS - 1
        )
    ) {
      // We've reached the max amount of loss events or the position is being created. We'll simply report all balances
      // as 0
      return 0;
    }

    (uint256 positionYieldAccum, uint256 positionBalance, bool positionHadLoss) =
      positionRegistry.read(positionId, token);
    (uint256 positionLossAccum, uint256 positionProcessedCompleteLossEvents) =
      positionHadLoss ? positionLossRegistry.read(positionId, token) : (YieldMath.LOSS_ACCUM_INITIAL, 0);
    if (positionProcessedCompleteLossEvents < newStrategyCompleteLossEvents) {
      positionBalance = 0;
      positionYieldAccum = 0;
      positionLossAccum = YieldMath.LOSS_ACCUM_INITIAL;
    } else {
      positionBalance = positionBalance.mulDiv(newStrategyLossAccum, positionLossAccum, Math.Rounding.Floor);
    }

    if (totalBalance > 0 || lastRecordedBalance == 0) {
      positionBalance += YieldMath.calculateEarned({
        positionYieldAccum: positionYieldAccum,
        strategyYieldAccum: newStrategyYieldAccum,
        positionShares: positionShares,
        positionLossAccum: positionLossAccum,
        strategyLossAccum: newStrategyLossAccum
      });
    }

    return positionBalance;
  }

  /**
   * @notice Calculates how much was earned by a position in a specific time window, delimited by the given
   *         yield accumulated values
   * @param positionYieldAccum The initial value of the accumulator
   * @param strategyYieldAccum The final value of the accumulator
   * @param positionShares The amount of the position's shares
   * @return The balance earned by the position
   */
  function calculateEarned(
    uint256 positionYieldAccum,
    uint256 strategyYieldAccum,
    uint256 positionShares,
    uint256 positionLossAccum,
    uint256 strategyLossAccum
  )
    internal
    pure
    returns (uint256)
  {
    uint256 positionYieldAccumWithLoss =
      positionYieldAccum.mulDiv(strategyLossAccum, positionLossAccum, Math.Rounding.Ceil);
    return positionYieldAccumWithLoss < strategyYieldAccum
      ? positionShares.mulDiv(strategyYieldAccum - positionYieldAccumWithLoss, ACCUM_PRECISION, Math.Rounding.Floor)
      : 0;
  }
}
