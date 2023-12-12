// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
// solhint-disable no-unused-import
import {
  StrategyYieldDataKey,
  StrategyYieldDataForToken,
  StrategyYieldDataForTokenLibrary,
  StrategyId,
  CustomUintSizeChecks
} from "../../../../src/vault/types/StrategyYieldDataForToken.sol";
// solhint-enable no-unused-import

contract StrategyYieldDataForTokenTest is PRBTest, StdUtils {
  using StrategyYieldDataForTokenLibrary for mapping(StrategyYieldDataKey => StrategyYieldDataForToken);

  StrategyId internal constant STRATEGY_ID = StrategyId.wrap(1);
  address internal constant TOKEN = address(2);

  mapping(StrategyYieldDataKey key => StrategyYieldDataForToken yieldData) internal _strategyYieldData;

  function test_update_RevertWhen_BalanceIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 150, 2 ** 150 - 1));
    _strategyYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newStrategyYieldAccum: 2 ** 150,
      newTotalBalance: 2 ** 102 - 1,
      newStrategyCompleteLossEvents: 2 ** 4 - 1
    });
  }

  function test_update_RevertWhen_AccumIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 102, 2 ** 102 - 1));
    _strategyYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newStrategyYieldAccum: 2 ** 150 - 1,
      newTotalBalance: 2 ** 102,
      newStrategyCompleteLossEvents: 2 ** 4 - 1
    });
  }

  function test_update_RevertWhen_LossEventsIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 4, 2 ** 4 - 1));
    _strategyYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newStrategyYieldAccum: 2 ** 150 - 1,
      newTotalBalance: 2 ** 102 - 1,
      newStrategyCompleteLossEvents: 2 ** 4
    });
  }

  function testFuzz_update(uint152 accumulator, uint104 totalBalance, uint8 lossEvents) public {
    accumulator = uint152(bound(accumulator, 0, 2 ** 150 - 1));
    totalBalance = uint104(bound(totalBalance, 0, 2 ** 102 - 1));
    lossEvents = uint8(bound(lossEvents, 0, 2 ** 4 - 1));
    _strategyYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newStrategyYieldAccum: accumulator,
      newTotalBalance: totalBalance,
      newStrategyCompleteLossEvents: lossEvents
    });

    (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, uint256 totalLossEvents) =
      _strategyYieldData.read(STRATEGY_ID, TOKEN);
    assertEq(yieldAccumulator, accumulator);
    assertEq(lastRecordedTotalBalance, totalBalance);
    assertEq(totalLossEvents, lossEvents);
  }
}
