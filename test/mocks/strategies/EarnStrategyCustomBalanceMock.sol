// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { EarnStrategyDead } from "./EarnStrategyDead.sol";

/// @notice An implementation of IEarnStrategy that returns balances set specifically
contract EarnStrategyCustomBalanceMock is EarnStrategyDead {
  using EnumerableSet for EnumerableSet.AddressSet;

  mapping(address token => uint104 balance) public tokenBalance;
  EnumerableSet.AddressSet private _tokens;

  constructor(address asset_) {
    _tokens.add(asset_);
  }

  function asset() external view override returns (address) {
    return _tokens.at(0);
  }

  function allTokens() external view override returns (address[] memory tokens, WithdrawalType[] memory types) {
    tokens = _tokens.values();
    types = supportedWithdrawals();
  }

  function supportedWithdrawals() public view override returns (WithdrawalType[] memory types) {
    types = new WithdrawalType[](_tokens.length());
  }

  function totalBalances() external view override returns (address[] memory tokens, uint256[] memory balances) {
    tokens = _tokens.values();
    balances = new uint256[](tokens.length);
    for (uint256 i; i < balances.length; i++) {
      balances[i] = tokenBalance[tokens[i]];
    }
  }

  function deposited(address, uint256 depositAmount) public payable override returns (uint256 assetsDeposited) {
    return depositAmount;
  }

  function withdraw(
    uint256,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address
  )
    external
    override
    returns (WithdrawalType[] memory)
  {
    for (uint256 i; i < tokens.length; i++) {
      tokenBalance[tokens[i]] -= uint104(toWithdraw[i]);
    }
  }

  function addToken(address token, uint104 balance) external returns (uint256) {
    require(_tokens.add(token), "Token already added");
    setBalance(token, balance);
    return _tokens.length();
  }

  function setBalance(address token, uint104 balance) public returns (uint104 previousBalance) {
    previousBalance = tokenBalance[token];
    tokenBalance[token] = balance;
  }
}
