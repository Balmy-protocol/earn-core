// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { INFTPermissions } from "@mean-finance/nft-permissions/interfaces/INFTPermissions.sol";
import { IEarnStrategyRegistry } from "../interfaces/IEarnStrategyRegistry.sol";
import { IEarnStrategy } from "./IEarnStrategy.sol";
import { StrategyId } from "../types/StrategyId.sol";
import { SpecialWithdrawalCode } from "../types/SpecialWithdrawals.sol";

/**
 * @title Earn Vault Interface
 * @notice Earn's vault is the place where users deposit and withdraw their funds and rewards. Earn has a singleton
 *         vault contract, which will be the one that keeps track of who owns what. It is also the one that implements
 *         access control and makes sure that users can only access their own funds.
 */
interface IEarnVault is INFTPermissions {
  /// @notice Thrown when a user tries to make an empty deposit
  error ZeroAmountDeposit();

  /// @notice Thrown when a deposit earns the caller zero shares
  error ZeroSharesDeposit();

  /// @notice Thrown when the withdraw input is invalid
  error InvalidWithdrawInput();

  /// @notice Emitted when a new position is created
  event PositionCreated(
    uint256 positionId,
    StrategyId strategyId,
    uint256 assetsDeposited,
    address owner,
    INFTPermissions.PermissionSet[] permissions,
    bytes misc
  );

  /**
   * @notice Returns the role in charge of pausing/unpausing deposits
   * @return The role in charge of pausing/unpausing deposits
   */
  // slither-disable-next-line naming-convention
  function PAUSE_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the id of the "increase" permission
   * @return The id of the "increase" permission
   */
  // slither-disable-next-line naming-convention
  function INCREASE_PERMISSION() external pure returns (Permission);

  /**
   * @notice Returns the id of the "withdraw" permission
   * @return The id of the "withdraw" permission
   */
  // slither-disable-next-line naming-convention
  function WITHDRAW_PERMISSION() external pure returns (Permission);

  /**
   * @notice Returns the address of the strategy registrt
   * @return The address of the strategy registrt
   */
  // slither-disable-next-line naming-convention
  function STRATEGY_REGISTRY() external view returns (IEarnStrategyRegistry);

  /**
   * @notice Returns the strategy chosen by the given position
   * @param positionId The position to check
   * @return strategyId The strategy chosen by the given position. Will return 0 if the position doesn't exist
   */
  function positionsStrategy(uint256 positionId) external view returns (StrategyId strategyId);

  /**
   * @notice Returns a summary of the position's balances
   * @param positionId The position to check the balances for
   * @return tokens All of the position's tokens
   * @return withdrawalTypes The type of withdrawal for each token
   * @return balances Total balance of each token
   */
  function position(uint256 positionId)
    external
    view
    returns (address[] memory tokens, IEarnStrategy.WithdrawalType[] memory withdrawalTypes, uint256[] memory balances);

  /**
   * @notice Returns if deposits and paused
   * @return Whether deposits are paused or not
   */
  function paused() external view returns (bool);

  /**
   * @notice Creates a new position with the given strategy owner and permissions
   * @param strategyId The strategy to use for this position
   * @param depositToken The token to use for the initial deposit
   * @param depositAmount The amount to deposit. If it's max(uint256), then all balance will be taken from the caller
   *                      Using max(uint256) and the native token will end up in revert
   * @param owner The owner to set for the position
   * @param permissions The permissions to set for the position
   * @param misc Miscellaneous bytes to emit, can work for referrals and more
   * @return positionId The id of the created position
   * @return assetsDeposited How much was actually deposited in terms of the asset
   */
  function createPosition(
    StrategyId strategyId,
    address depositToken,
    uint256 depositAmount,
    address owner,
    INFTPermissions.PermissionSet[] calldata permissions,
    bytes calldata misc
  )
    external
    payable
    returns (uint256 positionId, uint256 assetsDeposited);

  /**
   * @notice Deposits more funds into an existing position
   * @dev The caller must have permissions to increase the position
   * @param positionId The position to add funds to
   * @param depositToken The token to use for the initial deposit
   * @param depositAmount The amount to deposit. If it's max(uint256), then all balance will be taken from the caller
   *                      Using max(uint256) and the native token will end up in revert
   * @return assetsDeposited How much was actually deposited in terms of the asset
   */
  function increasePosition(
    uint256 positionId,
    address depositToken,
    uint256 depositAmount
  )
    external
    payable
    returns (uint256 assetsDeposited);

  /**
   * @notice Withdraws funds from an existing position
   * @dev The caller must have permissions to withdraw from the position
   * @param positionId The position to withdraw funds from
   * @param tokensToWithdraw All position's tokens, in the same order as returned on `position`
   * @param intendedWithdraw The amounts to withdraw from the position. You can set to max(uint256) to withdraw all
   *                         that's available. Note that if a token doesn't support and immediate withdrawal, then
   *                         a delayed withdrawal will be started
   * @param recipient The account that will receive the withdrawn funds
   * @return withdrawn How much was actually withdrawn from each token
   * @return withdrawalTypes The type of withdrawal for each token
   */
  function withdraw(
    uint256 positionId,
    address[] calldata tokensToWithdraw,
    uint256[] calldata intendedWithdraw,
    address recipient
  )
    external
    payable
    returns (uint256[] memory withdrawn, IEarnStrategy.WithdrawalType[] memory withdrawalTypes);

  /**
   * @notice Performs a special withdrawal against the strategy. This is meant to be used be used in special cases, like
   *         withdrawing the farm token directly, instead of the asset. The withdraw data and result can be different
   *         for each strategy
   * @dev The caller must have permissions to withdraw from the position
   * @param positionId The position to withdraw funds from
   * @param withdrawalCode The code that identifies the special withdrawal
   * @param withdrawalData The data that defines the withdrawal
   * @param recipient The account that will receive the withdrawn funds
   * @return tokens All of the position's tokens
   * @return withdrawn How much was actually withdrawn from each token
   * @return withdrawalTypes The type of withdrawal for each token
   * @return result The result of the withdrawal. Can be different for each strategy
   */
  function specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    bytes calldata withdrawalData,
    address recipient
  )
    external
    payable
    returns (
      address[] memory tokens,
      uint256[] memory withdrawn,
      IEarnStrategy.WithdrawalType[] memory withdrawalTypes,
      bytes memory result
    );

  /**
   * @notice Pauses position creations and increases
   * @dev Can only be called by someone with the `PAUSE_ROLE` role
   */
  function pause() external payable;

  /**
   * @notice Unpauses position creations and increases
   * @dev Can only be called by someone with the `PAUSE_ROLE` role
   */
  function unpause() external payable;
}
