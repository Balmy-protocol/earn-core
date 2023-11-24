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
  address[] public tokens;
  uint256[] public intendedToWithdrawRewards;
  uint256 public constant amountToIncrease = 100_000;
  uint256 public constant amountToDeposit = 6_000_000;
  uint256 public constant amountToReward = 1_000_000;
  uint256 public constant amountToWithdraw = 200_000;

  function setUp() public virtual override {
    super.setUp();

    tokens = CommonUtils.arrayOf(address(erc20), address(anotherErc20), address(thirdErc20));
    (strategyId, strategy) = vault.STRATEGY_REGISTRY().deployStateStrategy(tokens);
    (positionId,) = vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );
    thirdErc20.mint(address(strategy), amountToReward);

    intendedToWithdrawRewards = CommonUtils.arrayOf(0, 0, amountToWithdraw);
  }

  function test_Gas_position() public view {
    vault.position(positionId);
  }

  function test_Gas_withdraw_RewardToken() public {
    vault.withdraw(positionId, tokens, intendedToWithdrawRewards, address(this));
  }

  function test_Gas_increasePosition() public {
    vault.increasePosition(positionId, address(erc20), amountToIncrease);
  }
}
