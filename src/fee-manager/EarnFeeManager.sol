// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IEarnFeeManager } from "../interfaces/IEarnFeeManager.sol";
import { StrategyId } from "../types/StrategyId.sol";

contract EarnFeeManager is IEarnFeeManager, AccessControl {
  error ValueGreaterThanMaximum();
  error Unauthorized();

  bytes32 public constant MANAGE_FEES_ROLE = keccak256("MANAGE_FEES_ROLE");

  uint16 public constant MAX_FEE = 1000;
  uint16 private _defaultPerformanceFee;

  mapping(StrategyId => PerformanceFee) performanceFees;

  struct PerformanceFee {
    uint16 value;
    bool isSpecific;
  }

  constructor(address[] memory initialManageFeeAdmins, uint16 initialDefaultPerformanceFee) {
    _assignRoles(MANAGE_FEES_ROLE, initialManageFeeAdmins);
    _defaultPerformanceFee = initialDefaultPerformanceFee;
  }

  /// @inheritdoc IEarnFeeManager
  function defaultPerformanceFee() external view returns (uint16 feeBps) {
    feeBps = _defaultPerformanceFee;
  }

  /// @inheritdoc IEarnFeeManager
  function getPerformanceFeeForStrategy(StrategyId strategyId) external view returns (uint16 feeBps) {
    PerformanceFee memory performanceFee = performanceFees[strategyId];
    feeBps = performanceFee.isSpecific ? performanceFee.value : _defaultPerformanceFee;
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

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length;) {
      _grantRole(role, accounts[i]);
      unchecked {
        ++i;
      }
    }
  }
}
