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
import { EarnStrategyBadMock } from "../../mocks/strategies/EarnStrategyBadMock.sol";

contract EarnStrategyRegistryTest is PRBTest {
  event StrategyRegistered(address owner, StrategyId strategyId, IEarnStrategy strategy);

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
    IEarnStrategy aStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectEmit();
    emit StrategyRegistered(owner, StrategyIdConstants.INITIAL_STRATEGY_ID, aStrategy);

    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    assertEq(address(strategyRegistry.getStrategy(aRegisteredStrategyId)), address(aStrategy));
    assertEq(owner, strategyRegistry.owner(aRegisteredStrategyId));
    assertTrue(strategyRegistry.assignedId(aStrategy) == aRegisteredStrategyId);
    assertGt(StrategyId.unwrap(aRegisteredStrategyId), StrategyId.unwrap(StrategyIdConstants.NO_STRATEGY));
  }

  function test_registerStrategy_RevertWhen_StrategyIsAlreadyRegistered() public {
    IEarnStrategy aStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

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
    IEarnStrategy aStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    IEarnStrategy anotherStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    StrategyId anotherRegisteredStrategyId = strategyRegistry.registerStrategy(owner, anotherStrategy);

    assertNotEq(
      address(strategyRegistry.getStrategy(aRegisteredStrategyId)),
      address(strategyRegistry.getStrategy(anotherRegisteredStrategyId))
    );
    assertFalse(strategyRegistry.assignedId(aStrategy) == strategyRegistry.assignedId(anotherStrategy));
  }
}
