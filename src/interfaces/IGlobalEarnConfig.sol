// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title Earn Fee Manager Interface
 * @notice This manager handles fees
 */
interface IGlobalEarnConfig is IAccessControl {
  /// @notice Thrown when trying to set a fee greater than the maximum fee
  error FeeGreaterThanMaximum();

  /**
   * @notice Emitted when a new default fee is set
   * @param feeBps The new fee
   */
  event DefaultFeeChanged(uint16 feeBps);

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
   * @notice Returns the default fee
   * @return feeBps The default fee
   */
  function defaultFee() external view returns (uint16 feeBps);

  /**
   * @notice Sets the default fee
   * @dev Can only be called by someone with the `MANAGE_FEES_ROLE` role. Also, must be lower than `MAX_FEE`
   * @param feeBps The new default fee, in bps
   */
  function setDefaultFee(uint16 feeBps) external;
}
