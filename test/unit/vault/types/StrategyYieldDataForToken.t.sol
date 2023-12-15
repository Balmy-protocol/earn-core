// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
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
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 151, 2 ** 151 - 1));
    _strategyYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newStrategyYieldAccum: 2 ** 151,
      newTotalBalance: 2 ** 104 - 1,
      newStrategyHadLoss: true
    });
  }

  function test_update_RevertWhen_AccumIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 104, 2 ** 104));
    _strategyYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newStrategyYieldAccum: 2 ** 151 - 1,
      newTotalBalance: 2 ** 104,
      newStrategyHadLoss: true
    });
  }

  function testFuzz_update(uint152 accumulator, uint104 totalBalance, bool _strategyHadLoss) public {
    accumulator = uint152(bound(accumulator, 0, 2 ** 151 - 1));
    totalBalance = uint104(bound(totalBalance, 0, 2 ** 104 - 1));
    _strategyYieldData.update({
      strategyId: STRATEGY_ID,
      token: TOKEN,
      newStrategyYieldAccum: accumulator,
      newTotalBalance: totalBalance,
      newStrategyHadLoss: _strategyHadLoss
    });

    (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, bool strategyHadLoss) =
      _strategyYieldData.read(STRATEGY_ID, TOKEN);
    assertEq(yieldAccumulator, accumulator);
    assertEq(lastRecordedTotalBalance, totalBalance);
    assertEq(strategyHadLoss, _strategyHadLoss);
  }
}
