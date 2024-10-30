// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
// solhint-disable no-unused-import
import {
  YieldDataForToken,
  YieldDataForTokenLibrary,
  CustomUintSizeChecks
} from "../../../../src/vault/types/YieldDataForToken.sol";
// solhint-enable no-unused-import

contract YieldDataForTokenTest is PRBTest, StdUtils {
  using YieldDataForTokenLibrary for mapping(bytes32 => YieldDataForToken);

  uint256 internal constant POSITION_ID = 1;
  address internal constant TOKEN = address(2);

  mapping(bytes32 key => YieldDataForToken yieldData) internal _positionYieldData;

  function test_update_RevertWhen_BalanceIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(CustomUintSizeChecks.UintOverflowed.selector, 2 ** 151, 2 ** 151 - 1));
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newYieldAccum: 2 ** 151,
      newBalance: 2 ** 104 - 1,
      newHadLoss: true
    });
  }

  function test_update_RevertWhen_AccumIsTooBig() public {
    vm.expectRevert(abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 104, 2 ** 104));
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newYieldAccum: 2 ** 151 - 1,
      newBalance: 2 ** 104,
      newHadLoss: true
    });
  }

  function testFuzz_update(uint152 accumulator, uint104 totalBalance, bool _positionHadLoss) public {
    accumulator = uint152(bound(accumulator, 0, 2 ** 151 - 1));
    totalBalance = uint104(bound(totalBalance, 0, 2 ** 104 - 1));
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newYieldAccum: accumulator,
      newBalance: totalBalance,
      newHadLoss: _positionHadLoss
    });

    (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, bool positionHadLoss) =
      _positionYieldData.read(POSITION_ID, TOKEN);
    assertEq(yieldAccumulator, accumulator);
    assertEq(lastRecordedTotalBalance, totalBalance);
    assertEq(positionHadLoss, _positionHadLoss);
  }

  function test_clear() public {
    // Set some values
    _positionYieldData.update({
      positionId: POSITION_ID,
      token: TOKEN,
      newYieldAccum: 2 ** 151 - 1,
      newBalance: 2 ** 104 - 1,
      newHadLoss: true
    });

    // Clear
    _positionYieldData.clear({ positionId: POSITION_ID, token: TOKEN });

    // Assert it was cleared
    (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, bool positionHadLoss) =
      _positionYieldData.read(POSITION_ID, TOKEN);
    assertEq(yieldAccumulator, 0);
    assertEq(lastRecordedTotalBalance, 0);
    assertFalse(positionHadLoss);
  }
}
