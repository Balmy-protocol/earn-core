// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

/// @notice Calculated data in the context of a position and token
struct CalculatedDataForToken {
  // VALUES READ FROM STORAGE
  // The last recorded total balance reported by the strategy. This value is used to understand how
  // much yield was generated when we ask for the total balance in the future
  uint256 lastRecordedBalance;
  // The total amount of total loss events that have happened in the past on this strategy and token
  uint256 totalLossEvents;
  // The total amount of loss that have happened in the past on this strategy and token
  uint256 totalLossAccum;
  // CALCULATED VALUES
  // The position's total balance
  uint256 positionBalance;
  // The new value for the yield accumulator
  uint256 newAccumulator;
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
    for (uint256 i = 0; i < calculatedData.length;) {
      balances[i] = calculatedData[i].positionBalance;
      unchecked {
        ++i;
      }
    }
  }
}
