// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IEarnVault, StrategyId } from "../../../../src/vault/EarnVault.sol";
import { EarnStrategyCustomBalanceMock } from "../../../mocks/strategies/EarnStrategyCustomBalanceMock.sol";

contract VaultHandler is StdUtils {
  using SafeCast for uint256;
  using Math for uint256;

  EarnStrategyCustomBalanceMock private _strategy;
  StrategyId private _strategyId;
  IEarnVault private _vault;
  address private _asset;

  constructor(EarnStrategyCustomBalanceMock strategy, StrategyId strategyId, IEarnVault vault) {
    _strategy = strategy;
    _strategyId = strategyId;
    _vault = vault;
    _asset = _findTokenWithIndex(0);
  }

  function deposit(uint256 depositTokenIndex, uint256 depositAmount) external payable {
    uint104 previousBalance = _strategy.tokenBalance(_asset);
    uint256 maxBalanceInVault = (2 ** 102) - 1;
    uint256 availableToDeposit = maxBalanceInVault - uint256(previousBalance);
    depositAmount = bound(depositAmount, 1, availableToDeposit * 9 / 10); // We can only deposit up to 90% of what's
      // available

    address depositToken = _findTokenWithIndex(depositTokenIndex);

    _vault.createPosition(
      _strategyId, depositToken, depositAmount, address(this), PermissionUtils.buildEmptyPermissionSet(), ""
    );
  }

  function withdraw(uint256 positionIdIndex, uint256 tokenIndex, uint256 amountToWithdraw) external payable {
    if (_vault.totalSupply() != 0) {
      uint256 positionId = bound(positionIdIndex, 1, _vault.totalSupply());
      (address[] memory tokens,, uint256[] memory balances) = _vault.position(positionId);
      tokenIndex = bound(tokenIndex, 0, tokens.length - 1);

      uint256 previousBalance = balances[tokenIndex];
      if (previousBalance != 0) {
        uint256[] memory intendendWithdraw = new uint256[](balances.length);
        intendendWithdraw[tokenIndex] = bound(amountToWithdraw, 1, previousBalance);
        _vault.withdraw({
          positionId: positionId,
          tokensToWithdraw: tokens,
          intendedWithdraw: intendendWithdraw,
          recipient: address(1)
        });
      }
    }
  }
  // TODO: add increase
  // TODO: add special withdraw?

  function _findTokenWithIndex(uint256 tokenIndex) private view returns (address) {
    (address[] memory tokens,) = _strategy.allTokens();
    tokenIndex = bound(tokenIndex, 0, tokens.length - 1);
    return tokens[tokenIndex];
  }
}
