// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { YieldMath } from "../../../../src/vault/libraries/YieldMath.sol";
import {
  PositionYieldDataKey,
  PositionYieldDataForToken,
  PositionYieldDataForTokenLibrary
} from "../../../../src/vault/types/PositionYieldDataForToken.sol";

contract YieldMathTest is PRBTest, StdUtils {
  using Math for uint256;
  using Math for uint160;
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);

  mapping(PositionYieldDataKey => PositionYieldDataForToken) positionRegistry;

  function testFuzz_calculateAccum_ZeroShares(
    uint256 currentBalance,
    uint256 lastRecordedBalance,
    uint256 previousAccum
  )
    public
  {
    uint256 newAccum = YieldMath.calculateAccum(currentBalance, lastRecordedBalance, previousAccum, 0);
    assertEq(newAccum, 0);
  }

  function testFuzz_calculateAccum(
    uint104 currentBalance,
    uint104 lastRecordedBalance,
    uint152 previousAccum,
    uint128 totalShares
  )
    public
  {
    totalShares = uint128(bound(totalShares, 1, type(uint256).max));
    lastRecordedBalance = uint104(bound(lastRecordedBalance, 0, currentBalance));
    uint256 newAccum = YieldMath.calculateAccum(currentBalance, lastRecordedBalance, previousAccum, totalShares);
    assertEq(
      newAccum, previousAccum + YieldMath.ACCUM_PRECISION.mulDiv(currentBalance - lastRecordedBalance, totalShares)
    );
  }

  function testFuzz_calculateBalance(
    uint104 previousBalance,
    uint152 newAccumulator,
    uint152 initialAccum,
    uint160 positionShares
  )
    public
  {
    previousBalance = uint104(bound(previousBalance, 0, 2**102 - 1));
    newAccumulator = uint152(bound(newAccumulator, 0, 2**150 - 1));
    initialAccum = uint152(bound(initialAccum, 0, newAccumulator));

    // Set initial values
    positionRegistry.update({
      positionId: 1,
      token: address(0),
      newAccumulator: initialAccum,
      newPositionBalance: previousBalance,
      newProccessedLossEvents: 0,
      newShares: positionShares
    });

    uint256 newAccum = YieldMath.calculateBalance(1, address(0), positionShares, newAccumulator, positionRegistry);
    assertEq(
      newAccum, positionShares.mulDiv(newAccumulator - initialAccum, YieldMath.ACCUM_PRECISION) + previousBalance
    );
  }
}
