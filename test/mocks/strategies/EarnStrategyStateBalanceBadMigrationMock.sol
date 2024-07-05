// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { EarnStrategyStateBalanceMock, IEarnStrategy } from "./EarnStrategyStateBalanceMock.sol";

/// @notice An implementation of IEarnStrategy, without token migration
contract EarnStrategyStateBalanceBadMigrationMock is EarnStrategyStateBalanceMock {
  constructor(
    address[] memory tokens_,
    WithdrawalType[] memory withdrawalTypes_
  )
    EarnStrategyStateBalanceMock(tokens_, withdrawalTypes_)
  { }

  function migrateToNewStrategy(IEarnStrategy, bytes calldata) external pure override returns (bytes memory) {
    return "";
  }
}
