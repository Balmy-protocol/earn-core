// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { StrategyId } from "../../types/StrategyId.sol";
import { YieldMath } from "../libraries/YieldMath.sol";

/// @notice A key composed of a strategy id and a token address
type StrategyYieldLossDataKey is bytes32;

library StrategyYieldLossDataForTokenLibrary {
  /**
   * @notice Reads a strategy's yield loss data from storage
   */
  function read(
    mapping(StrategyYieldLossDataKey => uint256) storage strategyYieldLossData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (uint256)
  {
    uint256 strategyLossAccum = strategyYieldLossData[_keyFrom(strategyId, token)];
    return (strategyLossAccum == 0) ? YieldMath.LOSS_ACCUM_INITIAL : strategyLossAccum;
  }

  /**
   * @notice Updates a strategy's yield loss data based on the given values
   */
  function update(
    mapping(StrategyYieldLossDataKey => uint256) storage strategyYieldLossData,
    StrategyId strategyId,
    address token,
    uint256 newStrategyLossAccum
  )
    internal
  {
    strategyYieldLossData[_keyFrom(strategyId, token)] = newStrategyLossAccum;
  }

  function _keyFrom(StrategyId strategyId, address token) internal pure returns (StrategyYieldLossDataKey) {
    return StrategyYieldLossDataKey.wrap(keccak256(abi.encode(strategyId, token)));
  }
}
