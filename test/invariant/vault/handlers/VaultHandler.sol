// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IEarnVault, StrategyId } from "../../../../src/vault/EarnVault.sol";
import { EarnStrategyCustomBalanceMock } from "../../../mocks/strategies/EarnStrategyCustomBalanceMock.sol";

contract VaultHandler is StdUtils {
  using SafeCast for uint256;

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

  // TODO: Why uint80?
  function deposit(uint256 depositTokenIndex, uint80 depositAmount) external payable {
    uint104 previousBalance = _strategy.tokenBalance(_asset);
    depositAmount = uint80(bound(depositAmount, 1, type(uint80).max));
    address depositToken = _findTokenWithIndex(depositTokenIndex);
    (, uint256 assetsDeposited) = _vault.createPosition(
      _strategyId, depositToken, depositAmount, address(1), PermissionUtils.buildEmptyPermissionSet(), ""
    );
    _strategy.setBalance(_asset, previousBalance + assetsDeposited.toUint104());
  }

  // TODO: add increase
  // TODO: add withdraw
  // TODO: add special withdraw?

  function _findTokenWithIndex(uint256 tokenIndex) private view returns (address) {
    (address[] memory tokens,) = _strategy.allTokens();
    tokenIndex = bound(tokenIndex, 0, tokens.length - 1);
    return tokens[tokenIndex];
  }
}

