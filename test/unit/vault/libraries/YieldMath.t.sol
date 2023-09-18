// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { YieldMath } from "../../../../src/vault/libraries/YieldMath.sol";

contract YieldMathTest is PRBTest, StdUtils {
  uint256 private constant MAX_INT_256 = uint256(type(int256).max);

  function testFuzz_calculateAccum_ZeroShares(int256 yielded, int256 previousAccum) public {
    int256 newAccum = YieldMath.calculateAccum(yielded, previousAccum, 0);
    assertEq(newAccum, 0);
  }

  function test_calculateAccum_RoundsTowardsNegativeInfinity() public {
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

  function test_calculateBalance_RoundsTowardsNegativeInfinity() public {
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

  function _boundMaxInt256(uint256 value) internal view returns (uint256) {
    return bound(value, 0, MAX_INT_256);
  }
}
