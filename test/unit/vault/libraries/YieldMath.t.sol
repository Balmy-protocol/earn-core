// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { YieldMath } from "../../../../src/vault/libraries/YieldMath.sol";
// solhint-disable no-unused-import
import {
  YieldDataForToken,
  YieldLossDataForToken,
  YieldDataForTokenLibrary
} from "../../../../src/vault/types/YieldDataForToken.sol";
import { StrategyId } from "../../../../src/types/StrategyId.sol";

// solhint-enable no-unused-import

contract YieldMathTest is PRBTest, StdUtils {
  using Math for uint256;
  using Math for uint160;
  using YieldDataForTokenLibrary for mapping(bytes32 => YieldDataForToken);
  using YieldDataForTokenLibrary for mapping(bytes32 => YieldLossDataForToken);

  mapping(bytes32 key => YieldDataForToken yieldData) internal positionRegistry;
  mapping(bytes32 key => YieldLossDataForToken lossAmount) internal positionLossRegistry;

  function testFuzz_calculateAccum_ZeroShares(
    uint256 currentBalance,
    uint256 lastRecordedBalance,
    uint256 previousYieldAccum
  )
    public
  {
    uint256 previousLossAccum = YieldMath.LOSS_ACCUM_INITIAL;

    (uint256 newYieldAccum, uint256 newTotalLossAccum,) =
      YieldMath.calculateAccum(currentBalance, lastRecordedBalance, previousYieldAccum, 0, previousLossAccum, 0);
    if (currentBalance > lastRecordedBalance) {
      assertEq(newYieldAccum, previousYieldAccum);
    } else if (currentBalance == 0 && lastRecordedBalance != 0) {
      assertEq(newYieldAccum, 0);
    } else {
      assertEq(newYieldAccum, previousYieldAccum.mulDiv(newTotalLossAccum, previousLossAccum));
    }
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
    (uint256 newAccum,,) = YieldMath.calculateAccum(
      currentBalance, lastRecordedBalance, previousAccum, totalShares, YieldMath.LOSS_ACCUM_INITIAL, 0
    );
    assertEq(
      newAccum, previousAccum + YieldMath.ACCUM_PRECISION.mulDiv(currentBalance - lastRecordedBalance, totalShares)
    );
  }

  function testFuzz_calculateAccum_WithLoss(
    uint104 currentBalance,
    uint104 lastRecordedBalance,
    uint152 previousAccum,
    uint128 totalShares,
    uint8 completeLossEvents
  )
    public
  {
    totalShares = uint128(bound(totalShares, 1, type(uint256).max));
    lastRecordedBalance = uint104(bound(lastRecordedBalance, 2, type(uint104).max));
    completeLossEvents = uint8(bound(completeLossEvents, 1, YieldMath.MAX_COMPLETE_LOSS_EVENTS - 1));
    currentBalance = uint104(bound(currentBalance, 1, lastRecordedBalance - 1));
    (, uint256 newTotalLossAccum, uint256 newStrategyCompleteLossEvents) = YieldMath.calculateAccum(
      currentBalance, lastRecordedBalance, previousAccum, totalShares, YieldMath.LOSS_ACCUM_INITIAL, completeLossEvents
    );

    assertEq(newTotalLossAccum, uint256(YieldMath.LOSS_ACCUM_INITIAL).mulDiv(currentBalance, lastRecordedBalance));
    assertEq(newStrategyCompleteLossEvents, completeLossEvents);
  }

  function testFuzz_calculateAccum_WithCompleteLoss(
    uint104 lastRecordedBalance,
    uint152 previousAccum,
    uint128 totalShares,
    uint8 completeLossEvents
  )
    public
  {
    totalShares = uint128(bound(totalShares, 1, type(uint256).max));
    lastRecordedBalance = uint104(bound(lastRecordedBalance, 2, type(uint104).max));
    completeLossEvents = uint8(bound(completeLossEvents, 1, YieldMath.MAX_COMPLETE_LOSS_EVENTS - 1));
    uint104 currentBalance = 0;
    (, uint256 newTotalLossAccum, uint256 newStrategyCompleteLossEvents) = YieldMath.calculateAccum(
      currentBalance, lastRecordedBalance, previousAccum, totalShares, YieldMath.LOSS_ACCUM_INITIAL, completeLossEvents
    );

    assertEq(newTotalLossAccum, YieldMath.LOSS_ACCUM_INITIAL);
    assertEq(newStrategyCompleteLossEvents, completeLossEvents + 1);
  }

  function testFuzz_calculateBalance(
    uint104 previousBalance,
    uint152 newPositionYieldAccum,
    uint152 initialAccum,
    uint160 positionShares,
    uint104 totalBalance
  )
    public
  {
    totalBalance = uint104(bound(totalBalance, 2, 2 ** 102 - 1));
    previousBalance = uint104(bound(previousBalance, 1, totalBalance));
    newPositionYieldAccum = uint152(bound(newPositionYieldAccum, 0, 2 ** 150 - 1));
    initialAccum = uint152(bound(initialAccum, 0, newPositionYieldAccum));

    // Set initial values
    positionRegistry.update({
      positionId: 1,
      token: address(0),
      newYieldAccum: initialAccum,
      newBalance: previousBalance,
      newHadLoss: false
    });

    (, uint256 lastRecordedTotalBalance,) = positionRegistry.read(1, address(0));
    uint256 totalLossAccum = YieldMath.LOSS_ACCUM_INITIAL;

    uint256 currentBalance = YieldMath.calculateBalance(
      1,
      address(0),
      positionShares,
      lastRecordedTotalBalance,
      totalBalance,
      totalLossAccum,
      0,
      newPositionYieldAccum,
      positionRegistry,
      positionLossRegistry
    );
    assertEq(
      currentBalance,
      positionShares.mulDiv(newPositionYieldAccum - initialAccum, YieldMath.ACCUM_PRECISION) + previousBalance
    );
  }

  function testFuzz_calculateBalance_WithLoss(
    uint104 previousBalance,
    uint152 newPositionYieldAccum,
    uint160 positionShares,
    uint104 totalBalance
  )
    public
  {
    previousBalance = uint104(bound(previousBalance, 2, 2 ** 102 - 1));
    totalBalance = uint104(bound(totalBalance, 0, previousBalance - 1));
    newPositionYieldAccum = uint152(bound(newPositionYieldAccum, 0, 2 ** 102 - 1));
    positionShares = uint160(bound(positionShares, 1, 2 ** 102 - 1));

    address token = address(0);

    // Set initial values
    positionRegistry.update({
      positionId: 1,
      token: token,
      newYieldAccum: newPositionYieldAccum,
      newBalance: previousBalance,
      newHadLoss: false
    });

    (, uint256 lastRecordedTotalBalance,) = positionRegistry.read(1, token);
    uint256 totalLossAccum = YieldMath.LOSS_ACCUM_INITIAL;

    uint256 currentBalance = YieldMath.calculateBalance({
      positionId: 1,
      token: token,
      positionShares: positionShares,
      lastRecordedBalance: lastRecordedTotalBalance,
      totalBalance: totalBalance,
      newStrategyLossAccum: totalLossAccum,
      newStrategyCompleteLossEvents: 0,
      newStrategyYieldAccum: newPositionYieldAccum,
      positionRegistry: positionRegistry,
      positionLossRegistry: positionLossRegistry
    });

    assertEq(currentBalance, previousBalance);
  }
}
