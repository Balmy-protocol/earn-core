// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { StrategyId } from "../../types/StrategyId.sol";

/**
 * @notice Stores a position's strategy id and amount of shares
 * @dev Occupies 1 slot
 */
struct PositionData {
  // The strategy's id
  StrategyId strategyId;
  // The amount of shares
  uint160 shares;
}

/**
 * @notice Stores yield data for a specific token, for all positions in a given strategy
 * @dev Occupies 1 slot. To understand why we chose these variable sizes, please refer
 *      to the [README](../README.md).
 */
struct TotalYieldDataForToken {
  // The yield accumulator for this specific strategy and token
  int152 yieldAccumulator;
  // The last recorded total balance reported by the strategy. This value is used to understand how
  // much yield was generated when we ask for the total balance in the future
  uint104 lastRecordedBalance;
}

/**
 * @notice Stores yield data for a specific token, for a given position
 * @dev Occupies 1 slot
 */
struct PositionYieldDataForToken {
  // The yield accumulator for the strategy and token, when the position was last modified
  int152 baseAccumulator;
  // The amount of balance already accounted for, that hasn't been withdrawn
  int104 preAccountedBalance;
}
