// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { EarnStrategyStateBalanceMock, IEarnStrategy } from "./EarnStrategyStateBalanceMock.sol";

/// @notice An implementation of IEarnStrategy, without token migration
contract EarnStrategyStateBalanceBadMigrationMock is EarnStrategyStateBalanceMock {
  constructor(
    address[] memory tokens_,
    WithdrawalType[] memory withdrawalTypes_
  )
    EarnStrategyStateBalanceMock(tokens_, withdrawalTypes_)
  { }

  function migrateToNewStrategy(IEarnStrategy) external override returns (bytes memory) {
    return new bytes(0);
  }
}
