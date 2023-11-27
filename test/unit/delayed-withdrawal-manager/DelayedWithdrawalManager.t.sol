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

contract DelayedWithdrawalManagerTest is PRBTest {
  event DelayedWithdrawalRegistered(uint256 positionId, address token, address adapter);
  event WithdrawnFunds(uint256 positionId, address token, address recipient, uint256 withdrawn);

  using StrategyUtils for IEarnStrategyRegistry;

  DelayedWithdrawalManager private delayedWithdrawalManager;

  uint256[] private positions;
  mapping(uint256 position => address token) private tokenByPosition;
  IEarnStrategy private strategy;
  StrategyId private strategyId;
  address[] private tokens = new address[](2);
  address private owner = address(3);

  function setUp() public virtual {
    IEarnStrategyRegistry strategyRegistry = new EarnStrategyRegistry();
    EarnVault vault = new EarnVault(strategyRegistry, address(1), CommonUtils.arrayOf(address(2)));
    ERC20MintableBurnableMock erc20 = new ERC20MintableBurnableMock();
    erc20.approve(address(vault), type(uint256).max);

    uint104 amountToDeposit1 = 1_000_000;
    uint104 amountToDeposit2 = 1_000_001;
    uint104 amountToDeposit3 = 1_000_003;
    erc20.mint(address(this), amountToDeposit3);
    vm.deal(address(this), uint256(amountToDeposit1) + amountToDeposit2 + amountToDeposit3);

    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(erc20);

    uint256 position;
    (strategyId, strategy) = strategyRegistry.deployStateStrategy(tokens);

    (position,) = vault.createPosition{ value: amountToDeposit1 }(
      strategyId, tokens[0], amountToDeposit1, owner, PermissionUtils.buildEmptyPermissionSet(), ""
    );
    positions.push(position);
    tokenByPosition[position] = tokens[0];

    (position,) = vault.createPosition{ value: amountToDeposit2 }(
      strategyId, tokens[0], amountToDeposit2, owner, PermissionUtils.buildEmptyPermissionSet(), ""
    );
    positions.push(position);
    tokenByPosition[position] = tokens[0];

    (position,) = vault.createPosition(
      strategyId, tokens[1], amountToDeposit3, owner, PermissionUtils.buildEmptyPermissionSet(), ""
    );
    positions.push(position);
    tokenByPosition[position] = tokens[1];
    delayedWithdrawalManager = new DelayedWithdrawalManager(vault);
  }

  function test_registerDelayedWithdraw() public {
    address token = tokens[0];
    IDelayedWithdrawalAdapter adapter = strategy.delayedWithdrawalAdapter(token);
    vm.prank(address(adapter));
    vm.expectEmit();
    emit DelayedWithdrawalRegistered(positions[0], token, address(adapter));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], tokenByPosition[positions[0]]);
  }

  function test_registerDelayedWithdraw_MultiplePositions() public {
    IDelayedWithdrawalAdapter adapter1 = strategy.delayedWithdrawalAdapter(tokens[0]);
    vm.startPrank(address(adapter1));

    vm.expectEmit();
    emit DelayedWithdrawalRegistered(positions[0], tokens[0], address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], tokenByPosition[positions[0]]);

    vm.expectEmit();
    emit DelayedWithdrawalRegistered(positions[1], tokens[0], address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);
    vm.stopPrank();

    IDelayedWithdrawalAdapter adapter2 = strategy.delayedWithdrawalAdapter(tokens[1]);
    vm.prank(address(adapter2));
    vm.expectEmit();
    emit DelayedWithdrawalRegistered(positions[2], tokens[1], address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[2], tokenByPosition[positions[2]]);
  }

  function test_registerDelayedWithdraw_RevertWhen_AdapterDuplicated() public {
    address token = tokens[0];
    IDelayedWithdrawalAdapter adapter = strategy.delayedWithdrawalAdapter(token);
    vm.startPrank(address(adapter));

    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], token);

    vm.expectRevert(abi.encodeWithSelector(IDelayedWithdrawalManager.AdapterDuplicated.selector));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], token);

    vm.stopPrank();
  }

  function test_registerDelayedWithdraw_RevertWhen_AdapterMismatch() public {
    IDelayedWithdrawalAdapter adapter = strategy.delayedWithdrawalAdapter(tokens[0]);
    vm.prank(address(adapter));

    vm.expectRevert(abi.encodeWithSelector(IDelayedWithdrawalManager.AdapterMismatch.selector));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[2], tokenByPosition[positions[2]]);
  }

  function test_positionFunds() public {
    IDelayedWithdrawalAdapter adapter1 = strategy.delayedWithdrawalAdapter(tokens[0]);
    vm.startPrank(address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], tokenByPosition[positions[0]]);
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);
    vm.stopPrank();

    IDelayedWithdrawalAdapter adapter2 = strategy.delayedWithdrawalAdapter(tokens[1]);
    vm.prank(address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[2], tokenByPosition[positions[2]]);

    for (uint8 i; i < 3; i++) {
      assertEq(
        adapter1.estimatedPendingFunds(positions[i], tokenByPosition[positions[i]]),
        delayedWithdrawalManager.estimatedPendingFunds(positions[i], tokenByPosition[positions[i]])
      );

      assertEq(
        adapter1.withdrawableFunds(positions[i], tokenByPosition[positions[i]]),
        delayedWithdrawalManager.withdrawableFunds(positions[i], tokenByPosition[positions[i]])
      );

      (address[] memory positionTokens, uint256[] memory estimatedPending, uint256[] memory withdrawable) =
        delayedWithdrawalManager.allPositionFunds(positions[i]);
      (address[] memory vaultTokens,,) = delayedWithdrawalManager.vault().position(positions[i]);

      assertEq(positionTokens, vaultTokens);
      for (uint256 j; j < positionTokens.length; j++) {
        assertEq(estimatedPending[j], delayedWithdrawalManager.estimatedPendingFunds(positions[i], positionTokens[j]));

        assertEq(withdrawable[j], delayedWithdrawalManager.withdrawableFunds(positions[i], positionTokens[j]));
      }
    }
  }

  function test_positionFunds_MultipleAdaptersForPositionAndToken() public {
    uint256 positionId = positions[0];
    address token = tokenByPosition[positions[0]];
    IDelayedWithdrawalAdapter adapter1 = strategy.delayedWithdrawalAdapter(token);
    vm.startPrank(address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positionId, token);
    vm.stopPrank();

    // Update strategy to register a new adapter
    IEarnStrategyRegistry strategyRegistry = delayedWithdrawalManager.vault().STRATEGY_REGISTRY();
    IEarnStrategy newStrategy = StrategyUtils.deployStateStrategy(tokens);
    strategyRegistry.proposeStrategyUpdate(strategyId, newStrategy);
    vm.warp(block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY()); //Waiting for the delay...
    strategyRegistry.updateStrategy(strategyId);

    // Register new strategy adapter
    IDelayedWithdrawalAdapter adapter2 = newStrategy.delayedWithdrawalAdapter(token);
    vm.prank(address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positionId, token);

    /**
     * For that position and token:
     * estimatedPendingFunds(manager) =
     * estimatedPendingFunds(old strategy adapter) +
     * estimatedPendingFunds(new strategy adapter)
     *
     * withdrawableFunds(manager) =
     * withdrawableFunds(old strategy adapter) +
     * withdrawableFunds(new strategy adapter)
     */

    assertEq(
      adapter1.estimatedPendingFunds(positionId, token) + adapter2.estimatedPendingFunds(positionId, token),
      delayedWithdrawalManager.estimatedPendingFunds(positionId, token)
    );

    assertEq(
      adapter1.withdrawableFunds(positionId, token) + adapter2.withdrawableFunds(positionId, token),
      delayedWithdrawalManager.withdrawableFunds(positionId, token)
    );

    (address[] memory positionTokens, uint256[] memory estimatedPending, uint256[] memory withdrawable) =
      delayedWithdrawalManager.allPositionFunds(positionId);
    (address[] memory vaultTokens,,) = delayedWithdrawalManager.vault().position(positionId);

    assertEq(positionTokens, vaultTokens);
    for (uint256 i; i < positionTokens.length; i++) {
      assertEq(estimatedPending[i], delayedWithdrawalManager.estimatedPendingFunds(positionId, positionTokens[i]));

      assertEq(withdrawable[i], delayedWithdrawalManager.withdrawableFunds(positionId, positionTokens[i]));
    }
  }

  function test_withdraw() public {
    address recipient = address(10);
    for (uint8 i; i < 3; i++) {
      IDelayedWithdrawalAdapter adapter = strategy.delayedWithdrawalAdapter(tokenByPosition[positions[i]]);
      vm.prank(address(adapter));
      delayedWithdrawalManager.registerDelayedWithdraw(positions[i], tokenByPosition[positions[i]]);

      vm.startPrank(owner);
      //Before withdraw
      uint256 expectedWithdraw = delayedWithdrawalManager.withdrawableFunds(positions[i], tokenByPosition[positions[i]]);
      vm.expectEmit();
      emit WithdrawnFunds(positions[i], tokenByPosition[positions[i]], recipient, expectedWithdraw);
      (uint256 withdrawn,) = delayedWithdrawalManager.withdraw(positions[i], tokenByPosition[positions[i]], recipient);
      assertEq(expectedWithdraw, withdrawn);

      //After withdraw
      assertEq(delayedWithdrawalManager.withdrawableFunds(positions[i], tokenByPosition[positions[i]]), 0);
      (withdrawn,) = delayedWithdrawalManager.withdraw(positions[i], tokenByPosition[positions[i]], recipient);
      assertEq(withdrawn, 0);
      vm.stopPrank();
    }
  }

  function test_withdraw_MultipleAdaptersForPositionAndToken() public {
    uint256 positionId = positions[1];
    address recipient = address(10);
    address token = tokenByPosition[positions[1]];
    IDelayedWithdrawalAdapter adapter1 = strategy.delayedWithdrawalAdapter(token);
    vm.startPrank(address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positionId, token);
    vm.stopPrank();

    // Update strategy to register a new adapter
    IEarnStrategyRegistry strategyRegistry = delayedWithdrawalManager.vault().STRATEGY_REGISTRY();
    IEarnStrategy newStrategy = StrategyUtils.deployStateStrategy(tokens);
    strategyRegistry.proposeStrategyUpdate(strategyId, newStrategy);
    vm.warp(block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY()); //Waiting for the delay...
    strategyRegistry.updateStrategy(strategyId);

    // Register new strategy adapter
    IDelayedWithdrawalAdapter adapter2 = newStrategy.delayedWithdrawalAdapter(token);
    vm.prank(address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positionId, token);

    //Before withdraw
    uint256 expectedWithdraw = delayedWithdrawalManager.withdrawableFunds(positionId, token);
    vm.expectEmit();
    emit WithdrawnFunds(positionId, token, recipient, expectedWithdraw);
    vm.prank(owner);
    (uint256 withdrawn, uint256 stillPending) = delayedWithdrawalManager.withdraw(positionId, token, recipient);
    assertEq(expectedWithdraw, withdrawn);

    //After withdraw
    assertEq(
      adapter1.estimatedPendingFunds(positionId, token) + adapter2.estimatedPendingFunds(positionId, token),
      stillPending
    );

    assertEq(delayedWithdrawalManager.withdrawableFunds(positionId, token), 0);

    if (adapter2.estimatedPendingFunds(positionId, token) != 0) {
      vm.expectCall(
        address(adapter2),
        abi.encodeWithSelector(IDelayedWithdrawalAdapter.withdraw.selector, positionId, token, recipient)
      );
    }

    vm.prank(owner);
    (withdrawn, stillPending) = delayedWithdrawalManager.withdraw(positionId, token, recipient);
    assertEq(withdrawn, 0);
  }

  function test_withdraw_RevertWhen_UnauthorizedWithdrawal() public {
    address recipient = address(10);
    IDelayedWithdrawalAdapter adapter = strategy.delayedWithdrawalAdapter(tokenByPosition[positions[1]]);
    vm.prank(address(adapter));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);

    vm.expectRevert(abi.encodeWithSelector(IDelayedWithdrawalManager.UnauthorizedWithdrawal.selector));
    delayedWithdrawalManager.withdraw(positions[1], tokenByPosition[positions[1]], recipient);
  }
}
