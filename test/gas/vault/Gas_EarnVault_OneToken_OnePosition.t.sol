// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { Token } from "../../../src/libraries/Token.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { SpecialWithdrawalCode } from "../../../src/types/SpecialWithdrawals.sol";

contract GasEarnVaultOneTokenOnePosition is BaseEarnVaultGasTest {
  using StrategyUtils for EarnStrategyRegistryMock;

  uint256 public amountToDeposit = 6_000_000;
  uint256 public amountToWithdraw = 200_000;
  uint256 public positionId;

  address[] public tokens;
  uint256[] public intendedToWithdraw;
  uint256 public amountToIncrease = 100_000;

  function setUp() public virtual override {
    super.setUp();

    permissions = PermissionUtils.buildPermissionSet(
      address(this), PermissionUtils.permissions(vault.INCREASE_PERMISSION(), vault.WITHDRAW_PERMISSION())
    );

    vm.deal(address(this), type(uint256).max);
    erc20.mint(address(this), type(uint256).max);
    (strategyId, strategy) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));
    (positionId,) = vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, "");

    (tokens,,) = vault.position(positionId);
    intendedToWithdraw = CommonUtils.arrayOf(amountToWithdraw);
    erc20.approve(address(vault), type(uint256).max);
  }

  function test_Gas_position() public view {
    vault.position(positionId);
  }

  function test_Gas_withdraw() public {
    vault.withdraw(positionId, tokens, intendedToWithdraw, address(this));
  }

  function test_Gas_specialWithdraw() public {
    vault.specialWithdraw(positionId, SpecialWithdrawalCode.wrap(0), abi.encode(0, amountToWithdraw), address(this));
  }

  function test_Gas_increasePosition_WithNative() public {
    vault.increasePosition{ value: amountToIncrease }(positionId, address(Token.NATIVE_TOKEN), amountToIncrease);
  }

  function test_Gas_increasePosition_WithERC20() public {
    vault.increasePosition(positionId, address(erc20), amountToIncrease);
  }
}
