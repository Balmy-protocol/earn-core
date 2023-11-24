// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseEarnVaultGasTest } from "./BaseEarnVaultGasTest.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";

contract GasEarnVaultTwoTokensManyPositionsWithMaxLosses is BaseEarnVaultGasTest {
  using StrategyUtils for EarnStrategyRegistryMock;

  // solhint-disable const-name-snakecase
  uint256 public positionId;
  uint256 public constant amountToDeposit = 6_000_000;
  uint256 public constant amountToIncrease = 100_000;
  uint256 public constant amountToReward = 10_000_000;
  uint256 public constant amountToLose = 1000;

  function setUp() public virtual override {
    super.setUp();

    (strategyId, strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20), address(anotherErc20)));
    (positionId,) = vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );
    anotherErc20.mint(address(strategy), amountToReward);
    for (uint8 i; i < MAX_LOSSES; i++) {
      vault.increasePosition(positionId, address(erc20), amountToIncrease);
      anotherErc20.burn(address(strategy), amountToLose);
    }
  }

  function test_Gas_position() public view {
    vault.position(positionId);
  }

  function test_Gas_createPosition() public {
    vault.createPosition(
      strategyId, address(erc20), amountToDeposit, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );
  }

  function test_Gas_increasePosition() public {
    vault.increasePosition(positionId, address(erc20), amountToIncrease);
  }
}
