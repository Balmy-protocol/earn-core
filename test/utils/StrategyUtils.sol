// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IEarnStrategy, StrategyId } from "../../src/vault/EarnVault.sol";
import { IEarnStrategyRegistry } from "../../src/interfaces/IEarnStrategyRegistry.sol";
import { EarnStrategyStateBalanceMock } from "../mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { EarnStrategyRegistryMock } from "../mocks/strategies/EarnStrategyRegistryMock.sol";

library StrategyUtils {
  function deployStateStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    address owner
  )
    internal
    returns (EarnStrategyStateBalanceMock strategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    strategy = new EarnStrategyStateBalanceMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(owner, strategy);
  }

  function deployStateStrategy(address[] memory tokens) internal returns (EarnStrategyStateBalanceMock strategy) {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return strategy = new EarnStrategyStateBalanceMock(tokens, withdrawalTypes);
  }

  function deployStateStrategy(
    EarnStrategyRegistryMock registry,
    address[] memory tokens
  )
    internal
    returns (StrategyId strategyId, EarnStrategyStateBalanceMock strategy)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return deployStateStrategy(registry, tokens, withdrawalTypes);
  }

  function deployStateStrategy(
    EarnStrategyRegistryMock registry,
    address[] memory tokens,
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes
  )
    internal
    returns (StrategyId strategyId, EarnStrategyStateBalanceMock strategy)
  {
    require(tokens.length > 0, "Invalid");
    strategy = new EarnStrategyStateBalanceMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(address(this), strategy);
  }
}
