// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { StrategyId } from "../../../src/vault/EarnVault.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { Token } from "../../../src/libraries/Token.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";

contract GasEarnVaultOneTokenZeroPositions is BaseEarnVaultGasTest {
  using StrategyUtils for EarnStrategyRegistryMock;

  // solhint-disable const-name-snakecase
  StrategyId public strategyIdNative;
  uint256 public constant amountToDeposit = 6_000_000;

  function setUp() public virtual override {
    super.setUp();

    (strategyIdNative,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    (strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));
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
}
