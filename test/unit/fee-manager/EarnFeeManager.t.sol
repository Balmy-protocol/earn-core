// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnFeeManager } from "../../../src/fee-manager/EarnFeeManager.sol";
import { Utils } from "../../Utils.sol";
import { StrategyId } from "../../../src/types/StrategyId.sol";

contract EarnFeeManagerTest is PRBTest {
  address private manageFeeAdmin = address(1);
  uint16 private defaultPerformanceFee = 300;
  EarnFeeManager private feeManager;

  function setUp() public virtual {
    feeManager = new EarnFeeManager(
      Utils.arrayOf(manageFeeAdmin),
      defaultPerformanceFee
    );
  }

  function test_constants() public {
    assertEq(feeManager.MANAGE_FEES_ROLE(), keccak256("MANAGE_FEES_ROLE"));
  }

  function test_constructor() public {
    assertTrue(feeManager.hasRole(feeManager.MANAGE_FEES_ROLE(), manageFeeAdmin));
  }
}
