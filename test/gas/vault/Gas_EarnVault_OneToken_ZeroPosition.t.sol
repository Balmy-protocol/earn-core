// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { StrategyId } from "../../../src/vault/EarnVault.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { Token } from "../../../src/libraries/Token.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";

contract GasEarnVaultOneTokenZeroPosition is BaseEarnVaultGasTest {
  using StrategyUtils for EarnStrategyRegistryMock;

  StrategyId public strategyIdNative;
  uint256 public amountToDeposit;

  function setUp() public virtual override {
    super.setUp();

    amountToDeposit = 6_000_000;
    permissions = PermissionUtils.buildPermissionSet(
      operator, PermissionUtils.permissions(vault.INCREASE_PERMISSION(), vault.WITHDRAW_PERMISSION())
    );

    vm.deal(address(this), type(uint256).max);
    (strategyIdNative,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    erc20.mint(address(this), type(uint256).max);
    (strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));
  }

  function test_Gas_createPosition_WithNative() public {
    vault.createPosition{ value: amountToDeposit }(
      strategyIdNative, Token.NATIVE_TOKEN, amountToDeposit, positionOwner, permissions, ""
    );
  }

  function test_Gas_createPosition_WithERC20() public {
    vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, "");
  }
}
