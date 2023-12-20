// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { IEarnStrategyRegistry } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { Token } from "../../../src/libraries/Token.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { SpecialWithdrawalCode } from "../../../src/types/SpecialWithdrawals.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { StrategyId } from "../../../src/vault/EarnVault.sol";

contract GasEarnVaultOneTokenOnePosition is BaseEarnVaultGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  // solhint-disable const-name-snakecase
  StrategyId public strategyIdNative;
  uint256 public constant amountToDeposit = 6_000_000;
  uint256 public constant amountToWithdraw = 200_000;
  uint256 public constant amountToIncrease = 100_000;

  uint256 public positionId;

  address[] public tokens;
  uint256[] public intendedToWithdraw;

  function setUp() public virtual override {
    super.setUp();
    (strategyIdNative,) = vault.STRATEGY_REGISTRY().deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    (strategyId,) = vault.STRATEGY_REGISTRY().deployStateStrategy(CommonUtils.arrayOf(address(erc20)));
    (positionId,) = vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );

    (tokens,,) = vault.position(positionId);
    intendedToWithdraw = CommonUtils.arrayOf(amountToWithdraw);
  }

  function test_Gas_createPosition_WithNative() public {
    vault.createPosition{ value: amountToDeposit }(
      strategyIdNative,
      Token.NATIVE_TOKEN,
      amountToDeposit,
      address(this),
      PermissionUtils.buildEmptyPermissionSet(),
      ""
    );
  }

  function test_Gas_createPosition_WithERC20() public {
    vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );
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
