// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StrategyId } from "../../types/StrategyId.sol";
import { YieldMath } from "../libraries/YieldMath.sol";

/**
 * @notice Stores yield loss data for a specific token, for all positions in a specific strategy
 * @dev Occupies 1 slot. Holds:
 *      - Loss accumulator: the yield loss accumulator for this specific strategy and token. Will use 248 bits
 *      - Complete loss events: total number of reported complete loss events. Will use 8 bits.
 */
struct StrategyYieldLossDataForToken {
  uint248 strategyLossAccum;
  uint8 strategyCompleteLossEvents;
}

/// @notice A key composed of a strategy id and a token address
type StrategyYieldLossDataKey is bytes32;

library StrategyYieldLossDataForTokenLibrary {
  using SafeCast for uint256;

  /**
   * @notice Reads a strategy's yield loss data from storage
   */
  function read(
    mapping(StrategyYieldLossDataKey => StrategyYieldLossDataForToken) storage strategyYieldLossData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (uint256 strategyLossAccum, uint256 strategyCompleteLossEvents)
  {
    StrategyYieldLossDataForToken memory strategyYieldLossDataForToken =
      strategyYieldLossData[_keyFrom(strategyId, token)];
    if (strategyYieldLossDataForToken.strategyLossAccum == 0) {
      return (YieldMath.LOSS_ACCUM_INITIAL, strategyYieldLossDataForToken.strategyCompleteLossEvents);
    }
    return (strategyYieldLossDataForToken.strategyLossAccum, strategyYieldLossDataForToken.strategyCompleteLossEvents);
  }

  /**
   * @notice Updates a strategy's yield loss data based on the given values
   */
  function update(
    mapping(StrategyYieldLossDataKey => StrategyYieldLossDataForToken) storage strategyYieldLossData,
    StrategyId strategyId,
    address token,
    uint256 newStrategyLossAccum,
    uint256 newStrategyCompleteLossEvents
  )
    internal
  {
    strategyYieldLossData[_keyFrom(strategyId, token)] =
      StrategyYieldLossDataForToken(newStrategyLossAccum.toUint248(), newStrategyCompleteLossEvents.toUint8());
  }

  function _keyFrom(StrategyId strategyId, address token) internal pure returns (StrategyYieldLossDataKey) {
    return StrategyYieldLossDataKey.wrap(keccak256(abi.encode(strategyId, token)));
  }
}
