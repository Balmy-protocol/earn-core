// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IGlobalEarnConfig } from "../interfaces/IGlobalEarnConfig.sol";

contract GlobalEarnConfig is IGlobalEarnConfig, AccessControlDefaultAdminRules {
  /// @inheritdoc IGlobalEarnConfig
  bytes32 public constant MANAGE_FEES_ROLE = keccak256("MANAGE_FEES_ROLE");

  /// @inheritdoc IGlobalEarnConfig
  uint16 public constant MAX_FEE = 4000; // 40%

  /// @inheritdoc IGlobalEarnConfig
  uint16 public defaultFee;

  constructor(
    address superAdmin,
    address[] memory initialManageFeeAdmins,
    uint16 initialDefaultFee
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    _assignRoles(MANAGE_FEES_ROLE, initialManageFeeAdmins);
    _setDefaultFee(initialDefaultFee);
  }

  /// @inheritdoc IGlobalEarnConfig
  function setDefaultFee(uint16 feeBps) external onlyRole(MANAGE_FEES_ROLE) {
    _setDefaultFee(feeBps);
  }

  function _setDefaultFee(uint16 feeBps) internal {
    if (feeBps > MAX_FEE) revert FeeGreaterThanMaximum();
    defaultFee = feeBps;
    emit DefaultFeeChanged(feeBps);
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
