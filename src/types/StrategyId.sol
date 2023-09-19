// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

type StrategyId is uint96;

using { increment } for StrategyId global;

function increment(StrategyId id) pure returns (StrategyId) {
  return StrategyId.wrap(StrategyId.unwrap(id) + 1);
}

library StrategyIdConstants {
  StrategyId internal constant INITIAL_STRATEGY_ID = StrategyId.wrap(1);
}
