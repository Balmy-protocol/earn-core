// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { CalculatedDataForToken, CalculatedDataLibrary } from "../../../../src/vault/types/CalculatedDataForToken.sol";

contract CalculatedDataForTokenTest is PRBTest, StdUtils {
  function test_extractBalances() public {
    CalculatedDataForToken[] memory calculated = new CalculatedDataForToken[](3);
    calculated[0] = _calculatedWithBalance(0);
    calculated[1] = _calculatedWithBalance(2);
    calculated[2] = _calculatedWithBalance(999);

    uint256[] memory balances = CalculatedDataLibrary.extractBalances(calculated, 13);
    assertEq(balances.length, calculated.length + 1);
    assertEq(balances[0], 13);
    assertEq(balances[1], 0);
    assertEq(balances[2], 2);
    assertEq(balances[3], 999);
  }

  function _calculatedWithBalance(uint256 balance) internal pure returns (CalculatedDataForToken memory _calculated) {
    _calculated.positionBalance = balance;
  }
}
