// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StrategyId } from "../../types/StrategyId.sol";
import { YieldMath } from "../libraries/YieldMath.sol";
import { CustomUintSizeChecks } from "../libraries/CustomUintSizeChecks.sol";

type YieldDataForToken is uint256;

struct YieldLossDataForToken {
  uint248 lossAccum;
  uint8 completeLossEvents;
}

library YieldDataForTokenLibrary {
  using CustomUintSizeChecks for uint256;
  using SafeCast for uint256;

  function read(
    mapping(bytes32 => YieldDataForToken) storage yieldData,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (uint256 yieldAccumulator, uint256 balance, bool hadLoss)
  {
    return _read(yieldData, _keyFrom(positionId, token));
  }

  function read(
    mapping(bytes32 => YieldDataForToken) storage yieldData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (uint256 yieldAccumulator, uint256 balance, bool hadLoss)
  {
    return _read(yieldData, _keyFrom(strategyId, token));
  }

  function read(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (uint256, uint256)
  {
    return _read(yieldLossData, _keyFrom(positionId, token));
  }

  function read(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (uint256, uint256)
  {
    return _read(yieldLossData, _keyFrom(strategyId, token));
  }

  function readRaw(
    mapping(bytes32 => YieldDataForToken) storage yieldLossData,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (YieldDataForToken)
  {
    return _readRaw(yieldLossData, _keyFrom(positionId, token));
  }

  function readRaw(
    mapping(bytes32 => YieldDataForToken) storage yieldLossData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (YieldDataForToken raw)
  {
    return _readRaw(yieldLossData, _keyFrom(strategyId, token));
  }

  function readRaw(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (YieldLossDataForToken memory)
  {
    return _readRaw(yieldLossData, _keyFrom(positionId, token));
  }

  function readRaw(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    StrategyId strategyId,
    address token
  )
    internal
    view
    returns (YieldLossDataForToken memory)
  {
    return _readRaw(yieldLossData, _keyFrom(strategyId, token));
  }

  function update(
    mapping(bytes32 => YieldDataForToken) storage yieldData,
    uint256 positionId,
    address token,
    uint256 newBalance,
    uint256 newYieldAccum,
    bool newHadLoss
  )
    internal
  {
    _update({
      yieldData: yieldData,
      key: _keyFrom(positionId, token),
      newBalance: newBalance,
      newYieldAccum: newYieldAccum,
      newHadLoss: newHadLoss
    });
  }

  function update(
    mapping(bytes32 => YieldDataForToken) storage yieldData,
    StrategyId strategyId,
    address token,
    uint256 newBalance,
    uint256 newYieldAccum,
    bool newHadLoss
  )
    internal
  {
    _update({
      yieldData: yieldData,
      key: _keyFrom(strategyId, token),
      newBalance: newBalance,
      newYieldAccum: newYieldAccum,
      newHadLoss: newHadLoss
    });
  }

  function update(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    uint256 positionId,
    address token,
    uint256 newLossAccum,
    uint256 newCompleteLossEvents
  )
    internal
  {
    _update({
      yieldLossData: yieldLossData,
      key: _keyFrom(positionId, token),
      newLossAccum: newLossAccum,
      newCompleteLossEvents: newCompleteLossEvents
    });
  }

  function update(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    StrategyId strategyId,
    address token,
    uint256 newLossAccum,
    uint256 newCompleteLossEvents
  )
    internal
  {
    _update({
      yieldLossData: yieldLossData,
      key: _keyFrom(strategyId, token),
      newLossAccum: newLossAccum,
      newCompleteLossEvents: newCompleteLossEvents
    });
  }

  function _decode(YieldDataForToken encoded)
    private
    pure
    returns (uint256 yieldAccumulator, uint256 balance, bool hadLoss)
  {
    uint256 unwrapped = YieldDataForToken.unwrap(encoded);
    yieldAccumulator = unwrapped >> 105;
    balance = (unwrapped >> 1) & 0xffffffffffffffffffffffffff;
    hadLoss = unwrapped & 0x1 == 1;
  }

  function _encode(uint256 yieldAccumulator, uint256 balance, uint256 hadLoss) private pure returns (YieldDataForToken) {
    yieldAccumulator.assertFitsInUint151();
    // slither-disable-next-line unused-return
    balance.toUint104();
    return YieldDataForToken.wrap((yieldAccumulator << 105) | (balance << 1) | hadLoss);
  }

  function _keyFrom(StrategyId strategyId, address token) internal pure returns (bytes32) {
    return keccak256(abi.encode(strategyId, token));
  }

  function _keyFrom(uint256 positionId, address token) internal pure returns (bytes32) {
    return keccak256(abi.encode(positionId, token));
  }

  function _read(
    mapping(bytes32 => YieldDataForToken) storage yieldData,
    bytes32 key
  )
    private
    view
    returns (uint256 yieldAccumulator, uint256 balance, bool hadLoss)
  {
    return _decode(_readRaw(yieldData, key));
  }

  function _read(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    bytes32 key
  )
    private
    view
    returns (uint256, uint256)
  {
    YieldLossDataForToken memory yieldLossDataForToken = _readRaw(yieldLossData, key);
    if (yieldLossDataForToken.lossAccum == 0) {
      return (YieldMath.LOSS_ACCUM_INITIAL, yieldLossDataForToken.completeLossEvents);
    }
    return (yieldLossDataForToken.lossAccum, yieldLossDataForToken.completeLossEvents);
  }

  function _readRaw(
    mapping(bytes32 => YieldDataForToken) storage yieldData,
    bytes32 key
  )
    private
    view
    returns (YieldDataForToken)
  {
    return yieldData[key];
  }

  function _readRaw(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    bytes32 key
  )
    private
    view
    returns (YieldLossDataForToken memory)
  {
    return yieldLossData[key];
  }

  function _update(
    mapping(bytes32 => YieldDataForToken) storage yieldData,
    bytes32 key,
    uint256 newBalance,
    uint256 newYieldAccum,
    bool newHadLoss
  )
    private
  {
    yieldData[key] = _encode({ yieldAccumulator: newYieldAccum, balance: newBalance, hadLoss: newHadLoss ? 1 : 0 });
  }

  function _update(
    mapping(bytes32 => YieldLossDataForToken) storage yieldLossData,
    bytes32 key,
    uint256 newLossAccum,
    uint256 newCompleteLossEvents
  )
    internal
  {
    yieldLossData[key] = YieldLossDataForToken(newLossAccum.toUint248(), newCompleteLossEvents.toUint8());
  }
}
