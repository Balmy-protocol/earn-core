// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../interfaces/IEarnFeeManager.sol";

contract FeeManager is IEarnFeeManager {
  error ValueGreaterThanMaximum();
  error Unauthorized();

  bytes32 public constant MANAGE_FEES_ROLE = keccak256("MANAGE_FEES_ROLE");

  uint16 private constant MAX_FEE = 1000;
  uint16 private _defaultPerformanceFee;

  mapping(StrategyId => PerformanceFee) performanceFees;

  struct PerformanceFee {
    uint16 value;
    bool isSpecific;
  }

  constructor(uint16 defaultPerformanceFee) {
    _defaultPerformanceFee = defaultPerformanceFee;
  }

  function MANAGE_FEES_ROLE() external view returns (bytes32) {
    return MANAGE_FEES_ROLE;
  }

  /// @inheritdoc IEarnFeeManager
  function MAX_FEE() external view returns (uint16) {
    return MAX_FEE;
  }

  /// @inheritdoc IEarnFeeManager
  function defaultPerformanceFee() external view returns (uint16 feeBps) {
    feeBps = _defaultPerformanceFee;
  }

  /// @inheritdoc IEarnFeeManager
  function getPerformanceFeeForStrategy(StrategyId strategyId) external view returns (uint16 feeBps) {
    PerformanceFee performanceFee = performanceFees[strategyId];
    feeBps = performanceFee.isSpecific ? performanceFee.value : defaultPerformanceFee();
  }
  /// @inheritdoc IEarnFeeManager

  function setDefaultPerformanceFee(uint16 feeBps) external {
    if (!hasRole(MANAGE_FEES_ROLE, msg.sender)) revert Unauthorized();
    _defaultPerformanceFee = feeBps;
  }

  /// @inheritdoc IEarnFeeManager
  function specifyPerformanceFeeForStrategy(StrategyId strategyId, uint16 feeBps) external {
    if (!hasRole(MANAGE_FEES_ROLE, msg.sender)) revert Unauthorized();
    if (feeBps > MAX_FEE) revert ValueGreaterThanMaximum();
    performanceFees[strategyId] = PerformanceFee(feeBps, true);
  }

  /// @inheritdoc IEarnFeeManager
  function setPerformanceFeeForStrategyBackToDefault(StrategyId strategyId) external {
    if (!hasRole(MANAGE_FEES_ROLE, msg.sender)) revert Unauthorized();
    delete performanceFees[strategyId];
  }
}
