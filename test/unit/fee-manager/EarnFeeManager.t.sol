// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnFeeManager, IEarnFeeManager } from "../../../src/fee-manager/EarnFeeManager.sol";
import { Utils } from "../../Utils.sol";
import { StrategyId } from "../../../src/types/StrategyId.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract EarnFeeManagerTest is PRBTest {
  address private superAdmin = address(1);
  address private manageFeeAdmin = address(2);
  uint16 private defaultPerformanceFee = 300;
  EarnFeeManager private feeManager;
  StrategyId aStrategyId;

  function setUp() public virtual {
    feeManager = new EarnFeeManager(
      superAdmin,
      Utils.arrayOf(manageFeeAdmin),
      defaultPerformanceFee
    );
  }

  function test_constants() public {
    assertEq(feeManager.MANAGE_FEES_ROLE(), keccak256("MANAGE_FEES_ROLE"));
  }

  function test_constructor() public {
    assertTrue(feeManager.hasRole(feeManager.MANAGE_FEES_ROLE(), manageFeeAdmin));

    // Access control
    assertEq(feeManager.defaultAdminDelay(), 3 days);
    assertEq(feeManager.owner(), superAdmin);
    assertEq(feeManager.defaultAdmin(), superAdmin);
  }

  function test_defaultPerformanceFee() public {
    assertEq(feeManager.defaultPerformanceFee(), defaultPerformanceFee);
  }

  function test_setDefaultPerformanceFeeWithRole() public {
    assertEq(feeManager.defaultPerformanceFee(), defaultPerformanceFee);
    uint16 newDefaultPerformanceFee = 5;

    vm.startPrank(manageFeeAdmin);
    feeManager.setDefaultPerformanceFee(newDefaultPerformanceFee);
    assertNotEq(feeManager.defaultPerformanceFee(), defaultPerformanceFee);
    vm.stopPrank();

    assertEq(feeManager.defaultPerformanceFee(), newDefaultPerformanceFee);
  }

  function test_modifyPerformanceFeeAndSetBackWithRole() public {
    assertEq(feeManager.getPerformanceFeeForStrategy(aStrategyId), defaultPerformanceFee);
    uint16 specificPerformanceFee = 400;

    vm.startPrank(manageFeeAdmin);
    feeManager.specifyPerformanceFeeForStrategy(aStrategyId, specificPerformanceFee);
    assertEq(feeManager.getPerformanceFeeForStrategy(aStrategyId), specificPerformanceFee);
    feeManager.setPerformanceFeeForStrategyBackToDefault(aStrategyId);
    assertNotEq(feeManager.getPerformanceFeeForStrategy(aStrategyId), specificPerformanceFee);
    vm.stopPrank();

    assertEq(feeManager.getPerformanceFeeForStrategy(aStrategyId), defaultPerformanceFee);
  }

  function test_modifyDefaultPerformanceFee_RevertWhenCalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeManager.MANAGE_FEES_ROLE()
      )
    );
    feeManager.setDefaultPerformanceFee(200);
  }

  function test_modifyPerformanceFee_RevertWhenCalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeManager.MANAGE_FEES_ROLE()
      )
    );
    feeManager.specifyPerformanceFeeForStrategy(aStrategyId, 200);
  }

  function test_setPerformanceFeeBackToDefault_RevertWhenCalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeManager.MANAGE_FEES_ROLE()
      )
    );
    feeManager.setPerformanceFeeForStrategyBackToDefault(aStrategyId);
  }
}
