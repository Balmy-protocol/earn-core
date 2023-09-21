// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IEarnFeeManager, StrategyId } from "../../src/interfaces/IEarnFeeManager.sol";

contract EarnFeeManagerMock is IEarnFeeManager, AccessControl {
  error NotImplemented();

  uint16 public defaultPerformanceFee;

  constructor(uint16 defaultPerformanceFee_) {
    defaultPerformanceFee = defaultPerformanceFee_;
  }

  function getPerformanceFeeForStrategy(StrategyId) external view returns (uint16 feeBps) {
    return defaultPerformanceFee;
  }

  function MANAGE_FEES_ROLE() external pure returns (bytes32) {
    revert NotImplemented();
  }

  function MAX_FEE() external pure returns (uint16) {
    revert NotImplemented();
  }

  function setDefaultPerformanceFee(uint16) external pure {
    revert NotImplemented();
  }

  function specifyPerformanceFeeForStrategy(StrategyId, uint16) external pure {
    revert NotImplemented();
  }

  function setPerformanceFeeForStrategyBackToDefault(StrategyId) external pure {
    revert NotImplemented();
  }
}
