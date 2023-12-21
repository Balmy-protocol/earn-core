// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IEarnVault } from "../../../../src/interfaces/IEarnVault.sol";
import { EarnStrategyCustomBalanceMock } from "../../../mocks/strategies/EarnStrategyCustomBalanceMock.sol";
import { TokenManager } from "../helpers/TokenManager.sol";

contract StrategyHandler is StdUtils {
  // Let's remember that from our docs, we are assuming that the balance diff per update will be less than this value
  uint256 private constant MAX_BALANCE_DIFF = 4.52e13;

  EarnStrategyCustomBalanceMock private _strategy;
  IEarnVault private _vault;
  TokenManager private _tokenManager;

  constructor(EarnStrategyCustomBalanceMock strategy, IEarnVault vault, TokenManager tokenManager) {
    _strategy = strategy;
    _vault = vault;
    _tokenManager = tokenManager;
  }

  function addToken() public returns (address newToken) {
    (address[] memory tokens,) = _strategy.allTokens();
    newToken = _tokenManager.getTokenNotInList(tokens);
    _strategy.addToken(newToken, 0);
  }

  function increaseBalance(uint256 tokenIndex, uint48 toIncrease) external {
    address token = _findTokenWithIndex(tokenIndex);
    uint104 previousBalance = _strategy.tokenBalance(token);
    toIncrease = uint48(bound(toIncrease, 0, Math.min(type(uint104).max - previousBalance, MAX_BALANCE_DIFF)));
    _updateBalance(token, previousBalance + toIncrease);
  }

  function reduceBalance(uint256 tokenIndex, uint48 toReduce) external {
    address token = _findTokenWithIndex(tokenIndex);
    uint104 previousBalance = _strategy.tokenBalance(token);
    toReduce = uint48(bound(toReduce, 0, Math.min(previousBalance, MAX_BALANCE_DIFF)));
    _updateBalance(token, previousBalance - toReduce);
  }

  function _findTokenWithIndex(uint256 tokenIndex) private view returns (address) {
    (address[] memory tokens,) = _strategy.allTokens();
    tokenIndex = bound(tokenIndex, 0, tokens.length - 1);
    return tokens[tokenIndex];
  }

  function _updateBalance(address token, uint104 balance) internal {
    if (_vault.totalSupply() == 0) {
      // We need to have some positions before updating balance
      return;
    }
    _strategy.setBalance(token, balance);
  }
}
