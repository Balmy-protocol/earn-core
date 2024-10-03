// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StrategyId } from "../../types/StrategyId.sol";
import { CustomUintSizeChecks } from "../libraries/CustomUintSizeChecks.sol";

/**
 * @notice Stores yield data for a specific token, for all positions in a specific strategy
 * @dev Occupies 1 slot. Holds:
 *      - Yield accumulator: the yield accumulator for this specific strategy and token. Will use 151 bits
 *      - Last recorded balance: the last recorded total balance reported by the strategy. This value is used to
 *        understand how much yield was generated when we ask for the total balance in the future. Will use
 *        104 bits
 *      - Strategy had loss: indicates if the strategy ever had a loss. Will use 1 bit
 *      To understand why we chose these variable sizes, please refer to the [README](../README.md).
 */
type StrategyYieldDataForToken is uint256;

/// @notice A key composed of a strategy id and a token address
type StrategyYieldDataKey is bytes32;

library StrategyYieldDataForTokenLibrary {
  using CustomUintSizeChecks for uint256;
  using SafeCast for uint256;

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
    returns (uint256 yieldAccumulator, uint256 lastRecordedTotalBalance, bool strategyHadLoss)
  {
    return _decode(readRaw(totalYieldData, strategyId, token));
  }

  function readRaw(
    mapping(StrategyYieldDataKey => StrategyYieldDataForToken) storage totalYieldData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (StrategyYieldDataForToken raw)
  {
    return totalYieldData[_keyFrom(strategyId, token)];
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
    bool newStrategyHadLoss
  )
    internal
  {
    totalYieldData[_keyFrom(strategyId, token)] = _encode({
      yieldAccumulator: newStrategyYieldAccum,
      recordedBalance: newTotalBalance,
      strategyHadLoss: newStrategyHadLoss ? 1 : 0
    });
  }

  function _decode(StrategyYieldDataForToken encoded)
    private
    pure
    returns (uint256 yieldAccumulator, uint256 recordedBalance, bool strategyHadLoss)
  {
    uint256 unwrapped = StrategyYieldDataForToken.unwrap(encoded);
    yieldAccumulator = unwrapped >> 105;
    recordedBalance = (unwrapped >> 1) & 0xffffffffffffffffffffffffff;
    strategyHadLoss = unwrapped & 0x1 == 1;
  }

  function _encode(
    uint256 yieldAccumulator,
    uint256 recordedBalance,
    uint256 strategyHadLoss
  )
    private
    pure
    returns (StrategyYieldDataForToken)
  {
    yieldAccumulator.assertFitsInUint151();
    // slither-disable-next-line unused-return
    recordedBalance.toUint104();
    return StrategyYieldDataForToken.wrap((yieldAccumulator << 105) | (recordedBalance << 1) | strategyHadLoss);
  }

  function _keyFrom(StrategyId strategyId, address token) internal pure returns (StrategyYieldDataKey) {
    return StrategyYieldDataKey.wrap(keccak256(abi.encode(strategyId, token)));
  }
}
