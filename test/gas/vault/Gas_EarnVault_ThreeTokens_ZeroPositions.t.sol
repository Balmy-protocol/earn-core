// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
// solhint-disable-next-line no-unused-import
import { IEarnStrategyRegistry } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { PermissionUtils } from "@balmy/nft-permissions-test/PermissionUtils.sol";

contract GasEarnVaultThreeTokensZeroPositions is BaseEarnVaultGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  // solhint-disable const-name-snakecase
  uint256 public constant amountToDeposit = 6_000_000;

  function setUp() public virtual override {
    super.setUp();

    (strategyId,) = vault.STRATEGY_REGISTRY().deployStateStrategy(
      CommonUtils.arrayOf(address(erc20), address(anotherErc20), address(thirdErc20))
    );
  }

  function test_Gas_createPosition() public {
    vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), "", ""
    );
  }
}
