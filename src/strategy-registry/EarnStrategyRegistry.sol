// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IEarnStrategyRegistry, IEarnStrategy } from "../interfaces/IEarnStrategyRegistry.sol";
import { StrategyId } from "../types/StrategyId.sol";

contract EarnStrategyRegistry is IEarnStrategyRegistry {
  uint256 public constant STRATEGY_UPDATE_DELAY = 3 days;

  uint96 internal _lastUsedStrategyId = 0;
  mapping(StrategyId strategyId => StrategyRegistered strategyRegistered) internal _strategyById;
  mapping(IEarnStrategy strategy => StrategyId strategyId) internal _idByStrategy;

  struct StrategyRegistered {
    IEarnStrategy strategy;
    address owner;
    uint256 lastUpdated;
    bool accepted;
  }

  /// @inheritdoc IEarnStrategyRegistry
  function getStrategy(StrategyId strategyId) external view returns (IEarnStrategy) {
    StrategyRegistered memory strategyRegistered = _strategyById[strategyId];
    return strategyRegistered.strategy;
  }

  /// @inheritdoc IEarnStrategyRegistry
  function assignedId(IEarnStrategy strategy) external view returns (StrategyId) {
    return _idByStrategy[strategy];
  }

  /// @inheritdoc IEarnStrategyRegistry
  function proposedUpdate(StrategyId strategyId)
    external
    view
    returns (IEarnStrategy newStrategy, uint256 executableAt)
  { }

  /// @inheritdoc IEarnStrategyRegistry
  function proposedOwnershipTransfer(StrategyId strategyId) external view returns (address newOwner) { }

  /// @inheritdoc IEarnStrategyRegistry
  function registerStrategy(address owner, IEarnStrategy strategy) external returns (StrategyId) {
    StrategyId strategyId = StrategyId.wrap(++_lastUsedStrategyId);
    _idByStrategy[strategy] = strategyId;
    _strategyById[strategyId] = StrategyRegistered(strategy, owner, block.timestamp, false);
    return strategyId;
  }

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
// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IEarnStrategyRegistry, IEarnStrategy } from "../interfaces/IEarnStrategyRegistry.sol";
import { StrategyId } from "../types/StrategyId.sol";

contract EarnStrategyRegistry is IEarnStrategyRegistry {
  uint256 public constant STRATEGY_UPDATE_DELAY = 3 days;

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
