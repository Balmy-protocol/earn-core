// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { IEarnStrategyRegistry } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { SpecialWithdrawalCode } from "../../../src/types/SpecialWithdrawals.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";

contract GasEarnVaultTwoTokensOnePosition is BaseEarnVaultGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  // solhint-disable const-name-snakecase
  uint256 public positionId;
  address[] public tokens;
  uint256[] public intendedToWithdraw;
  uint256[] public intendedToWithdrawRewards;
  uint256 public constant amountToIncrease = 100_000;
  uint256 public constant amountToWithdraw = 200_000;
  uint256 public constant amountToDeposit = 6_000_000;
  uint256 public constant amountToReward = 1_000_000;

  function setUp() public virtual override {
    super.setUp();

    (strategyId, strategy) =
      vault.STRATEGY_REGISTRY().deployStateStrategy(CommonUtils.arrayOf(address(erc20), address(anotherErc20)));
    (positionId,) = vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );
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
