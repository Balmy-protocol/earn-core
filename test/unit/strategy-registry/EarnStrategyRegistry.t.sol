// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnStrategyRegistry, IEarnStrategyRegistry } from "../../../src/strategy-registry/EarnStrategyRegistry.sol";
import { Utils } from "../../Utils.sol";
import { StrategyId } from "../../../src/types/StrategyId.sol";

import { IEarnStrategy } from "../../../src/interfaces/IEarnStrategy.sol";

contract EarnStrategyRegistryTest is PRBTest {
  IEarnStrategyRegistry private strategyRegistry;
  StrategyId private invalidStrategyId = StrategyId.wrap(1000);
  StrategyId private anotherInvalidStrategyId = StrategyId.wrap(1001);
  address private owner = address(1);
  IEarnStrategy private aStrategy;

  function setUp() public virtual {
    strategyRegistry = new EarnStrategyRegistry();
  }

  function test_getStrategy_ShouldReturnZero_WhenNonExistentStrategyId() public {
    assertEq(address(strategyRegistry.getStrategy(invalidStrategyId)), address(0));
  }

  function test_registerStrategy() public {
    StrategyId aRegisteredStrategy = strategyRegistry.registerStrategy(owner, aStrategy);
    assertEq(address(strategyRegistry.getStrategy(aRegisteredStrategy)), address(aStrategy));
    assertGt(StrategyId.unwrap(aRegisteredStrategy), 0);
  }
}
