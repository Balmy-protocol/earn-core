// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IEarnStrategy, StrategyId } from "../../src/vault/EarnVault.sol";
import { IEarnStrategyRegistry } from "../../src/interfaces/IEarnStrategyRegistry.sol";
import { EarnStrategyMock } from "../mocks/EarnStrategyMock.sol";
import { EarnStrategyRegistryMock } from "../mocks/EarnStrategyRegistryMock.sol";

library StrategyUtils {
  function deployStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    address owner
  )
    internal
    returns (EarnStrategyMock strategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    strategy = new EarnStrategyMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(owner, strategy);
  }

  function deployStrategy(address[] memory tokens) internal returns (EarnStrategyMock strategy) {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return strategy = new EarnStrategyMock(tokens, withdrawalTypes);
  }

  function deployStrategy(
    EarnStrategyRegistryMock registry,
    address[] memory tokens
  )
    internal
    returns (StrategyId strategyId, EarnStrategyMock strategy)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return deployStrategy(registry, tokens, withdrawalTypes);
  }

  function deployStrategy(
    EarnStrategyRegistryMock registry,
    address[] memory tokens,
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes
  )
    internal
    returns (StrategyId strategyId, EarnStrategyMock strategy)
  {
    require(tokens.length > 0, "Invalid");
    strategy = new EarnStrategyMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(address(this), strategy);
  }
}
