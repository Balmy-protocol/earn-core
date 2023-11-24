// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";

contract GasEarnVaultTwoTokensTwoPositionsWithLoss is BaseEarnVaultGasTest {
  using StrategyUtils for EarnStrategyRegistryMock;

  uint256 public positionId;

  address[] public tokens;
  uint256[] public intendedToWithdrawRewards;
  uint256 public amountToDeposit = 6_000_000;
  uint256 public amountToIncrease = 100_000;

  function setUp() public virtual override {
    super.setUp();

    uint256 amountToReward = 1_000_000;
    uint256 amountToLose = 1000;
    uint256 amountToWithdraw = 200_000;
    permissions = PermissionUtils.buildPermissionSet(
      address(this), PermissionUtils.permissions(vault.INCREASE_PERMISSION(), vault.WITHDRAW_PERMISSION())
    );

    erc20.mint(address(this), type(uint256).max);
    (strategyId, strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20), address(anotherErc20)));
    (positionId,) = vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, "");
    anotherErc20.mint(address(strategy), amountToReward);

    vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, "");
    anotherErc20.burn(address(strategy), amountToLose);

    (tokens,,) = vault.position(positionId);
    intendedToWithdrawRewards = CommonUtils.arrayOf(0, amountToWithdraw);
  }

  function test_Gas_position_withLosses() public view {
    vault.position(positionId);
  }
}
