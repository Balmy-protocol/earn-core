// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { StdUtils } from "forge-std/StdUtils.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { EarnVault, StrategyId, IEarnNFTDescriptor } from "../../../src/vault/EarnVault.sol";
import { EarnStrategyCustomBalanceMock } from "../../mocks/strategies/EarnStrategyCustomBalanceMock.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { TokenManager } from "./helpers/TokenManager.sol";
import { StrategyHandler } from "./handlers/StrategyHandler.sol";
import { VaultHandler } from "./handlers/VaultHandler.sol";

contract EarnVaultInvariantTest is StdInvariant, StdUtils, StdAssertions {
  using StrategyUtils for EarnStrategyRegistryMock;

  // Vault
  EarnVault internal vault;
  // Mocks
  EarnStrategyRegistryMock internal strategyRegistry;
  EarnStrategyCustomBalanceMock internal strategy;
  // Helpers
  TokenManager internal tokenManager;
  // Handlers
  VaultHandler internal vaultHandler;
  StrategyHandler internal strategyHandler;

  function setUp() public virtual {
    tokenManager = new TokenManager({ tokensToDeploy: 50 });
    strategyRegistry = new EarnStrategyRegistryMock();
    IEarnNFTDescriptor nftDescriptor;
    StrategyId strategyId;
    (strategyId, strategy) = strategyRegistry.deployCustomStrategy(tokenManager.getRandomToken());
    vault = new EarnVault(strategyRegistry, address(1), new address[](0), nftDescriptor);

    vaultHandler = new VaultHandler(strategy, strategyId, vault);

    strategyHandler = new StrategyHandler(strategy, vault, tokenManager);

    targetContract(address(vaultHandler));
    targetContract(address(strategyHandler));

    // Prevent these contracts from being fuzzed as `msg.sender`.
    address[] memory allTokens = tokenManager.allTokens();
    for (uint256 i; i < allTokens.length; i++) {
      excludeSender(allTokens[i]);
    }
  }

  function invariant_sumOfAllBalancesLteTotalBalance() public {
    (address[] memory tokens, uint256[] memory strategyBalances) = strategy.totalBalances();
    uint256[] memory totalBalances = new uint256[](tokens.length);

    for (uint256 positionId = 1; positionId <= vault.totalSupply(); positionId++) {
      (, uint256[] memory balances,,) = vault.position(positionId);
      for (uint256 i; i < tokens.length; i++) {
        totalBalances[i] += balances[i];
      }
    }

    for (uint256 i; i < tokens.length; i++) {
      assertTrue(totalBalances[i] <= strategyBalances[i]);
    }
  }
}
