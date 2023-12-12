// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { YieldMath } from "../../../../src/vault/libraries/YieldMath.sol";
// solhint-disable no-unused-import
import {
  PositionYieldDataKey,
  PositionYieldDataForToken,
  PositionYieldDataForTokenLibrary
} from "../../../../src/vault/types/PositionYieldDataForToken.sol";

import {
  PositionYieldLossDataKey,
  PositionYieldLossDataForTokenLibrary
} from "../../../../src/vault/types/PositionYieldLossDataForToken.sol";

import { StrategyId } from "../../../../src/types/StrategyId.sol";

// solhint-enable no-unused-import

contract YieldMathTest is PRBTest, StdUtils {
  using Math for uint256;
  using Math for uint160;
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);
  using PositionYieldLossDataForTokenLibrary for mapping(PositionYieldLossDataKey => uint256);

  mapping(PositionYieldDataKey key => PositionYieldDataForToken yieldData) internal positionRegistry;
  mapping(PositionYieldLossDataKey key => uint256 lossAmount) internal positionLossRegistry;

  function testFuzz_calculateAccum_ZeroShares(
    uint256 currentBalance,
    uint256 lastRecordedBalance,
    uint256 previousAccum
  )
    public
  {
    uint256 previousLossAccum = 1;

    (uint256 newAccum, uint256 newTotalLossAccum,) =
      YieldMath.calculateAccum(currentBalance, lastRecordedBalance, previousAccum, 0, previousLossAccum, 0);
    if (currentBalance > lastRecordedBalance) {
      assertEq(newAccum, previousAccum);
    } else if (currentBalance == 0 && lastRecordedBalance != 0) {
      assertEq(newAccum, 0);
    } else {
      assertEq(newAccum, previousAccum.mulDiv(newTotalLossAccum, previousLossAccum));
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
    uint128 totalShares
  )
    public
  {
    totalShares = uint128(bound(totalShares, 1, type(uint256).max));
    lastRecordedBalance = uint104(bound(lastRecordedBalance, 2, type(uint104).max));
    currentBalance = uint104(bound(currentBalance, 1, lastRecordedBalance - 1));
    (, uint256 newTotalLossAccum,) = YieldMath.calculateAccum(
      currentBalance, lastRecordedBalance, previousAccum, totalShares, YieldMath.LOSS_ACCUM_INITIAL, 0
    );

    assertEq(newTotalLossAccum, YieldMath.LOSS_ACCUM_INITIAL.mulDiv(currentBalance, lastRecordedBalance));
  }

  function testFuzz_calculateAccum_WithCompleteLoss(
    uint104 lastRecordedBalance,
    uint152 previousAccum,
    uint128 totalShares
  )
    public
  {
    totalShares = uint128(bound(totalShares, 1, type(uint256).max));
    lastRecordedBalance = uint104(bound(lastRecordedBalance, 2, type(uint104).max));
    uint104 currentBalance = 0;
    (, uint256 newTotalLossAccum,) = YieldMath.calculateAccum(
      currentBalance, lastRecordedBalance, previousAccum, totalShares, YieldMath.LOSS_ACCUM_INITIAL, 1
    );

    assertEq(newTotalLossAccum, YieldMath.LOSS_ACCUM_INITIAL);
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
      newPositionYieldAccum: initialAccum,
      newPositionBalance: previousBalance,
      newPositionProccessedLossEvents: 0,
      newShares: positionShares
    });

    (, uint256 lastRecordedTotalBalance, uint256 totalLossEvents) = positionRegistry.read(1, address(0));
    uint256 totalLossAccum = YieldMath.LOSS_ACCUM_INITIAL;

    uint256 currentBalance = YieldMath.calculateBalance(
      1,
      address(0),
      positionShares,
      lastRecordedTotalBalance,
      totalBalance,
      totalLossAccum,
      totalLossEvents,
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
      newPositionYieldAccum: newPositionYieldAccum,
      newPositionBalance: previousBalance,
      newPositionProccessedLossEvents: 0,
      newShares: positionShares
    });

    (, uint256 lastRecordedTotalBalance, uint256 strategyCompleteLossEvents) = positionRegistry.read(1, token);
    uint256 totalLossAccum = YieldMath.LOSS_ACCUM_INITIAL;

    uint256 currentBalance = YieldMath.calculateBalance({
      positionId: 1,
      token: token,
      positionShares: positionShares,
      lastRecordedBalance: lastRecordedTotalBalance,
      totalBalance: totalBalance,
      strategyLossAccum: totalLossAccum,
      strategyCompleteLossEvents: strategyCompleteLossEvents,
      newStrategyYieldAccum: newPositionYieldAccum,
      positionRegistry: positionRegistry,
      positionLossRegistry: positionLossRegistry
    });

    assertEq(currentBalance, totalBalance == 0 ? 0 : previousBalance);
  }
}
