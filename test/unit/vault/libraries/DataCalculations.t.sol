// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { DataCalculations } from "../../../../src/vault/libraries/DataCalculations.sol";
import { CalculatedDataForToken } from "../../../../src/vault/types/Memory.sol";

contract DataCalculationsTest is PRBTest, StdUtils {
  function test_calculateBalances() public {
    CalculatedDataForToken[] memory calculated = new CalculatedDataForToken[](3);
    calculated[0] = _calculatedWithBalance(-1);
    calculated[1] = _calculatedWithBalance(0);
    calculated[2] = _calculatedWithBalance(1);

    uint256[] memory balances = DataCalculations.calculateBalances(calculated);
    assertEq(balances.length, calculated.length);
    assertEq(balances[0], 0);
    assertEq(balances[1], 0);
    assertEq(balances[2], 1);
  }

  function _calculatedWithBalance(int256 balance) internal pure returns (CalculatedDataForToken memory _calculated) {
    _calculated.positionBalance = balance;
  }
}
