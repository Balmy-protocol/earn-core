// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
// solhint-disable-next-line no-unused-import
import { StrategyAndToken, PositionAndToken, KeyEncoding } from "../types/KeyEncoding.sol";
import { StrategyId } from "../../types/StrategyId.sol";
import { TotalYieldDataForToken, PositionYieldDataForToken } from "../types/Storage.sol";

library StorageHelper {
  using SafeCast for uint256;
  using SafeCast for int256;

  /**
   * @notice Reads total yield data from storage
   */
  function read(
    mapping(StrategyAndToken => TotalYieldDataForToken) storage totalYieldData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (TotalYieldDataForToken memory)
  {
    return totalYieldData[KeyEncoding.from(strategyId, token)];
  }

  /**
   * @notice Reads a position's yield data from storage
   */
  function read(
    mapping(PositionAndToken => PositionYieldDataForToken) storage positionYieldData,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (PositionYieldDataForToken memory)
  {
    return positionYieldData[KeyEncoding.from(positionId, token)];
  }

  /**
   * @notice Updates total yield data based on the given values
   */
  function update(
    mapping(StrategyAndToken => TotalYieldDataForToken) storage totalYieldData,
    StrategyId strategyId,
    address token,
    uint256 newTotalBalance,
    int256 newAccumulator,
    uint256 newEarnedFees,
    TotalYieldDataForToken memory previousValues
  )
    internal
  {
    // TODO: make some gas test to understand if there is a more optimized way to do this
    if (
      newTotalBalance != previousValues.lastRecordedBalance || newAccumulator != previousValues.yieldAccumulator
        || newEarnedFees != previousValues.earnedFees
    ) {
      totalYieldData[KeyEncoding.from(strategyId, token)] = TotalYieldDataForToken({
        lastRecordedBalance: newTotalBalance,
        yieldAccumulator: newAccumulator.toInt152(),
        earnedFees: newEarnedFees.toUint104()
      });
    }
  }

  /**
   * @notice Updates a position's yield data based on the given values
   */
  function update(
    mapping(PositionAndToken => PositionYieldDataForToken) storage positionYieldData,
    uint256 positionId,
    address token,
    int256 newAccumulator,
    int256 newAccountedBalance,
    uint256 newShares,
    PositionYieldDataForToken memory previousValues
  )
    internal
  {
    if (newShares == 0 && newAccountedBalance == 0) {
      // This is a small optimization that allows us to clear the slot for gas savings
      delete positionYieldData[KeyEncoding.from(positionId, token)];
    } else if (
      newAccumulator != previousValues.baseAccumulator || newAccountedBalance != previousValues.preAccountedBalance
    ) {
      positionYieldData[KeyEncoding.from(positionId, token)] = PositionYieldDataForToken({
        baseAccumulator: newAccumulator.toInt152(),
        preAccountedBalance: newAccountedBalance.toInt104()
      });
    }
  }
}
