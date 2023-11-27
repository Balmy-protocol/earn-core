// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { IEarnStrategyRegistry } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";

contract GasEarnVaultThreeTokensOnePosition is BaseEarnVaultGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  // solhint-disable const-name-snakecase
  uint256 public positionId;
  uint256 public constant amountToIncrease = 100_000;
  uint256 public constant amountToDeposit = 6_000_000;
  uint256 public constant amountToReward = 1_000_000;

  function setUp() public virtual override {
    super.setUp();

    (strategyId, strategy) = vault.STRATEGY_REGISTRY().deployStateStrategy(
      CommonUtils.arrayOf(address(erc20), address(anotherErc20), address(thirdErc20))
    );
    (positionId,) = vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );
    anotherErc20.mint(address(strategy), amountToReward);
  }

  function test_Gas_position() public view {
    vault.position(positionId);
  }
}
