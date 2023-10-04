// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IEarnVault } from "./IEarnVault.sol";

/**
 * @title Delayed Withdrawal Manager Interface
 * @notice This contract will reference all delayed withdraws for all positions. When a delayed withdrawal is started,
 *         the Earn strategy will delegate the withdrawal to a delayed withdraw adapter. That adapter is the one that
 *         will start the withdraw, and then register itself to the manager. By doing so, we will be able to track all
 *         pending withdrawals for a specific position in one place (here).
 */
interface IDelayedWithdrawalManager {
  /// @notice Thrown when trying to register a delayed withdraw from an address that doesn't correspond with the token
  /// adapter
  error AdapterMismatch();

  /// @notice Thrown when trying to register a delayed withdraw for the same token and position twice
  error AdapterDuplicated();

  /**
   * @notice Emitted when a delayed withdraw is registered
   * @param positionId The position to associate the withdrawal to
   * @param token The token that is being withdrawn
   * @param adapter The delayed withdrawal adapter responsible for processing the withdrawal
   */
  event DelayedWithdrawRegistered(uint256 positionId, address token, address adapter);

  /**
   * @notice Returns the address to Earn's vault
   * @return Earn's vault address
   */
  function vault() external view returns (IEarnVault);

  /**
   * @notice Returns the estimated amount of funds that are pending for withdrawal. Note that this amount is estimated
   *         because the underlying farm might not be able to guarantee an exit amount when it is first started
   * @param positionId The position that executed the withdrawal
   * @param token The token that is being withdrawn
   * @return The estimated amount of funds that are pending for withdrawal
   */
  function estimatedPendingFunds(uint256 positionId, address token) external view returns (uint256);

  /**
   * @notice Returns the amount of funds that are available for withdrawal
   * @param positionId The position that executed the withdrawal
   * @param token The token that is being withdrawn
   * @return The amount of funds that are available for withdrawal
   */
  function withdrawableFunds(uint256 positionId, address token) external view returns (uint256);

  /**
   * @notice Returns the total amounts of funds that are pending or withdrawable, for a given position
   * @param positionId The position to check
   * @return tokens The position's tokens
   * @return estimatedPending The estimated amount of funds that are pending for withdrawal
   * @return withdrawable The amount of funds that are available for withdrawal
   */
  function allPositionFunds(uint256 positionId)
    external
    view
    returns (address[] memory tokens, uint256[] memory estimatedPending, uint256[] memory withdrawable);

  /**
   * @notice Registers a delayed withdrawal for the given position and token
   * @dev Must be called by a delayed withdrawal adapter that is referenced by the position's strategy
   * @param positionId The position to associate the withdrawal to
   * @param token The token that is being withdrawn
   */
  function registerDelayedWithdraw(uint256 positionId, address token) external;

  /**
   * @notice Completes a delayed withdrawal for a given position and token
   * @dev The caller must have withdraw permissions over the position
   *      If there are no withdrawable funds associated to the position, will just return 0
   * @param positionId The position that executed the withdrawal
   * @param token The token that is being withdrawn
   * @param recipient The account that will receive the funds
   * @return withdrawn How much was withdrawn
   */
  function withdraw(uint256 positionId, address token, address recipient) external returns (uint256 withdrawn);
}
