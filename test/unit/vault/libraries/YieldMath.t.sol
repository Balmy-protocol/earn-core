// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SignedMath } from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { YieldMath } from "../../../../src/vault/libraries/YieldMath.sol";

contract YieldMathTest is PRBTest, StdUtils {
  uint256 private constant MAX_INT_256 = uint256(type(int256).max);

  using Math for uint256;
  using SignedMath for int256;

  function testFuzz_calculateYielded_NoYield(uint256 balance, uint104 lastRecordedEarnedFees, uint16 feeBps) public {
    feeBps = _boundFees(feeBps);
    balance = _boundMaxInt256(balance);

    (int256 yielded, uint256 newTotalEarnedFees) = YieldMath.calculateYielded({
      currentBalance: balance,
      lastRecordedBalance: balance,
      lastRecordedEarnedFees: lastRecordedEarnedFees,
      feeBps: feeBps
    });

    assertEq(yielded, 0);
    assertEq(newTotalEarnedFees, lastRecordedEarnedFees);
  }

  function testFuzz_calculateYielded_PositiveYield(
    uint256 lastRecordedBalance,
    uint256 currentBalance,
    uint128 lastRecordedEarnedFees,
    uint16 feeBps
  )
    public
  {
    currentBalance = bound(currentBalance, 1, MAX_INT_256);
    lastRecordedBalance = bound(lastRecordedBalance, 0, currentBalance);
    feeBps = _boundFees(feeBps);

    (int256 yielded, uint256 newTotalEarnedFees) = YieldMath.calculateYielded({
      currentBalance: currentBalance,
      lastRecordedBalance: lastRecordedBalance,
      lastRecordedEarnedFees: lastRecordedEarnedFees,
      feeBps: feeBps
    });

    uint256 fee = uint256(_calculateFees(currentBalance, lastRecordedBalance, feeBps));
    assertEq(uint256(yielded), currentBalance - lastRecordedBalance - fee);
    assertEq(newTotalEarnedFees, lastRecordedEarnedFees + fee);
  }

  function testFuzz_calculateYielded_NegativeYield(
    uint256 lastRecordedBalance,
    uint256 currentBalance,
    uint104 lastRecordedEarnedFees,
    uint16 feeBps
  )
    public
  {
    lastRecordedBalance = bound(lastRecordedBalance, 1, MAX_INT_256);
    currentBalance = bound(currentBalance, 0, lastRecordedBalance);
    feeBps = _boundFees(feeBps);

    (int256 yielded, uint256 newTotalEarnedFees) = YieldMath.calculateYielded({
      currentBalance: currentBalance,
      lastRecordedBalance: lastRecordedBalance,
      lastRecordedEarnedFees: lastRecordedEarnedFees,
      feeBps: feeBps
    });
    int256 fee = _calculateFees(currentBalance, lastRecordedBalance, feeBps);
    bool willUseAllEarnedFees = lastRecordedEarnedFees < fee.abs();
    fee = willUseAllEarnedFees ? -int256(uint256(lastRecordedEarnedFees)) : fee;
    assertEq(yielded, int256(currentBalance) - int256(lastRecordedBalance) - fee);
    assertEq(newTotalEarnedFees, willUseAllEarnedFees ? 0 : lastRecordedEarnedFees - fee.abs());
  }

  function testFuzz_calculateAccum_ZeroShares(int256 yielded, int256 previousAccum) public {
    int256 newAccum = YieldMath.calculateAccum(yielded, previousAccum, 0);
    assertEq(newAccum, 0);
  }

  function test_calculateAccum_RoundsTowardsMinusInfinity() public {
    uint256 totalShares = YieldMath.ACCUM_PRECISION * 2;

    // Basically we are doing 5 / 2
    assertEq(YieldMath.calculateAccum(5, 0, totalShares), 2);

    // Basically we are doing -5 / 2
    assertEq(YieldMath.calculateAccum(-5, 0, totalShares), -3);
  }

  function testFuzz_calculateAccum_DoesNotOverflow(int128 yielded, int152 previousAccum, uint128 totalShares) public {
    vm.assume(totalShares > 0);
    int256 newAccum = YieldMath.calculateAccum(yielded, previousAccum, totalShares);
    assertEq(newAccum, previousAccum + YieldMath.signedMulDiv(YieldMath.ACCUM_PRECISION, yielded, totalShares));
  }

  function test_calculateBalance_RoundsTowardsMinusInfinity() public {
    int256 currentAccum = int256(YieldMath.ACCUM_PRECISION) - 1;

    // Basically we are doing (ACCUM_PRECISION - 1) / ACCUM_PRECISION
    assertEq(YieldMath.calculateBalance(0, currentAccum, 0, 1), 0);

    // Basically we are doing -(ACCUM_PRECISION - 1) / ACCUM_PRECISION
    assertEq(YieldMath.calculateBalance(0, -currentAccum, 0, 1), -1);
  }

  function testFuzz_calculateBalance_DoesNotOverflow(
    int104 preAccountedBalance,
    int152 currentAccum,
    int152 baseAccum,
    uint160 positionShares
  )
    public
  {
    int256 newAccum = YieldMath.calculateBalance(preAccountedBalance, currentAccum, baseAccum, positionShares);
    assertEq(
      newAccum,
      YieldMath.signedMulDiv(positionShares, int256(currentAccum) - baseAccum, YieldMath.ACCUM_PRECISION)
        + preAccountedBalance
    );
  }

  function _calculateFees(uint256 x, uint256 y, uint256 feeBps) internal pure returns (int256) {
    return YieldMath.signedMulDiv(feeBps, int256(x) - int256(y), 10_000);
  }

  function _boundFees(uint16 feeBps) internal view returns (uint16) {
    return uint16(bound(feeBps, 0, 100));
  }

  function _boundMaxInt256(uint256 value) internal view returns (uint256) {
    return bound(value, 0, MAX_INT_256);
  }
}
