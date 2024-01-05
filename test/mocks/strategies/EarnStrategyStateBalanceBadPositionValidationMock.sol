// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { EarnStrategyStateBalanceMock } from "./EarnStrategyStateBalanceMock.sol";

/// @notice An implementation of IEarnStrategy, that doesn't accept new positions
contract EarnStrategyStateBalanceBadPositionValidationMock is EarnStrategyStateBalanceMock {
  error InvalidPositionCreation();

  constructor(
    address[] memory tokens_,
    WithdrawalType[] memory withdrawalTypes_
  )
    EarnStrategyStateBalanceMock(tokens_, withdrawalTypes_)
  { }

  function validatePositionCreation(address, bytes calldata) external pure override {
    revert InvalidPositionCreation();
  }
}
