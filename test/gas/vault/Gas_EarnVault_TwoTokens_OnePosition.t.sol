// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { SpecialWithdrawalCode } from "../../../src/types/SpecialWithdrawals.sol";

contract GasEarnVaultTwoTokensOnePosition is BaseEarnVaultGasTest {
  using StrategyUtils for EarnStrategyRegistryMock;

  uint256 public positionId;

  address[] public tokens;
  uint256[] public intendedToWithdraw;
  uint256[] public intendedToWithdrawRewards;
  uint256 public amountToIncrease = 100_000;
  uint256 public amountToWithdraw = 200_000;

  function setUp() public virtual override {
    super.setUp();

    uint256 amountToDeposit = 6_000_000;
    uint256 amountToReward = 1_000_000;

    permissions = PermissionUtils.buildPermissionSet(
      address(this), PermissionUtils.permissions(vault.INCREASE_PERMISSION(), vault.WITHDRAW_PERMISSION())
    );

    erc20.mint(address(this), type(uint256).max);
    (strategyId, strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20), address(anotherErc20)));
    (positionId,) = vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, "");
    anotherErc20.mint(address(strategy), amountToReward);

    (tokens,,) = vault.position(positionId);
    intendedToWithdraw = CommonUtils.arrayOf(amountToWithdraw, 0);
    intendedToWithdrawRewards = CommonUtils.arrayOf(0, amountToWithdraw);
  }

  function test_Gas_position() public view {
    vault.position(positionId);
  }

  function test_Gas_withdraw_ByAsset() public {
    vault.withdraw(positionId, tokens, intendedToWithdraw, address(this));
  }

  function test_Gas_withdraw_RewardToken() public {
    vault.withdraw(positionId, tokens, intendedToWithdrawRewards, address(this));
  }

  function test_Gas_specialWithdraw() public {
    vault.specialWithdraw(positionId, SpecialWithdrawalCode.wrap(0), abi.encode(0, amountToWithdraw), address(this));
  }

  function test_Gas_increasePosition() public {
    vault.increasePosition(positionId, address(erc20), amountToIncrease);
  }
}
