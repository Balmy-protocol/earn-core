// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IEarnStrategy } from "./IEarnStrategy.sol";
import { StrategyId } from "../types/StrategyId.sol";

/**
 * @title Earn Strategy Registry Interface
 * @notice This contract will act as a registry, so that Earn strategies can be updated. It will force a delay before
 *         strategies can be updated
 */
interface IEarnStrategyRegistry {
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
  function proposedUpdate(StrategyId strategyId)
    external
    view
    returns (IEarnStrategy newStrategy, uint256 executableAt);

  /**
   * @notice Returns any proposed ownership transfer for the given strategy id
   * @param strategyId The id to check for proposed ownership transfers
   * @return newOwner The new owner, or the zero address if no transfer was proposed
   */
  function proposedOwnershipTransfer(StrategyId strategyId) external view returns (address newOwner);

  /**
   * @notice Registers a new strategy
   * @dev The strategy must report the asset as the first token
   *      The strategy can't be associated to another id
   *      The new strategy must support the expected interface.
   * @param owner The strategy's owner
   * @param strategy The strategy to register
   * @return The id assigned to the new strategy
   */
  function registerStrategy(address owner, IEarnStrategy strategy) external returns (StrategyId);

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
   */
  function proposeStrategyUpdate(StrategyId strategyId, IEarnStrategy newStrategy) external;

  /**
   * @notice Cancels a strategy update
   * @dev Can only be called by the strategy's owner
   * @param strategyId The strategy that was being updated
   */
  function cancelStrategyUpdate(StrategyId strategyId) external; // Only owner

  /**
   * @notice Updates a strategy, after the delay has passed
   * @param strategyId The strategy to update
   */
  function updateStrategy(StrategyId strategyId) external;
}
