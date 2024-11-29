// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IEarnStrategyRegistry } from "./IEarnStrategyRegistry.sol";
import { IEarnVault } from "./IEarnVault.sol";
import { StrategyId } from "../types/StrategyId.sol";
import { SpecialWithdrawalCode } from "../types/SpecialWithdrawals.sol";

/**
 * @title Earn Strategy Interface
 * @notice In Earn, a strategy will take an asset (could be ERC20 or native) and generate yield with it. The generated
 *         yield could be in the same asset, or in other tokens. One strategy could generate yield on multiple tokens
 *         at the same time
 * @dev For the proper functioning of the platform, there are some restrictions that strategy devs must consider:
 *      - The asset cannot change over time, it must always be the same
 *      - The strategy must report the asset as the first token
 *      - Tokens can never be removed from the list. New ones can be added, but they cannot be removed later
 *      - Functions like `withdrawalTypes` and `totalBalances` must return the same amount of values as `allTokens`, and
 *        in the same order too
 *      - Yield generation should ideally be continuous over time, instead of happening "all at once". If the latter
 *        happens, then an attacker might try to front-run the yield generation event to keep most yield to themselves
 *      - During a withdrawal, a user might get less tokens than requested in some cases, like if the strategy
 *        implements withdrawal fee. This is ok and expected but, if for some reason, a strategy does not have enough
 *        funds to cover the expected withdrawal amount (the one that considers the fee), then the withdrawal must
 *        revert. For example, if a strategy deposits funds in a lending market and most of the funds are borrowed,
 *        then the strategy must revert
 *      - Tokens with very high supplies or a high amount of decimals might not fit correctly into the Vault's
 *        accounting system. For more information about this, please refer to the [README](../vault/README.md).
 *      Take into account some strategies might not support an immediate withdraw of all tokens, since they
 *      might implement a lock up period. If that's the case, then executing a withdraw will start what we call a
 *      "delayed withdrawal". This is a process where the funds are sent to a "delayed withdrawal" adapter,
 *      which is in charge of handling this process. Users will be able to monitor their funds through the
 *      "delayed withdrawal" manager, who aggregates all available adapters. Finally, once the withdrawal can be
 *      executed, only those with withdraw permissions over the position will be able to retrieve the funds
 */
interface IEarnStrategy is IERC165 {
  /// @notice The type of withdrawal supported for a specific token
  enum WithdrawalType {
    IMMEDIATE,
    DELAYED
  }

  /// @notice The type of fee charged for a specific token
  enum FeeType {
    PERFORMANCE,
    DEPOSIT,
    WITHDRAW,
    RESCUE,
    OTHER
  }

  /**
   * @notice Returns the address to Earn's vault
   * @return Earn's vault address
   */
  function vault() external view returns (IEarnVault);

  /**
   * @notice Returns the address to Earn's strategy registry
   * @return Earn's strategy registry address
   */
  function registry() external view returns (IEarnStrategyRegistry);

  /**
   * @notice Returns the asset this strategy will use to generate yield
   * @return The asset this strategy will use to generate yield
   */
  function asset() external view returns (address);

  /**
   * @notice Returns the strategy's description
   * @return The strategy's description
   */
  function description() external view returns (string memory);

  /**
   * @notice Returns all tokens under the strategy's control
   * @dev The asset must be the first token returned
   * @return tokens All tokens under the strategy's control
   */
  function allTokens() external view returns (address[] memory tokens);

  /**
   * @notice Returns the types of withdrawals supported for each token
   * @dev In the same order returned as `tokens`
   * @return The types of withdrawals for each token
   */
  function supportedWithdrawals() external view returns (WithdrawalType[] memory);

  /**
   * @notice Returns whether a specific token can be used to deposit funds into the strategy
   * @param depositToken The token to check
   * @return Whether the given token can be used to deposit funds into the strategy
   */
  function isDepositTokenSupported(address depositToken) external view returns (bool);

  /**
   * @notice Returns all tokens that can be used  to deposit funds into the strategy
   * @return All tokens that can be used  to deposit funds into the strategy
   */
  function supportedDepositTokens() external view returns (address[] memory);

  /**
   * @notice Returns how much can be deposited from the given token
   * @dev Will return 0 if the token is not supported
   * @return How much can be deposited from the given token
   */
  function maxDeposit(address depositToken) external view returns (uint256);

  /**
   * @notice Returns how many tokens are currently under the strategy's control
   */
  function totalBalances() external view returns (address[] memory tokens, uint256[] memory balances);

  /**
   * @notice Returns whether a specific withdrawal method can be used
   * @param withdrawalCode The withdrawal method to check
   * @return Whether the given withdrawal method can be used to withdraw funds
   */
  function isSpecialWithdrawalSupported(SpecialWithdrawalCode withdrawalCode) external view returns (bool);

  /**
   * @notice Returns all withdrawal methods can be used  to withdraw funds
   * @return All withdrawal methods can be used  to withdraw funds
   */
  function supportedSpecialWithdrawals() external view returns (SpecialWithdrawalCode[] memory);

  /**
   * @notice Returns how much can be withdrawn at this moment
   * @return tokens All tokens under the strategy's control
   * @return withdrawable How much can be withdrawn for each one
   */
  function maxWithdraw() external view returns (address[] memory tokens, uint256[] memory withdrawable);

  /**
   * @notice Returns how much is charged in terms of fees, for each token
   * @return types The type of fee charged for each token
   * @return bps How much fee is being charged, in basis points
   */
  function fees() external view returns (FeeType[] memory types, uint16[] memory bps);

  /**
   * @notice Notifies the strategy that funds have been deposited into it
   * @dev Will revert if the given token is not supported
   * @param depositToken The token that was deposited
   * @param depositAmount The amount that was deposited
   * @return assetsDeposited How much was deposited, measured in asset
   */
  function deposited(address depositToken, uint256 depositAmount) external payable returns (uint256 assetsDeposited);

  /**
   * @notice Executes a withdraw, for the given tokens and amounts. If a token only supports delayed withdrawals,
   *         then one will be started and associated to the given position
   * @dev Can only be called by the vault
   * @param positionId The position that initiated the withdrawal
   * @param tokens All tokens supported by the strategy, in the same order as in `tokens`
   * @param toWithdraw How much to withdraw from each
   * @param recipient The account that will receive the tokens
   * @return The types of withdrawals for each token
   */
  function withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    external
    returns (WithdrawalType[] memory);

  /**
   * @notice Executes a special withdraw
   * @dev Can only be called by the vault
   * @param positionId The position that initiated the withdrawal
   * @param withdrawalCode The code that identifies the type of withdrawal
   * @param toWithdraw Amounts to withdraw, based on the withdrawal code. Does not need to have the same
   *                   length or order as `tokens`
   * @param withdrawalData Data necessary to execute the withdrawal
   * @param recipient The account that will receive the tokens
   * @return balanceChanges Changes in the position's balances
   * @return actualWithdrawnTokens The tokens that were actually withdrawn
   * @return actualWithdrawnAmounts How much was withdrawn from each token
   * @return result Some custom data related to the withdrawal
   */
  function specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawalData,
    address recipient
  )
    external
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    );

  /**
   * @notice Migrates all tokens and data to a new strategy
   * @dev Can only be called by the strategy registry
   * @param newStrategy The strategy to migrate to
   * @param migrationData Data to be used as part of the migration
   * @return Data related to the result of the migration. Will be sent to the new strategy
   */
  function migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    external
    returns (bytes memory);

  /**
   * @notice Performs any necessary preparations to be used by the vault
   * @dev Can only be called by the strategy registry
   * @param strategyId The id that this strategy was registered to
   * @param oldStrategy The previous strategy registered to the id. Will be the zero address if this is the first
   *                    strategy registered to the id
   * @param migrationResultData Data sent by the previous strategy registered to the id. Will be empty if this is the
   *                      first strategy registered to the id
   */
  function strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationResultData
  )
    external;

  /**
   * @notice Validates if the position can be created for this strategy, and fails it it can't
   * @dev While most implementations of this function don't modify state, we want to be flexible and allow potential
   *      implementations that do modify it. Since this function is called inside a function that supports non-view
   *      calls, we can support it
   * @param sender The address to be checked
   * @param creationData The hash to check with the sender
   */
  function validatePositionCreation(address sender, bytes calldata creationData) external;
}
