// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
// solhint-disable no-unused-import
import {
  PositionYieldDataKey,
  PositionYieldDataForToken,
  PositionYieldDataForTokenLibrary
} from "../types/PositionYieldDataForToken.sol";
import {
  PositionYieldLossDataKey, PositionYieldLossDataForTokenLibrary
} from "../types/PositionYieldLossDataForToken.sol";
// solhint-enable no-unused-import

library YieldMath {
  using SafeCast for uint256;
  using Math for uint256;
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);
  using PositionYieldLossDataForTokenLibrary for mapping(PositionYieldLossDataKey => uint256);

  /**
   * @dev We are increasing the precision when storing the yield accumulator, to prevent data loss. We will reduce the
   *      precision back to normal when reading it, so the rest of the code doesn't need to know what we are doing. To
   *      understand why we chose this particular amount, please refer refer to the [README](../README.md).
   */
  uint256 internal constant ACCUM_PRECISION = 1e33;
  uint256 internal constant LOSS_ACCUM_PRECISION = 1e18;
  // slither-disable-next-line unused-state-variable
  uint256 internal constant LOSS_ACCUM_INITIAL = type(uint256).max / LOSS_ACCUM_PRECISION;

  /// @dev Used to represent a position being created
  uint256 internal constant POSITION_BEING_CREATED = 0;

  /**
   * @dev The maximum amount of loss events supported per strategy and token. After this threshold is met, then all
   *      balances will for that strategy and token will be reported as zero.
   */
  uint8 internal constant MAX_TOTAL_LOSS_EVENTS = 15;

  /**
   * @notice Calculates the new yield accum based on the yielded amount and amount of shares
   * @param currentBalance The current balance for a specific token
   * @param lastRecordedBalance The last recorded balance for a specific token
   * @param previousAccum The previous value of the accum
   * @param totalShares The current total amount of shares
   * @param currentTotalLossAccum The current total loss accum
   * @return newYieldAccum The new value of the accum
   * @return newTotalLossAccum The new total loss accum
   */
  function calculateAccum(
    uint256 currentBalance,
    uint256 lastRecordedBalance,
    uint256 previousAccum,
    uint256 totalShares,
    uint256 currentTotalLossAccum
  )
    internal
    pure
    returns (uint256 newYieldAccum, uint256 newTotalLossAccum)
  {
    if (currentBalance < lastRecordedBalance) {
      newTotalLossAccum = currentTotalLossAccum.mulDiv(currentBalance, lastRecordedBalance, Math.Rounding.Floor)
        * YieldMath.LOSS_ACCUM_PRECISION / YieldMath.LOSS_ACCUM_PRECISION;
      newYieldAccum = previousAccum.mulDiv(newTotalLossAccum, currentTotalLossAccum, Math.Rounding.Floor);
    } else if (totalShares == 0) {
      return (previousAccum, currentTotalLossAccum);
    } else {
      uint256 yieldPerShare =
        ACCUM_PRECISION.mulDiv(currentBalance - lastRecordedBalance, totalShares, Math.Rounding.Floor);
      newYieldAccum = previousAccum + yieldPerShare;
      newTotalLossAccum = currentTotalLossAccum;
    }
  }

  /**
   * @notice Calculates a position's balance for a specific token, based on past events and current strategy's balance
   * @param positionId The position's id
   * @param token The token to calculate the balance for
   * @param positionShares The amount of shares owned by the position
   * @param totalLossAccum The total amount of loss that happened for this strategy and token
   * @param totalLossEvents The total amount of loss events that happened for this strategy and token
   * @param newAccumulator The new value for the yield accumulator
   * @param positionRegistry A registry for yield data for each position
   */
  function calculateBalance(
    uint256 positionId,
    address token,
    uint256 positionShares,
    uint256 lastRecordedBalance,
    uint256 totalBalance,
    uint256 totalLossAccum,
    uint256 totalLossEvents,
    uint256 newAccumulator,
    mapping(PositionYieldDataKey => PositionYieldDataForToken) storage positionRegistry,
    mapping(PositionYieldLossDataKey => uint256) storage positionLossRegistry
  )
    internal
    view
    returns (uint256)
  {
    if (
      positionId == POSITION_BEING_CREATED || totalLossEvents == MAX_TOTAL_LOSS_EVENTS
        || (totalLossEvents == MAX_TOTAL_LOSS_EVENTS - 1 && totalBalance < lastRecordedBalance && totalBalance == 0)
    ) {
      // We've reached the max amount of loss events or the position is being created. We'll simply report all balances
      // as 0
      return 0;
    }

    (uint256 initialAccum, uint256 positionBalance, uint256 processedTotalLossEvents) =
      positionRegistry.read(positionId, token);
    uint256 lossAccum = positionLossRegistry.read(positionId, token);
    if (processedTotalLossEvents < totalLossEvents) {
      positionBalance = 0;
      initialAccum = 0;
      lossAccum = YieldMath.LOSS_ACCUM_INITIAL;
    } else {
      positionBalance = positionBalance.mulDiv(totalLossAccum, lossAccum, Math.Rounding.Floor);
    }

    positionBalance += YieldMath.calculateEarned({
      initialAccum: initialAccum,
      finalAccum: newAccumulator,
      positionShares: positionShares,
      lossAccum: lossAccum,
      totalLossAccum: totalLossAccum
    });

    if (totalBalance < lastRecordedBalance && totalBalance == 0) {
      positionBalance = 0;
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
    uint256 positionShares,
    uint256 lossAccum,
    uint256 totalLossAccum
  )
    internal
    pure
    returns (uint256)
  {
    uint256 initialAccumWithLoss = initialAccum.mulDiv(totalLossAccum, lossAccum, Math.Rounding.Ceil);
    return initialAccumWithLoss < finalAccum
      ? positionShares.mulDiv(finalAccum - initialAccumWithLoss, ACCUM_PRECISION, Math.Rounding.Floor)
      : 0;
  }
}
