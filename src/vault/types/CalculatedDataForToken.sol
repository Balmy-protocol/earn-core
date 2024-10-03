// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

/// @notice Calculated data in the context of a position and token
struct CalculatedDataForToken {
  // The total amount of complete loss events that have happened in the past on this strategy and token
  uint256 newStrategyCompleteLossEvents;
  // The total amount of loss that have happened in the past on this strategy and token
  uint256 newStrategyLossAccum;
  // The position's total balance
  uint256 positionBalance;
  // The new value for the yield accumulator
  uint256 newStrategyYieldAccum;
}

library CalculatedDataLibrary {
  /**
   * @notice Extracts a position's balance, from all calculated data
   * @param calculatedData The data calculated for this position
   * @return balances A position's balance
   */
  function extractBalances(
    CalculatedDataForToken[] memory calculatedData,
    uint256 positionAssetBalance
  )
    internal
    pure
    returns (uint256[] memory balances)
  {
    balances = new uint256[](calculatedData.length + 1);
    balances[0] = positionAssetBalance;
    for (uint256 i = 0; i < calculatedData.length; ++i) {
      balances[i + 1] = calculatedData[i].positionBalance;
    }
  }
}
