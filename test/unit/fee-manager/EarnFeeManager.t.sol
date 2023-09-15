// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnFeeManager, IEarnFeeManager } from "../../../src/fee-manager/EarnFeeManager.sol";
import { Utils } from "../../Utils.sol";
import { StrategyId } from "../../../src/types/StrategyId.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract EarnFeeManagerTest is PRBTest {
  event DefaultPerformanceFeeChanged(uint16 feeBps);
  event SpecificPerformanceFeeChanged(StrategyId strategyId, uint16 feeBps);
  event SpecificPerformanceFeeRemoved(StrategyId strategyId);

  address private superAdmin = address(1);
  address private manageFeeAdmin = address(2);
  uint16 private defaultPerformanceFee = 300;
  EarnFeeManager private feeManager;
  StrategyId private aStrategyId = StrategyId.wrap(1);
  StrategyId private anotherStrategyId = StrategyId.wrap(2);

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

    assertEq(feeManager.defaultPerformanceFee(), defaultPerformanceFee);
  }

  function test_setDefaultPerformanceFee() public {
    uint16 newDefaultPerformanceFee = 5;

    vm.prank(manageFeeAdmin);
    feeManager.setDefaultPerformanceFee(newDefaultPerformanceFee);
    assertEq(feeManager.defaultPerformanceFee(), newDefaultPerformanceFee);
  }

  function test_setPerformanceFeeForStrategyBackToDefault_modifyAndSetBack() public {
    assertEq(feeManager.getPerformanceFeeForStrategy(aStrategyId), defaultPerformanceFee);
    uint16 specificPerformanceFee = defaultPerformanceFee + 2;

    vm.startPrank(manageFeeAdmin);
    feeManager.specifyPerformanceFeeForStrategy(aStrategyId, specificPerformanceFee);
    assertEq(feeManager.getPerformanceFeeForStrategy(aStrategyId), specificPerformanceFee);
    feeManager.setPerformanceFeeForStrategyBackToDefault(aStrategyId);

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

  function test_specifyPerformanceFeeForStrategy_RevertWhenCalledWithoutRole() public {
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

  function test_setPerformanceFee_DoesNotModifyOtherStrategies() public {
    assertEq(
      feeManager.getPerformanceFeeForStrategy(aStrategyId), feeManager.getPerformanceFeeForStrategy(anotherStrategyId)
    );
    uint16 specificPerformanceFee = defaultPerformanceFee - 2;

    vm.prank(manageFeeAdmin);
    feeManager.specifyPerformanceFeeForStrategy(aStrategyId, specificPerformanceFee);
    assertNotEq(
      feeManager.getPerformanceFeeForStrategy(aStrategyId), feeManager.getPerformanceFeeForStrategy(anotherStrategyId)
    );
  }

  function test_specifyPerformanceFeeForStrategy_RevertWhenFeeGreaterThanMaximum() public {
    vm.prank(manageFeeAdmin);
    vm.expectRevert(abi.encodeWithSelector(IEarnFeeManager.FeeGreaterThanMaximum.selector));
    feeManager.specifyPerformanceFeeForStrategy(aStrategyId, 10_000);
  }

  function test_setDefaultPerformanceFee_RevertWhenFeeGreaterThanMaximum() public {
    vm.prank(manageFeeAdmin);
    vm.expectRevert(abi.encodeWithSelector(IEarnFeeManager.FeeGreaterThanMaximum.selector));
    feeManager.setDefaultPerformanceFee(10_000);
  }
}
