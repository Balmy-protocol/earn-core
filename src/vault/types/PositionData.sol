// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
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

library PositionDataLibrary {
  using SafeCast for uint256;

  /**
   * @notice Reads a position's data from storage
   */
  function read(
    mapping(uint256 => PositionData) storage positionData,
    uint256 positionId
  )
    internal
    view
    returns (StrategyId strategyId, uint160 positionShares)
  {
    PositionData memory data = positionData[positionId];
    strategyId = data.strategyId;
    positionShares = data.shares;
  }

  /**
   * @notice Updates a position's data based on the given values
   */
  function update(
    mapping(uint256 => PositionData) storage positionData,
    uint256 positionId,
    StrategyId strategyId,
    uint256 newPositionShares
  )
    internal
  {
    positionData[positionId] = PositionData({ shares: newPositionShares.toUint160(), strategyId: strategyId });
  }
}
