// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";

contract GasEarnVaultTwoTokensZeroPositions is BaseEarnVaultGasTest {
  using StrategyUtils for EarnStrategyRegistryMock;

  // solhint-disable const-name-snakecase
  uint256 public constant amountToDeposit = 6_000_000;

  function setUp() public virtual override {
    super.setUp();

    (strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20), address(anotherErc20)));
  }

  function test_Gas_createPosition() public {
    vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );
  }
}
