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
  RewardLossEventKey, RewardLossEvent, RewardLossEventLibrary
} from "../../../../src/vault/types/RewardLossEvent.sol";
import { StrategyId } from "../../../../src/types/StrategyId.sol";

// solhint-enable no-unused-import

contract YieldMathTest is PRBTest, StdUtils {
  using Math for uint256;
  using Math for uint160;
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);
  using RewardLossEventLibrary for mapping(RewardLossEventKey => RewardLossEvent);

  mapping(PositionYieldDataKey key => PositionYieldDataForToken yieldData) internal positionRegistry;
  mapping(RewardLossEventKey key => RewardLossEvent lossEvent) internal lossEventRegistry;

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
    uint160 positionShares,
    uint104 totalBalance
  )
    public
  {
    totalBalance = uint104(bound(totalBalance, 0, 2 ** 102 - 1));
    previousBalance = uint104(bound(previousBalance, 0, totalBalance));
    newAccumulator = uint152(bound(newAccumulator, 0, 2 ** 150 - 1));
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

    (, uint256 lastRecordedTotalBalance, uint256 totalLossEvents) = positionRegistry.read(1, address(0));

    uint256 currentBalance = YieldMath.calculateBalance(
      1,
      StrategyId.wrap(1),
      address(0),
      positionShares,
      lastRecordedTotalBalance,
      totalBalance,
      totalLossEvents,
      newAccumulator,
      positionRegistry,
      lossEventRegistry
    );
    assertEq(
      currentBalance, positionShares.mulDiv(newAccumulator - initialAccum, YieldMath.ACCUM_PRECISION) + previousBalance
    );
  }

  function testFuzz_calculateBalance_WithLoss(
    uint104 previousBalance,
    uint152 newAccumulator,
    uint160 positionShares,
    uint104 totalBalance
  )
    public
  {
    previousBalance = uint104(bound(previousBalance, 2, 2 ** 102 - 1));
    totalBalance = uint104(bound(totalBalance, 1, previousBalance - 1));
    newAccumulator = uint152(bound(newAccumulator, 0, 2 ** 102 - 1));
    positionShares = uint160(bound(positionShares, 1, 2 ** 102 - 1));

    address token = address(0);

    // Set initial values
    positionRegistry.update({
      positionId: 1,
      token: token,
      newAccumulator: newAccumulator, //newAcumulator == initialAcumulator
      newPositionBalance: previousBalance,
      newProccessedLossEvents: 0,
      newShares: positionShares
    });

    StrategyId strategyId = StrategyId.wrap(1);

    (, uint256 lastRecordedTotalBalance, uint256 totalLossEvents) = positionRegistry.read(1, token);

    lossEventRegistry.registerNew(
      strategyId, token, totalLossEvents++, newAccumulator, lastRecordedTotalBalance, previousBalance
    );

    uint256 currentBalance = YieldMath.calculateBalance({
      positionId: 1,
      strategyId: strategyId,
      token: token,
      positionShares: positionShares,
      lastRecordedBalance: previousBalance,
      totalBalance: totalBalance,
      totalLossEvents: totalLossEvents,
      newAccumulator: newAccumulator,
      positionRegistry: positionRegistry,
      lossEventRegistry: lossEventRegistry
    });

    assertEq(currentBalance, totalBalance);
  }
}
