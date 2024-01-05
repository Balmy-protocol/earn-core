// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { EarnStrategyStateBalanceMock } from "./EarnStrategyStateBalanceMock.sol";

/// @notice An implementation of IEarnStrategy, without token migration
contract EarnStrategyStateBalanceBadSignatureMock is EarnStrategyStateBalanceMock {
  error InvalidTermsAndConditions();

  constructor(
    address[] memory tokens_,
    WithdrawalType[] memory withdrawalTypes_
  )
    EarnStrategyStateBalanceMock(tokens_, withdrawalTypes_)
  { }

  function validatePositionCreation(address, bytes calldata) external pure override {
    revert InvalidTermsAndConditions();
  }
}
