// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

type StrategyId is uint96;

using { increment, equals as ==, notEquals as != } for StrategyId global;

function increment(StrategyId id) pure returns (StrategyId) {
  return StrategyId.wrap(StrategyId.unwrap(id) + 1);
}

function equals(StrategyId id1, StrategyId id2) pure returns (bool) {
  return StrategyId.unwrap(id1) == StrategyId.unwrap(id2);
}

function notEquals(StrategyId id1, StrategyId id2) pure returns (bool) {
  return StrategyId.unwrap(id1) != StrategyId.unwrap(id2);
}

library StrategyIdConstants {
  StrategyId internal constant NO_STRATEGY = StrategyId.wrap(0);
  StrategyId internal constant INITIAL_STRATEGY_ID = StrategyId.wrap(1);
}
