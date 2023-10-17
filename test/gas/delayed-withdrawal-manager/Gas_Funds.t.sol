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

contract Gas_Funds is PRBTest {
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
    EarnVault vault = new EarnVault(
      strategyRegistry,
      address(1),
      CommonUtils.arrayOf(address(2))
    );
    ERC20MintableBurnableMock erc20 = new ERC20MintableBurnableMock();
    erc20.approve(address(vault), type(uint256).max);

    uint104 amountToDeposit1 = 1_000_000;
    uint104 amountToDeposit2 = 1_000_001;
    uint104 amountToDeposit3 = 1_000_003;
    erc20.mint(address(this), amountToDeposit3);

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

    // setUp
    IDelayedWithdrawalAdapter adapter1 = strategy.delayedWithdrawalAdapter(tokens[0]);
    vm.startPrank(address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], tokenByPosition[positions[0]]);
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);
    vm.stopPrank();

    IDelayedWithdrawalAdapter adapter2 = strategy.delayedWithdrawalAdapter(tokens[1]);
    vm.prank(address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[2], tokenByPosition[positions[2]]);
  }

  function test_Gas_estimatedPendingFunds_0() public view {
    delayedWithdrawalManager.estimatedPendingFunds(positions[0], tokenByPosition[positions[0]]);
  }

  function test_Gas_withdrawableFunds_0() public view {
    delayedWithdrawalManager.withdrawableFunds(positions[0], tokenByPosition[positions[0]]);
  }

  function test_Gas_allPositionFunds_0() public view {
    delayedWithdrawalManager.allPositionFunds(positions[0]);
  }

  function test_Gas_estimatedPendingFunds_1() public view {
    delayedWithdrawalManager.estimatedPendingFunds(positions[1], tokenByPosition[positions[1]]);
  }

  function test_Gas_withdrawableFunds_1() public view {
    delayedWithdrawalManager.withdrawableFunds(positions[1], tokenByPosition[positions[1]]);
  }

  function test_Gas_allPositionFunds_1() public view {
    delayedWithdrawalManager.allPositionFunds(positions[1]);
  }

  function test_Gas_estimatedPendingFunds_2() public view {
    delayedWithdrawalManager.estimatedPendingFunds(positions[2], tokenByPosition[positions[2]]);
  }

  function test_Gas_withdrawableFunds_2() public view {
    delayedWithdrawalManager.withdrawableFunds(positions[2], tokenByPosition[positions[2]]);
  }

  function test_Gas_allPositionFunds_2() public view {
    delayedWithdrawalManager.allPositionFunds(positions[2]);
  }
}
