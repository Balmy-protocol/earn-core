// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { TotalYieldDataForToken, PositionYieldDataForToken } from "./Storage.sol";

/// @notice Calculated data in the context of a position and token
struct CalculatedDataForToken {
  // EXTERNAL VALUES
  // Total token balance, as reported by the strategy
  uint256 totalBalance;
  // VALUES READ FROM STORAGE
  // Yield data for the position, in the context of a token
  PositionYieldDataForToken positionYieldData;
  // Yield data for the position's strategy, in the context of a token
  TotalYieldDataForToken totalYieldData;
  // CALCULATED VALUES
  // The position's total balance
  int256 positionBalance;
  // Total amount of fees earned in this strategy and token, taking into account the last yield
  uint256 earnedFees;
  // The new value for the yield accumulator
  int256 newAccumulator;
}

/// @notice Whether a specific action is to deposit or withdraw
enum UpdateAction {
  DEPOSIT,
  WITHDRAW
}
