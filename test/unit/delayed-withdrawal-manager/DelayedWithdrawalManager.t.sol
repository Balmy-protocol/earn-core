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
  event DelayedWithdrawRegistered(uint256 positionId, address token, address adapter);

  using StrategyUtils for EarnStrategyRegistry;

  DelayedWithdrawalManager private delayedWithdrawalManager;

  uint256[] private positions;
  mapping(uint256 position => address token) private tokenByPosition;
  IEarnStrategy private strategy;
  address[] private tokens = new address[](2);

  function setUp() public virtual {
    EarnStrategyRegistry strategyRegistry = new EarnStrategyRegistry();
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
    vm.deal(address(this), uint256(amountToDeposit1) + amountToDeposit2 + amountToDeposit3);

    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(erc20);

    uint256 position;
    StrategyId strategyId;
    (strategyId, strategy) = strategyRegistry.deployStateStrategy(tokens);

    (position,) = vault.createPosition{ value: amountToDeposit1 }(
      strategyId, tokens[0], amountToDeposit1, address(3), PermissionUtils.buildEmptyPermissionSet(), ""
    );
    positions.push(position);
    tokenByPosition[position] = tokens[0];

    (position,) = vault.createPosition{ value: amountToDeposit2 }(
      strategyId, tokens[0], amountToDeposit2, address(3), PermissionUtils.buildEmptyPermissionSet(), ""
    );
    positions.push(position);
    tokenByPosition[position] = tokens[0];

    (position,) = vault.createPosition{ value: amountToDeposit3 }(
      strategyId, tokens[1], amountToDeposit3, address(3), PermissionUtils.buildEmptyPermissionSet(), ""
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
    emit DelayedWithdrawRegistered(positions[0], token, address(adapter));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], token);
  }

  function test_registerDelayedWithdraw_MultiplePositions() public {
    IDelayedWithdrawalAdapter adapter1 = strategy.delayedWithdrawalAdapter(tokens[0]);
    vm.startPrank(address(adapter1));

    vm.expectEmit();
    emit DelayedWithdrawRegistered(positions[0], tokens[0], address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], tokens[0]);

    vm.expectEmit();
    emit DelayedWithdrawRegistered(positions[1], tokens[0], address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokens[0]);
    vm.stopPrank();

    IDelayedWithdrawalAdapter adapter2 = strategy.delayedWithdrawalAdapter(tokens[1]);
    vm.prank(address(adapter2));
    vm.expectEmit();
    emit DelayedWithdrawRegistered(positions[2], tokens[1], address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[2], tokens[1]);
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
    address token = tokens[1];
    IDelayedWithdrawalAdapter adapter = strategy.delayedWithdrawalAdapter(tokens[0]);
    vm.prank(address(adapter));

    vm.expectRevert(abi.encodeWithSelector(IDelayedWithdrawalManager.AdapterMismatch.selector));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[2], token);
  }
}
