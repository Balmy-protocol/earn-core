// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IEarnVault } from "./IEarnVault.sol";
import { IDelayedWithdrawalManager } from "./IDelayedWithdrawalManager.sol";

/**
 * @title Delayed Withdrawal Adapter Interface
 * @notice This contract will interact with one or more farms and handle the process of withdrawing funds that have a
 *         lock up period. When a withdrawal is initiated, adapters will register themselves to the manager, to
 *         help with discoverability. Only the manager can process a finished withdrawal
 */
interface IDelayedWithdrawalAdapter is IERC165 {
  /**
   * @notice Returns the address to Earn's vault
   * @return Earn's vault address
   */
  function vault() external view returns (IEarnVault);

  /**
   * @notice Returns the address to Earn's delayed withdrawal manager
   * @return Earn's delayed withdrawal manager's address
   */
  function manager() external view returns (IDelayedWithdrawalManager);

  /**
   * @notice Returns the estimated amount of funds that are pending for withdrawal. Note that this amount is estimated
   *         because the underlying farm might not be able to guarantee an exit amount when the withdraw is started
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
   * @notice Starts a delayed withdrawal, and associates it to the position
   * @dev Can only be called by the position's strategy. If it's the zero position, then any registered strategy can
   *      call it
   * @param positionId The position to associate to the withdrawal
   * @param token The token that is being withdrawn
   * @param amount The amount of input for the withdrawal to use. Each adapter might provide different meaning to this
   *               value
   */
  function initiateDelayedWithdrawal(uint256 positionId, address token, uint256 amount) external;

  /**
   * @notice Completes a delayed withdrawal for a given position and token
   * @dev Can only be called by the delayed withdrawal manager
   *      If there are no withdrawable funds associated to the given parameters, will just return 0
   * @param positionId The position that executed the withdrawal
   * @param token The token that is being withdrawn
   * @param recipient The account that will receive the funds
   * @return withdrawn How much was withdrawn
   * @return stillPending How much is still pending
   */
  function withdraw(
    uint256 positionId,
    address token,
    address recipient
  )
    external
    returns (uint256 withdrawn, uint256 stillPending);
}
