// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Token, IERC20, Address } from "../../../src/libraries/Token.sol";

import { EarnStrategyStateBalanceMock, IEarnStrategy } from "./EarnStrategyStateBalanceMock.sol";

/// @notice An implementation of IEarnStrategy, without token migration
contract EarnStrategyStateBalanceBadTokens is EarnStrategyStateBalanceMock {
  using Token for address;

  constructor(
    address[] memory tokens_,
    WithdrawalType[] memory withdrawalTypes_
  )
    EarnStrategyStateBalanceMock(tokens_, withdrawalTypes_)
  { }

  function totalBalances() external view override returns (address[] memory tokens_, uint256[] memory balances) {
    tokens_ = new address[](tokens.length - 1);
    balances = new uint256[](tokens.length - 1);
    for (uint256 i = 1; i < balances.length; i++) {
      tokens_[i] = tokens[i];
      balances[i] = tokens_[i].balanceOf(address(this));
    }
  }
}
