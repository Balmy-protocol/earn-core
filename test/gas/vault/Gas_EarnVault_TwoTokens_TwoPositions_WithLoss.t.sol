// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
// solhint-disable-next-line no-unused-import
import { IEarnStrategyRegistry } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { PermissionUtils } from "@balmy/nft-permissions-test/PermissionUtils.sol";

contract GasEarnVaultTwoTokensTwoPositionsWithLoss is BaseEarnVaultGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  // solhint-disable const-name-snakecase
  uint256 public positionId;
  uint256 public constant amountToDeposit = 6_000_000;
  uint256 public constant amountToIncrease = 100_000;
  uint256 public constant amountToReward = 1_000_000;
  uint256 public constant amountToLose = 1000;

  function setUp() public virtual override {
    super.setUp();

    (strategyId, strategy) =
      vault.STRATEGY_REGISTRY().deployStateStrategy(CommonUtils.arrayOf(address(erc20), address(anotherErc20)));
    (positionId,) = vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), "", ""
    );
    anotherErc20.mint(address(strategy), amountToReward);

    vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), "", ""
    );
    anotherErc20.burn(address(strategy), amountToLose);
  }

  function test_Gas_position_withLosses() public view {
    vault.position(positionId);
  }
}
