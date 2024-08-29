// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { IEarnStrategy } from "./IEarnStrategy.sol";
import { StrategyId } from "../types/StrategyId.sol";

/**
 * @title Earn Strategy Registry Interface
 * @notice This contract will act as a registry, so that Earn strategies can be updated. It will force a delay before
 *         strategies can be updated
 */
interface IEarnStrategyRegistry {
  /// @notice Thrown when trying to register a strategy that is already registered
  error StrategyAlreadyRegistered();

  /// @notice Thrown when trying to propose a strategy update that has another pending proposal
  error StrategyAlreadyProposedUpdate();

  /// @notice Thrown when trying to propose a strategy update that doesn't have the same asset as the current strategy
  error AssetMismatch();

  /**
   * @notice Thrown when trying to propose a strategy update that doesn't support at least same tokens as the current
   *         strategy
   */
  error TokensSupportedMismatch();

  /**
   * @notice Thrown when the sender is not the owner of the strategy.
   */
  error UnauthorizedStrategyOwner();

  /**
   * @notice Thrown when the sender is not the strategy ownership receiver.
   */
  error UnauthorizedOwnershipReceiver();

  /**
   * @notice Thrown when trying to register an address that is not an strategy
   * @param notStrategy The address that was not a strategy
   */
  error AddressIsNotStrategy(IEarnStrategy notStrategy);

  /**
   * @notice Thrown when trying to register an strategy that does no report the asset as first token
   * @param invalidStrategy The object that was not a valid strategy
   */
  error AssetIsNotFirstToken(IEarnStrategy invalidStrategy);

  /**
   * @notice Thrown when trying to cancel a proposed update, but no new strategy has been proposed for the strategy id
   * @param strategyId The strategy id without a proposed update
   */
  error MissingStrategyProposedUpdate(StrategyId strategyId);

  /**
   * @notice Thrown when trying to confirm the proposed update before the delay has passed
   * @param strategyId The strategy id to update
   */
  error StrategyUpdateBeforeDelay(StrategyId strategyId);

  /**
   * @notice Thrown when the migration data doesn't match the expected one
   * @param strategyId The strategy id to update
   */
  error MigrationDataMismatch(StrategyId strategyId);

  /// @notice Thrown when trying to propose a strategy ownership transfer that has a pending proposal
  error StrategyOwnershipTransferAlreadyProposed();

  /// @notice Thrown when trying to cancel a proposed strategy ownership transfer without a pending proposal
  error StrategyOwnershipTransferWithoutPendingProposal();

  /// @notice Thrown when trying to confirm the proposed update with lower balances than the current one
  error ProposedStrategyBalancesAreLowerThanCurrentStrategy();

  /**
   * @notice Emitted when a new strategy is registered
   * @param owner The strategy's owner
   * @param strategyId The strategy id
   * @param strategy The strategy
   */
  event StrategyRegistered(address owner, StrategyId strategyId, IEarnStrategy strategy);

  /**
   * @notice Emitted when a new strategy is proposed
   * @param strategyId The strategy id
   * @param newStrategy The strategy
   * @param migrationData Data to be used as part of the migration
   */
  event StrategyUpdateProposed(StrategyId strategyId, IEarnStrategy newStrategy, bytes migrationData);

  /**
   * @notice Emitted when a new strategy is updated
   * @param strategyId The strategy id
   * @param newStrategy The strategy
   */
  event StrategyUpdated(StrategyId strategyId, IEarnStrategy newStrategy);

  /**
   * @notice Emitted when a proposed update is canceled
   * @param strategyId The strategy id
   * @param strategy The strategy we were going to update the id to
   */
  event StrategyUpdateCanceled(StrategyId strategyId, IEarnStrategy strategy);

  /**
   * @notice Emitted when a proposed strategy ownership transfer is proposed
   * @param strategyId The strategy id
   * @param newOwner The proposed new owner
   */
  event StrategyOwnershipTransferProposed(StrategyId strategyId, address newOwner);

  /**
   * @notice Emitted when a proposed strategy ownership transfer is canceled
   * @param strategyId The strategy id
   * @param receiver The canceled receiver
   */
  event StrategyOwnershipTransferCanceled(StrategyId strategyId, address receiver);

  /**
   * @notice Emitted when a strategy ownership is transferred
   * @param strategyId The strategy id
   * @param newOwner The new owner
   */
  event StrategyOwnershipTransferred(StrategyId strategyId, address newOwner);

  /**
   * @notice Returns the delay (in seconds) necessary to execute a proposed strategy update
   * @return The delay (in seconds) necessary to execute a proposed strategy update
   */
  // slither-disable-next-line naming-convention
  function STRATEGY_UPDATE_DELAY() external pure returns (uint256);

  /**
   * @notice Returns the strategy registered to the given id
   * @param strategyId The id to check
   * @return The registered strategy, or the zero address if none is registered
   */
  function getStrategy(StrategyId strategyId) external view returns (IEarnStrategy);

  /**
   * @notice Returns the id that is assigned to the strategy
   * @param strategy The strategy to check
   * @return The assigned if, or zero if it hasn't been assigned
   */
  function assignedId(IEarnStrategy strategy) external view returns (StrategyId);

  /**
   * @notice Returns any proposed update for the given strategy id
   * @param strategyId The id to check for proposed updates
   * @return newStrategy The new strategy
   * @return executableAt When the update will be executable
   */
  function proposedUpdate(
    StrategyId strategyId
  )
    external
    view
    returns (IEarnStrategy newStrategy, uint96 executableAt, bytes32 migrationDataHash);

  /**
   * @notice Returns any proposed ownership transfer for the given strategy id
   * @param strategyId The id to check for proposed ownership transfers
   * @return newOwner The new owner, or the zero address if no transfer was proposed
   */
  function proposedOwnershipTransfer(StrategyId strategyId) external view returns (address newOwner);

  /**
   * @notice Returns the number of registered strategies
   * @return The number of registered strategies
   */
  function totalRegistered() external view returns (uint256);

  /**
   * @notice Registers a new strategy
   * @dev The strategy must report the asset as the first token
   *      The strategy can't be associated to another id
   *      The new strategy must support the expected interface.
   * @param firstOwner The strategy's owner
   * @param strategy The strategy to register
   * @return The id assigned to the new strategy
   */
  function registerStrategy(address firstOwner, IEarnStrategy strategy) external returns (StrategyId);

  /**
   * @notice Returns the strategy's owner to the given id
   * @param strategyId The id to check
   * @return The owner of the strategy, or the zero address if none is registered
   */
  function owner(StrategyId strategyId) external view returns (address);

  /**
   * @notice Proposes an ownership transfer. Must be accepted by the new owner
   * @dev Can only be called by the strategy's owner
   * @param strategyId The id of the strategy to change ownership of
   * @param newOwner The new owner
   */
  function proposeOwnershipTransfer(StrategyId strategyId, address newOwner) external;

  /**
   * @notice Cancels an ownership transfer
   * @dev Can only be called by the strategy's owner
   * @param strategyId The id of the strategy that was being transferred
   */
  function cancelOwnershipTransfer(StrategyId strategyId) external;

  /**
   * @notice Accepts an ownership transfer, and updates the owner by doing so
   * @dev Can only be called by the strategy's new owner
   * @param strategyId The id of the strategy that was being transferred
   */
  function acceptOwnershipTransfer(StrategyId strategyId) external;

  /**
   * @notice Proposes a strategy update
   * @dev Can only be called by the strategy's owner.
   *      The strategy must report the asset as the first token
   *      The new strategy can't be associated to another id, neither can it be in the process of being associated to
   *      another id.
   *      The new strategy must support the expected interface.
   *      The new strategy must have the same asset as the strategy it's replacing.
   *      The new strategy must support the same tokens as the strategy it's replacing. It may also support new ones.
   * @param strategyId The strategy to update
   * @param newStrategy The new strategy to associate to the id
   * @param migrationData Data to be used as part of the migration
   */
  function proposeStrategyUpdate(
    StrategyId strategyId,
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    external;

  /**
   * @notice Cancels a strategy update
   * @dev Can only be called by the strategy's owner
   * @param strategyId The strategy that was being updated
   */
  function cancelStrategyUpdate(StrategyId strategyId) external;

  /**
   * @notice Updates a strategy, after the delay has passed
   * @dev The migration data must be the same as the ones passed during the proposal
   * @param strategyId The strategy to update
   * @param migrationData Data to be used as part of the migration
   */
  function updateStrategy(StrategyId strategyId, bytes calldata migrationData) external;
}
