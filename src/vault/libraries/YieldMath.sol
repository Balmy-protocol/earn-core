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
// solhint-enable no-unused-import

library YieldMath {
  using SafeCast for uint256;
  using Math for uint256;
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);

  /**
   * @dev We are increasing the precision when storing the yield accumulator, to prevent data loss. We will reduce the
   *      precision back to normal when reading it, so the rest of the code doesn't need to know what we are doing. To
   *      understand why we chose this particular amount, please refer refer to the [README](../README.md).
   */
  uint256 internal constant ACCUM_PRECISION = 1e33;

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
   * @notice Calculates a position's  for a specific token, based on past events and current balance
   * @param positionId The position's id
   * @param token The token to calculate the balance for
   * @param positionShares The amount of shares owned by the position
   * @param newAccumulator The new value for the yield accumulator
   * @param positionRegistry A registry for yield data for each position
   */
  function calculateBalance(
    uint256 positionId,
    address token,
    uint256 positionShares,
    uint256 newAccumulator,
    mapping(PositionYieldDataKey => PositionYieldDataForToken) storage positionRegistry
  )
    internal
    view
    returns (uint256)
  {
    // slither-disable-next-line unused-return
    (uint256 initialAccum, uint256 positionBalance,) = positionRegistry.read(positionId, token);

    positionBalance += YieldMath.calculateEarned({
      initialAccum: initialAccum,
      finalAccum: newAccumulator,
      positionShares: positionShares
    });

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
}
