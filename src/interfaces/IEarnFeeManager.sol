// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { StrategyId } from "../types/StrategyId.sol";

/**
 * @title Earn Fee Manager Interface
 * @notice This manager handles performance fees
 */
interface IEarnFeeManager is IAccessControl {
  /**
   * @notice Returns the role in charge of managing fees
   * @return The role in charge of managing fees
   */
  // slither-disable-next-line naming-convention
  function MANAGE_FEES_ROLE() external view returns (bytes32);

  /**
   * @notice Returns the max amount of fee possible
   * @return The max amount of fee possible
   */
  // slither-disable-next-line naming-convention
  function MAX_FEE() external view returns (uint16);

  /**
   * @notice Returns the default performance fee
   * @return feeBps The default performance fee
   */
  function defaultPerformanceFee() external view returns (uint16 feeBps);

  /**
   * @notice Returns the performance fee to use for a specific strategy
   * @param strategyId The strategy to check
   * @return feeBps The performance fee to use for the given strategy
   */
  function getPerformanceFeeForStrategy(StrategyId strategyId) external view returns (uint16 feeBps);

  /**
   * @notice Sets the default performance fee
   * @dev Can only be called by someone with the `MANAGE_FEES_ROLE` role. Also, must be lower than `MAX_FEE`
   * @param feeBps The new default performance fee, in bps
   */
  function setDefaultPerformanceFee(uint16 feeBps) external;

  /**
   * @notice Sets a specific performance fee for the given strategy
   * @dev Can only be called by someone with the `MANAGE_FEES_ROLE` role. Also, must be lower than `MAX_FEE`
   * @param strategyId The strategy to set the fee for
   * @param feeBps The new default performance fee, in bps
   */
  function specifyPerformanceFeeForStrategy(StrategyId strategyId, uint16 feeBps) external;

  /**
   * @notice Clears the specific performance fee on the strategy and starts using the default again
   * @dev Can only be called by someone with the `MANAGE_FEES_ROLE` role.
   *      Will revert if it didn't have a specific performance fee set
   * @param strategyId The strategy to clear the fee for
   */
  function setPerformanceFeeForStrategyBackToDefault(StrategyId strategyId) external;
}
