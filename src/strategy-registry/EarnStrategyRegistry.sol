// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IEarnStrategyRegistry, IEarnStrategy } from "../interfaces/IEarnStrategyRegistry.sol";
import { StrategyId } from "../types/StrategyId.sol";

contract EarnStrategyRegistry is IEarnStrategyRegistry {
  uint256 public constant STRATEGY_UPDATE_DELAY = 259_200; // TBD

  /// @inheritdoc IEarnStrategyRegistry
  function getStrategy(StrategyId strategyId) external view returns (IEarnStrategy) { }

  /// @inheritdoc IEarnStrategyRegistry
  function assignedId(IEarnStrategy strategy) external view returns (StrategyId) { }

  /// @inheritdoc IEarnStrategyRegistry
  function proposedUpdate(StrategyId strategyId)
    external
    view
    returns (IEarnStrategy newStrategy, uint256 executableAt)
  { }

  /// @inheritdoc IEarnStrategyRegistry
  function proposedOwnershipTransfer(StrategyId strategyId) external view returns (address newOwner) { }

  /// @inheritdoc IEarnStrategyRegistry
  function registerStrategy(address owner, IEarnStrategy strategy) external returns (StrategyId) { }

  /// @inheritdoc IEarnStrategyRegistry
  function proposeOwnershipTransfer(StrategyId strategyId, address newOwner) external { }

  /// @inheritdoc IEarnStrategyRegistry
  function cancelOwnershipTransfer(StrategyId strategyId) external { }

  /// @inheritdoc IEarnStrategyRegistry
  function acceptOwnershipTransfer(StrategyId strategyId) external { }

  /// @inheritdoc IEarnStrategyRegistry
  function proposeStrategyUpdate(StrategyId strategyId, IEarnStrategy newStrategy) external { }

  /// @inheritdoc IEarnStrategyRegistry
  function cancelStrategyUpdate(StrategyId strategyId) external { }

  /// @inheritdoc IEarnStrategyRegistry
  function updateStrategy(StrategyId strategyId) external { }
}
