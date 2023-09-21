// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { CalculatedDataForToken } from "../types/Memory.sol";

library DataCalculations {
  /**
   * @notice Calculates a position's balance, based on the calculated data
   * @dev Positions might have negative balance under certain particular situations. But it doesn't make much sense to
   *      expose this to the user. So we'll simply set them to 0.
   * @param calculatedData The data calculated for this position
   * @return balances A position's balance
   */
  function calculateBalances(CalculatedDataForToken[] memory calculatedData)
    internal
    pure
    returns (uint256[] memory balances)
  {
    balances = new uint256[](calculatedData.length);
    for (uint256 i = 0; i < calculatedData.length;) {
      int256 balance = calculatedData[i].positionBalance;
      balances[i] = balance > 0 ? uint256(balance) : 0;
      unchecked {
        ++i;
      }
    }
  }
}
