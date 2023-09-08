// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

type PositionId is uint256;

using { equals as ==, notEquals as != } for PositionId global;

function equals(PositionId id1, PositionId id2) pure returns (bool) {
  return PositionId.unwrap(id1) == PositionId.unwrap(id2);
}

function notEquals(PositionId id1, PositionId id2) pure returns (bool) {
  return PositionId.unwrap(id1) != PositionId.unwrap(id2);
}

library PositionIdConstants {
  PositionId internal constant ZERO_POSITION = PositionId.wrap(0);
}
