// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId } from "../../src/vault/EarnVault.sol";
import { IEarnStrategyRegistry } from "../../src/interfaces/IEarnStrategyRegistry.sol";
import { EarnStrategyStateBalanceMock } from "../mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { EarnStrategyCustomBalanceMock } from "../mocks/strategies/EarnStrategyCustomBalanceMock.sol";
import { EarnStrategyStateBalanceBadMigrationMock } from
  "../mocks/strategies/EarnStrategyStateBalanceBadMigrationMock.sol";
import { EarnStrategyStateBalanceBadTokensMock } from "../mocks/strategies/EarnStrategyStateBalanceBadTokensMock.sol";

import { EarnStrategyStateBalanceBadSignatureMock } from
  "../mocks/strategies/EarnStrategyStateBalanceBadSignatureMock.sol";

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

  function deployBadMigrationStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    address owner
  )
    internal
    returns (EarnStrategyStateBalanceBadMigrationMock strategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    strategy = new EarnStrategyStateBalanceBadMigrationMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(owner, strategy);
  }

  function deployBadSignatureStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens
  )
    internal
    returns (EarnStrategyStateBalanceBadSignatureMock strategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    strategy = new EarnStrategyStateBalanceBadSignatureMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(address(this), strategy);
  }

  function deployStateStrategy(address[] memory tokens) internal returns (EarnStrategyStateBalanceMock strategy) {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return strategy = new EarnStrategyStateBalanceMock(tokens, withdrawalTypes);
  }

  function deployBadTokensStrategy(address[] memory tokens) internal returns (EarnStrategyStateBalanceMock strategy) {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return strategy = new EarnStrategyStateBalanceBadTokensMock(tokens, withdrawalTypes);
  }

  function deployStateStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens
  )
    internal
    returns (StrategyId strategyId, EarnStrategyStateBalanceMock strategy)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return deployStateStrategy(registry, tokens, withdrawalTypes);
  }

  function deployStateStrategy(
    IEarnStrategyRegistry registry,
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

  function deployCustomStrategy(
    IEarnStrategyRegistry registry,
    address asset
  )
    internal
    returns (StrategyId strategyId, EarnStrategyCustomBalanceMock strategy)
  {
    strategy = new EarnStrategyCustomBalanceMock(asset);
    strategyId = registry.registerStrategy(address(this), strategy);
  }
}
