// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { AccessControlDefaultAdminRules } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IEarnFeeManager } from "../interfaces/IEarnFeeManager.sol";
import { StrategyId } from "../types/StrategyId.sol";

contract EarnFeeManager is IEarnFeeManager, AccessControlDefaultAdminRules {
  /// @inheritdoc IEarnFeeManager
  bytes32 public constant MANAGE_FEES_ROLE = keccak256("MANAGE_FEES_ROLE");

  /// @inheritdoc IEarnFeeManager
  uint16 public constant MAX_FEE = 4000;

  /// @inheritdoc IEarnFeeManager
  uint16 public defaultPerformanceFee;

  mapping(StrategyId strategyId => PerformanceFee performanceFee) internal _performanceFees;

  struct PerformanceFee {
    uint16 value;
    bool isSpecific;
  }

  constructor(address[] memory initialManageFeeAdmins, uint16 initialDefaultPerformanceFee) {
    _assignRoles(MANAGE_FEES_ROLE, initialManageFeeAdmins);
    defaultPerformanceFee = initialDefaultPerformanceFee;
    emit DefaultPerformanceFeeChanged(initialDefaultPerformanceFee);
  }

  /// @inheritdoc IEarnFeeManager
  function getPerformanceFeeForStrategy(StrategyId strategyId) external view returns (uint16 feeBps) {
    PerformanceFee memory performanceFee = _performanceFees[strategyId];
    feeBps = performanceFee.isSpecific ? performanceFee.value : defaultPerformanceFee;
  }

  /// @inheritdoc IEarnFeeManager
  function setDefaultPerformanceFee(uint16 feeBps) external onlyRole(MANAGE_FEES_ROLE) {
    defaultPerformanceFee = feeBps;
    emit DefaultPerformanceFeeChanged(feeBps);
  }

  /// @inheritdoc IEarnFeeManager
  function specifyPerformanceFeeForStrategy(StrategyId strategyId, uint16 feeBps) external onlyRole(MANAGE_FEES_ROLE) {
    if (feeBps > MAX_FEE) revert FeeGreaterThanMaximum();
    _performanceFees[strategyId] = PerformanceFee(feeBps, true);
  }

  /// @inheritdoc IEarnFeeManager
  function setPerformanceFeeForStrategyBackToDefault(StrategyId strategyId) external onlyRole(MANAGE_FEES_ROLE) {
    delete _performanceFees[strategyId];
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
