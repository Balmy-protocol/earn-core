// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
// solhint-disable no-unused-import
import {
  PositionYieldDataKey,
  PositionYieldDataForToken,
  PositionYieldDataForTokenLibrary,
  CustomUintSizeChecks
} from "../../../../src/vault/types/PositionYieldDataForToken.sol";
// solhint-enable no-unused-import

contract PositionYieldDataForTokenTest is PRBTest, StdUtils {
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);

  uint256 internal constant POSITION_ID = 1;
  address internal constant TOKEN = address(2);

  mapping(PositionYieldDataKey key => PositionYieldDataForToken yieldData) internal _positionYieldData;

  function test_update_RevertWhen_BalanceIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 150, 2 ** 150 - 1));
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newAccumulator: 2 ** 150,
      newPositionBalance: 2 ** 102 - 1,
      newProccessedLossEvents: 2 ** 4 - 1,
      newShares: 1
    });
  }

  function test_update_RevertWhen_AccumIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 102, 2 ** 102 - 1));
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newAccumulator: 2 ** 150 - 1,
      newPositionBalance: 2 ** 102,
      newProccessedLossEvents: 2 ** 4 - 1,
      newShares: 1
    });
  }

  function test_update_RevertWhen_LossEventsIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 4, 2 ** 4 - 1));
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newAccumulator: 2 ** 150 - 1,
      newPositionBalance: 2 ** 102 - 1,
      newProccessedLossEvents: 2 ** 4,
      newShares: 1
    });
  }

  function testFuzz_update(uint152 accumulator, uint104 totalBalance, uint8 lossEvents) public {
    accumulator = uint152(bound(accumulator, 0, 2 ** 150 - 1));
    totalBalance = uint104(bound(totalBalance, 0, 2 ** 102 - 1));
    lossEvents = uint8(bound(lossEvents, 0, 2 ** 4 - 1));
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newAccumulator: accumulator,
      newPositionBalance: totalBalance,
      newProccessedLossEvents: lossEvents,
      newShares: 1
    });

    (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, uint256 totalLossEvents) =
      _positionYieldData.read(POSITION_ID, TOKEN);
    assertEq(yieldAccumulator, accumulator);
    assertEq(lastRecordedTotalBalance, totalBalance);
    assertEq(totalLossEvents, lossEvents);
  }

  function test_update_SharesAndPositionIsZero() public {
    // Set some values
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newAccumulator: 2 ** 150 - 1,
      newPositionBalance: 2 ** 102 - 1,
      newProccessedLossEvents: 2 ** 4 - 1,
      newShares: 1
    });

    // Update it again with zero shares and balance
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newAccumulator: 2 ** 150 - 1,
      newPositionBalance: 0,
      newProccessedLossEvents: 2 ** 4 - 1,
      newShares: 0
    });

    // Assert it was cleared
    (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, uint256 totalLossEvents) =
      _positionYieldData.read(POSITION_ID, TOKEN);
    assertEq(yieldAccumulator, 0);
    assertEq(lastRecordedTotalBalance, 0);
    assertEq(totalLossEvents, 0);
  }
}
