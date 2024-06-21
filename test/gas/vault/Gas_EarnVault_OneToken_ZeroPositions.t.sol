// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { StrategyId } from "../../../src/vault/EarnVault.sol";
// solhint-disable-next-line no-unused-import
import { IEarnStrategyRegistry } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { Token } from "../../../src/libraries/Token.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { PermissionUtils } from "@balmy/nft-permissions-test/PermissionUtils.sol";

contract GasEarnVaultOneTokenZeroPositions is BaseEarnVaultGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  // solhint-disable const-name-snakecase
  StrategyId public strategyIdNative;
  uint256 public constant amountToDeposit = 6_000_000;

  function setUp() public virtual override {
    super.setUp();

    (strategyIdNative,) = vault.STRATEGY_REGISTRY().deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    (strategyId,) = vault.STRATEGY_REGISTRY().deployStateStrategy(CommonUtils.arrayOf(address(erc20)));
  }

  function test_Gas_createPosition_WithNative() public {
    vault.createPosition{ value: amountToDeposit }(
      strategyIdNative,
      Token.NATIVE_TOKEN,
      amountToDeposit,
      address(this),
      PermissionUtils.buildEmptyPermissionSet(),
      "",
      ""
    );
  }

  function test_Gas_createPosition_WithERC20() public {
    vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), "", ""
    );
  }
}
