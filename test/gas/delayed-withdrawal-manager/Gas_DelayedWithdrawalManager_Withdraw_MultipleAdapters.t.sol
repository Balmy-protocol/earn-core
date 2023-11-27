// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnVault, IEarnVault, StrategyId } from "../../../src/vault/EarnVault.sol";
import { EarnStrategyRegistry, IEarnStrategyRegistry } from "../../../src/strategy-registry/EarnStrategyRegistry.sol";
import { IEarnStrategy } from "../../../src/interfaces/IEarnStrategy.sol";
import {
  DelayedWithdrawalManager,
  IDelayedWithdrawalManager,
  IDelayedWithdrawalAdapter
} from "../../../src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { INFTPermissions, IERC721 } from "@mean-finance/nft-permissions/interfaces/INFTPermissions.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { EarnStrategyStateBalanceMock } from "../../mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { Token } from "../../../src/libraries/Token.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { ERC20MintableBurnableMock } from "../../mocks/ERC20/ERC20MintableBurnableMock.sol";
import { BaseDelayedWithdrawalGasTest } from "./BaseDelayedWithdrawalGasTest.sol";

contract GasDelayedWithdrawalManagerWithdraw is BaseDelayedWithdrawalGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  function setUp() public virtual override {
    super.setUp();

    // setUp
    IDelayedWithdrawalAdapter adapter1 = strategy.delayedWithdrawalAdapter(tokens[0]);
    vm.startPrank(address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], tokenByPosition[positions[0]]);
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);
    vm.stopPrank();

    IDelayedWithdrawalAdapter adapter2 = strategy.delayedWithdrawalAdapter(tokens[1]);
    vm.prank(address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[2], tokenByPosition[positions[2]]);

    // Update strategy to register a new adapter
    IEarnStrategyRegistry strategyRegistry = delayedWithdrawalManager.vault().STRATEGY_REGISTRY();
    IEarnStrategy newStrategy = StrategyUtils.deployStateStrategy(tokens);
    strategyRegistry.proposeStrategyUpdate(strategyId, newStrategy);
    vm.warp(block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY()); //Waiting for the delay...
    strategyRegistry.updateStrategy(strategyId);

    // Register new strategy adapter
    adapter2 = newStrategy.delayedWithdrawalAdapter(tokenByPosition[positions[1]]);
    vm.prank(address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);

    vm.prank(address(owner));
  }

  function test_Gas_withdraw_twoAdapters() public {
    delayedWithdrawalManager.withdraw(positions[1], tokenByPosition[positions[1]], address(10));
  }
}
