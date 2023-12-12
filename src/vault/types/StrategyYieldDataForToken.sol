// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { StrategyId } from "../../types/StrategyId.sol";
import { CustomUintSizeChecks } from "../libraries/CustomUintSizeChecks.sol";

/**
 * @notice Stores yield data for a specific token, for all positions in a specific strategy
 * @dev Occupies 1 slot. Holds:
 *      - Yield accumulator: the yield accumulator for this specific strategy and token. Will use 150 bits
 *      - Last recorded balance: the last recorded total balance reported by the strategy. This value is used to
 *        understand how much yield was generated when we ask for the total balance in the future. Will use
 *        102 bits
 *      - Complete loss events: total number of reported complete loss events. Will use 4 bits.
 *      To understand why we chose these variable sizes, please refer to the [README](../README.md).
 */
type StrategyYieldDataForToken is uint256;

/// @notice A key composed of a strategy id and a token address
type StrategyYieldDataKey is bytes32;

library StrategyYieldDataForTokenLibrary {
  using CustomUintSizeChecks for uint256;

  /**
   * @notice Reads total yield data from storage
   */
  function read(
    mapping(StrategyYieldDataKey => StrategyYieldDataForToken) storage totalYieldData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, uint256 strategyCompleteLossEvents)
  {
    return _decode(totalYieldData[_keyFrom(strategyId, token)]);
  }

  /**
   * @notice Updates total yield data based on the given values
   */
  function update(
    mapping(StrategyYieldDataKey => StrategyYieldDataForToken) storage totalYieldData,
    StrategyId strategyId,
    address token,
    uint256 newTotalBalance,
    uint256 newStrategyYieldAccum,
    uint256 newStrategyCompleteLossEvents
  )
    internal
  {
    // TODO: make some gas tests to understand gas savings if we remember the previous value and compare it before
    // writing
    totalYieldData[_keyFrom(strategyId, token)] = _encode({
      yieldAccumulator: newStrategyYieldAccum,
      recordedBalance: newTotalBalance,
      strategyCompleteLossEvents: newStrategyCompleteLossEvents
    });
  }

  function _decode(StrategyYieldDataForToken encoded)
    private
    pure
    returns (uint256 yieldAccumulator, uint256 recordedBalance, uint256 strategyCompleteLossEvents)
  {
    uint256 unwrapped = StrategyYieldDataForToken.unwrap(encoded);
    yieldAccumulator = unwrapped >> 106;
    recordedBalance = (unwrapped >> 4) & 0x3fffffffffffffffffffffffff;
    strategyCompleteLossEvents = unwrapped & 0xF;
  }

  function _encode(
    uint256 yieldAccumulator,
    uint256 recordedBalance,
    uint256 strategyCompleteLossEvents
  )
    private
    pure
    returns (StrategyYieldDataForToken)
  {
    yieldAccumulator.assertFitsInUint150();
    recordedBalance.assertFitsInUint102();
    strategyCompleteLossEvents.assertFitsInUint4();
    return
      StrategyYieldDataForToken.wrap((yieldAccumulator << 106) | (recordedBalance << 4) | strategyCompleteLossEvents);
  }

  function _keyFrom(StrategyId strategyId, address token) internal pure returns (StrategyYieldDataKey) {
    return StrategyYieldDataKey.wrap(keccak256(abi.encode(strategyId, token)));
  }
}
