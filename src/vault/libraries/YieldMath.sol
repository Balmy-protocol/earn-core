// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SignedMath } from "@openzeppelin/contracts/utils/math/SignedMath.sol";

library YieldMath {
  using SafeCast for uint256;
  using Math for uint256;
  using SignedMath for int256;

  /**
   * @dev We are increasing the precision when storing the yield accumulator, to prevent data loss. We will reduce the
   *      precision back to normal when reading it, so the rest of the code doesn't need to know what we are doing. To
   *      understand why we chose this particular amount, please refer refer to the [README](../README.md).
   */
  uint256 internal constant ACCUM_PRECISION = 1e33;

  /**
   * @notice Takes the current and last recorded balance and calculates yielded tokens, and the new value for earned
   *         fees
   * @param currentBalance The current amount of balance
   * @param lastRecordedBalance The last recorded amount of balance
   * @param lastRecordedEarnedFees The last recorded amount of earned fees
   * @param feeBps The fees to charge, in bps
   * @return yielded How much was yielded since the last update
   * @return newTotalEarnedFees New total of earned fees
   */
  function calculateYielded(
    uint256 currentBalance,
    uint256 lastRecordedBalance,
    uint256 lastRecordedEarnedFees,
    uint256 feeBps
  )
    internal
    pure
    returns (int256 yielded, uint256 newTotalEarnedFees)
  {
    yielded = currentBalance.toInt256() - lastRecordedBalance.toInt256();
    int256 feesEarnedSinceLastUpdate = signedMulDiv(feeBps, yielded, 10_000);
    int256 signedLastRecordedEarnedFees = lastRecordedEarnedFees.toInt256();

    // Note: this is the same as signedLastRecordedEarnedFees + feesEarnedSinceLastUpdate < 0
    if (signedLastRecordedEarnedFees < -feesEarnedSinceLastUpdate) {
      // If there was a negative yield, then we'll use some of the earned fees to pay for users. But we'll make sure to
      // not leave earned fees in negative
      feesEarnedSinceLastUpdate = -signedLastRecordedEarnedFees;
    }
    newTotalEarnedFees = uint256(signedLastRecordedEarnedFees + feesEarnedSinceLastUpdate);
    yielded -= feesEarnedSinceLastUpdate;
  }

  /**
   * @notice Calculates the new yield accum based on the yielded amount and amount of shares
   * @param yielded How much was yielded since the last update
   * @param previousAccum The previous value of the accum
   * @param totalShares The current total amount of shares
   * @return newAccum The new value of the accum
   */
  function calculateAccum(
    int256 yielded,
    int256 previousAccum,
    uint256 totalShares
  )
    internal
    pure
    returns (int256 newAccum)
  {
    if (totalShares == 0) return 0;
    int256 yieldPerShare = signedMulDiv(ACCUM_PRECISION, yielded, totalShares);
    newAccum = previousAccum + yieldPerShare;
  }

  /**
   * @notice Calculates a position's balance based on the accums
   * @dev Take into account that the balance could be negative
   * @param preAccountedBalance Any amount of pre-accounted balance
   * @param currentAccum The current value of the accum
   * @param baseAccum The base value of the accum
   * @param positionShares The amount of the position's shares
   * @return The position's balance
   */
  function calculateBalance(
    int256 preAccountedBalance,
    int256 currentAccum,
    int256 baseAccum,
    uint256 positionShares
  )
    internal
    pure
    returns (int256)
  {
    return signedMulDiv(positionShares, currentAccum - baseAccum, ACCUM_PRECISION) + preAccountedBalance;
  }

  /**
   * @notice Performs a signed mul div, by supporting up to uint256 bits of precision. It will always round to negative
   *         negative infinity
   * @param x A part of the numerator
   * @param y The other part of the numerator, can be signed
   * @param denominator The denominator
   * @return result The result of the multipliation and division
   */
  function signedMulDiv(uint256 x, int256 y, uint256 denominator) internal pure returns (int256 result) {
    // We always round towards negative infinity so that any funds lost in precision are assigned to the vault
    // instead of the positions. By doing so, we can guarantee the vault will always be able to cover all withdrawals.
    return y >= 0
      ? x.mulDiv(uint256(y), denominator, Math.Rounding.Floor).toInt256()
      : -x.mulDiv(uint256(-y), denominator, Math.Rounding.Ceil).toInt256();
  }
}
