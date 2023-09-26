// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnStrategyRegistry, IEarnStrategyRegistry } from "../../../src/strategy-registry/EarnStrategyRegistry.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { StrategyId, StrategyIdConstants } from "../../../src/types/StrategyId.sol";
import { Token } from "../../../src/libraries/Token.sol";

import { IEarnStrategy } from "../../../src/interfaces/IEarnStrategy.sol";
import { EarnStrategyMock } from "../../mocks/EarnStrategyMock.sol";
import { EarnStrategyBadMock } from "../../mocks/EarnStrategyBadMock.sol";

contract EarnStrategyRegistryTest is PRBTest {
  event StrategyRegistered(address owner, StrategyId strategyId, IEarnStrategy strategy);
  event StrategyUpdateProposed(address owner, StrategyId strategyId, IEarnStrategy strategy);

  EarnStrategyRegistry private strategyRegistry;
  StrategyId private invalidStrategyId = StrategyId.wrap(1000);
  StrategyId private anotherInvalidStrategyId = StrategyId.wrap(1001);
  address private owner = address(1);

  function setUp() public virtual {
    strategyRegistry = new EarnStrategyRegistry();
  }

  function test_getStrategy_ShouldReturnZero_WhenNonExistentStrategyId() public {
    assertEq(address(strategyRegistry.getStrategy(invalidStrategyId)), address(0));
  }

  function test_registerStrategy() public {
    IEarnStrategy aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectEmit();
    emit StrategyRegistered(owner, StrategyIdConstants.INITIAL_STRATEGY_ID, aStrategy);

    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    assertEq(address(strategyRegistry.getStrategy(aRegisteredStrategyId)), address(aStrategy));
    assertEq(owner, strategyRegistry.owner(aRegisteredStrategyId));
    assertTrue(strategyRegistry.assignedId(aStrategy) == aRegisteredStrategyId);
    assertGt(StrategyId.unwrap(aRegisteredStrategyId), StrategyId.unwrap(StrategyIdConstants.NO_STRATEGY));
  }

  function test_registerStrategy_RevertWhen_StrategyIsAlreadyRegistered() public {
    IEarnStrategy aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    strategyRegistry.registerStrategy(owner, aStrategy);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.StrategyAlreadyRegistered.selector));
    strategyRegistry.registerStrategy(owner, aStrategy);
  }

  function test_registerStrategy_RevertWhen_AssetIsNotFirstToken() public {
    address[] memory tokens = new address[](2);
    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(1);
    IEarnStrategy badStrategy = new EarnStrategyBadMock(tokens);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AssetIsNotFirstToken.selector, badStrategy));
    strategyRegistry.registerStrategy(owner, badStrategy);
  }

  function test_registerStrategy_RevertWhen_AddressIsNotStrategy() public {
    IEarnStrategy badStrategy;
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AddressIsNotStrategy.selector, badStrategy));
    strategyRegistry.registerStrategy(owner, badStrategy);
  }

  function test_registerStrategy_MultipleStrategiesRegistered() public {
    IEarnStrategy aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    IEarnStrategy anotherStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    StrategyId anotherRegisteredStrategyId = strategyRegistry.registerStrategy(owner, anotherStrategy);

    assertNotEq(
      address(strategyRegistry.getStrategy(aRegisteredStrategyId)),
      address(strategyRegistry.getStrategy(anotherRegisteredStrategyId))
    );
    assertFalse(strategyRegistry.assignedId(aStrategy) == strategyRegistry.assignedId(anotherStrategy));
  }

  function test_proposeStrategyUpdate() public {
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    EarnStrategyMock anotherStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectEmit();
    emit StrategyUpdateProposed(owner, aRegisteredStrategyId, anotherStrategy);
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_UpdateWithMoreTokens() public {
    address[] memory strategyTokens = new address[](2);
    strategyTokens[0] = Token.NATIVE_TOKEN;
    strategyTokens[1] = address(1);
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(strategyTokens);

    address[] memory newStrategyTokens = new address[](2);
    newStrategyTokens[0] = Token.NATIVE_TOKEN;
    newStrategyTokens[1] = address(2);
    newStrategyTokens[1] = address(1);
    EarnStrategyMock anotherStrategy = StrategyUtils.deployStrategy(newStrategyTokens);
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);

    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_WrongOwner() public {
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    EarnStrategyMock anotherStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    address anotherOwner = address(2);

    vm.expectRevert();
    vm.prank(anotherOwner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_StrategyAlreadyProposedUpdate() public {
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    EarnStrategyMock anotherStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.StrategyAlreadyProposedUpdate.selector));
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_StrategyAlreadyRegistered() public {
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    EarnStrategyMock anotherStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    strategyRegistry.registerStrategy(owner, anotherStrategy);

    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.StrategyAlreadyRegistered.selector));
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_TokensSupportedMismatch() public {
    address[] memory tokens = new address[](2);
    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(1);
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(tokens);
    EarnStrategyMock anotherStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);

    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.TokensSupportedMismatch.selector));
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_AssetMismatch() public {
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(address(1)));
    EarnStrategyMock anotherStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AssetMismatch.selector));
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_AddressIsNotStrategy() public {
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    IEarnStrategy badStrategy;

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AddressIsNotStrategy.selector, badStrategy));
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, badStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_AssetIsNotFirstToken() public {
    EarnStrategyMock aStrategy = StrategyUtils.deployStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);

    address[] memory tokens = new address[](2);
    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(1);
    IEarnStrategy badStrategy = new EarnStrategyBadMock(tokens);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AssetIsNotFirstToken.selector, badStrategy));
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, badStrategy);
  }
}
