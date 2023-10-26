// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable-next-line no-unused-import
import { EarnStrategyStateBalanceMock, IEarnStrategy } from "./EarnStrategyStateBalanceMock.sol";
// solhint-disable-next-line no-unused-import
import { Token } from "../../../src/libraries/Token.sol";

/// @notice An implementation of IEarnStrategy that returns balances by reading token's state
contract EarnStrategyRewardsBalanceMock is EarnStrategyStateBalanceMock {
  using Token for address;

  constructor(
    address[] memory tokens_,
    WithdrawalType[] memory withdrawalTypes_
  )
    EarnStrategyStateBalanceMock(tokens_, withdrawalTypes_)
  { }

  function totalBalances() external view override returns (address[] memory tokens_, uint256[] memory balances) {
    tokens_ = tokens;
    balances = new uint256[](tokens.length);
    for (uint256 i; i < balances.length; i++) {
      balances[i] = tokens_[0].balanceOf(address(this)) * (i + 1);
    }
  }
}
