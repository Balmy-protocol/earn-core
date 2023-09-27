// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
// solhint-disable no-unused-import
import {
  TotalYieldDataKey,
  TotalYieldDataForToken,
  TotalYieldDataForTokenLibrary,
  StrategyId,
  CustomUintSizeChecks
} from "../../../../src/vault/types/TotalYieldDataForToken.sol";
// solhint-enable no-unused-import

contract TotalYieldDataForTokenTest is PRBTest, StdUtils {
  using TotalYieldDataForTokenLibrary for mapping(TotalYieldDataKey => TotalYieldDataForToken);

  StrategyId internal constant STRATEGY_ID = StrategyId.wrap(1);
  address internal constant TOKEN = address(2);

  mapping(TotalYieldDataKey key => TotalYieldDataForToken yieldData) internal _totalYieldData;

  function test_update_RevertWhen_BalanceIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 150, 2 ** 150 - 1));
    _totalYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newAccumulator: 2 ** 150,
      newTotalBalance: 2 ** 102 - 1,
      newTotalLossEvents: 2 ** 4 - 1
    });
  }

  function test_update_RevertWhen_AccumIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 102, 2 ** 102 - 1));
    _totalYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newAccumulator: 2 ** 150 - 1,
      newTotalBalance: 2 ** 102,
      newTotalLossEvents: 2 ** 4 - 1
    });
  }

  function test_update_RevertWhen_LossEventsIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 4, 2 ** 4 - 1));
    _totalYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newAccumulator: 2 ** 150 - 1,
      newTotalBalance: 2 ** 102 - 1,
      newTotalLossEvents: 2 ** 4
    });
  }

  function testFuzz_update(uint152 accumulator, uint104 totalBalance, uint8 lossEvents) public {
    accumulator = uint152(bound(accumulator, 0, 2 ** 150 - 1));
    totalBalance = uint104(bound(totalBalance, 0, 2 ** 102 - 1));
    lossEvents = uint8(bound(lossEvents, 0, 2 ** 4 - 1));
    _totalYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newAccumulator: accumulator,
      newTotalBalance: totalBalance,
      newTotalLossEvents: lossEvents
    });

    (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, uint256 totalLossEvents) =
      _totalYieldData.read(STRATEGY_ID, TOKEN);
    assertEq(yieldAccumulator, accumulator);
    assertEq(lastRecordedTotalBalance, totalBalance);
    assertEq(totalLossEvents, lossEvents);
  }
}
