// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

/// @notice Calculated data in the context of a position and token
struct CalculatedDataForToken {
  // VALUES READ FROM STORAGE
  // The total amount of complete loss events that have happened in the past on this strategy and token
  uint256 strategyCompleteLossEvents;
  // The total amount of loss that have happened in the past on this strategy and token
  uint256 newStrategyLossAccum;
  // CALCULATED VALUES
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
  function extractBalances(CalculatedDataForToken[] memory calculatedData)
    internal
    pure
    returns (uint256[] memory balances)
  {
    balances = new uint256[](calculatedData.length);
    for (uint256 i = 0; i < calculatedData.length; ++i) {
      balances[i] = calculatedData[i].positionBalance;
    }
  }
}
