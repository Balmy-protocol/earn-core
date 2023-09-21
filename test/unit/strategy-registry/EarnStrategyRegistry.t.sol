// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnStrategyRegistry, IEarnStrategyRegistry } from "../../../src/strategy-registry/EarnStrategyRegistry.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { StrategyId } from "../../../src/types/StrategyId.sol";
import { Token } from "../../../src/libraries/Token.sol";

import { IEarnStrategy } from "../../../src/interfaces/IEarnStrategy.sol";
import { EarnStrategyMock } from "../../mocks/EarnStrategyMock.sol";

contract EarnStrategyRegistryTest is PRBTest {
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
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    assertEq(address(strategyRegistry.getStrategy(aRegisteredStrategyId)), address(aStrategy));
    assertEq(owner, strategyRegistry.owner(aRegisteredStrategyId));
    assertTrue(strategyRegistry.assignedId(aStrategy) == aRegisteredStrategyId);
    assertGt(StrategyId.unwrap(aRegisteredStrategyId), 0);
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
}
