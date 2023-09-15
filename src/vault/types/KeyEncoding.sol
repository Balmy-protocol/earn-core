// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { StrategyId } from "../../types/StrategyId.sol";

type PositionAndToken is bytes32;

type StrategyAndToken is bytes32;

library KeyEncoding {
  function from(StrategyId strategyId, address token) internal pure returns (StrategyAndToken) {
    return StrategyAndToken.wrap(keccak256(abi.encode(strategyId, token)));
  }

  function from(uint256 positionId, address token) internal pure returns (PositionAndToken) {
    return PositionAndToken.wrap(keccak256(abi.encode(positionId, token)));
  }
}
