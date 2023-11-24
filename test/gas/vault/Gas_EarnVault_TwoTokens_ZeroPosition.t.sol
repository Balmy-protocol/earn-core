// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";

contract GasEarnVaultTwoTokensZeroPosition is BaseEarnVaultGasTest {
  using StrategyUtils for EarnStrategyRegistryMock;

  uint256 public amountToDeposit;

  function setUp() public virtual override {
    super.setUp();

    amountToDeposit = 6_000_000;
    permissions = PermissionUtils.buildPermissionSet(
      operator, PermissionUtils.permissions(vault.INCREASE_PERMISSION(), vault.WITHDRAW_PERMISSION())
    );

    erc20.mint(address(this), type(uint256).max);
    (strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20), address(anotherErc20)));
  }

  function test_Gas_createPosition() public {
    vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, "");
  }
}
