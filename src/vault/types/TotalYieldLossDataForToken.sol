// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { StrategyId } from "../../types/StrategyId.sol";
import { YieldMath } from "../libraries/YieldMath.sol";

/// @notice A key composed of a strategy id and a token address
type TotalYieldLossDataKey is bytes32;

library TotalYieldLossDataForTokenLibrary {
  /**
   * @notice Reads a strategy's yield loss data from storage
   */
  function read(
    mapping(TotalYieldLossDataKey => uint256) storage totalYieldLossData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (uint256)
  {
    uint256 lossAccum = totalYieldLossData[_keyFrom(strategyId, token)];
    return (lossAccum == 0) ? YieldMath.LOSS_ACCUM_INITIAL : lossAccum;
  }

  /**
   * @notice Updates a strategy's yield loss data based on the given values
   */
  function update(
    mapping(TotalYieldLossDataKey => uint256) storage totalYieldLossData,
    StrategyId strategyId,
    address token,
    uint256 lossAccum
  )
    internal
  {
    totalYieldLossData[_keyFrom(strategyId, token)] = lossAccum;
  }

  function _keyFrom(StrategyId strategyId, address token) internal pure returns (TotalYieldLossDataKey) {
    return TotalYieldLossDataKey.wrap(keccak256(abi.encode(strategyId, token)));
  }
}
