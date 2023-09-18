// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IEarnStrategyRegistry, IEarnStrategy } from "../interfaces/IEarnStrategyRegistry.sol";
import { StrategyId, StrategyIdConstants } from "../types/StrategyId.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

// TODO: remove once functions are implemented
// slither-disable-start unimplemented-functions
// solhint-disable no-empty-blocks

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
  // slither-disable-next-line naming-convention
  StrategyId internal _nextStrategyId = StrategyIdConstants.INITIAL_STRATEGY_ID;

  /// @inheritdoc IEarnStrategyRegistry
  mapping(StrategyId strategyId => IEarnStrategy strategy) public getStrategy;

  /// @inheritdoc IEarnStrategyRegistry
  mapping(IEarnStrategy strategy => StrategyId strategyId) public assignedId;

  /// @inheritdoc IEarnStrategyRegistry
  mapping(StrategyId strategyId => address owner) public owner;

  /// @inheritdoc IEarnStrategyRegistry
  function proposedUpdate(StrategyId strategyId)
    external
    view
    returns (IEarnStrategy newStrategy, uint256 executableAt)
  { }

  /// @inheritdoc IEarnStrategyRegistry
  function proposedOwnershipTransfer(StrategyId strategyId) external view returns (address newOwner) { }

  /// @inheritdoc IEarnStrategyRegistry
  function registerStrategy(address firstOwner, IEarnStrategy strategy) external returns (StrategyId strategyId) {
    _revertIfNotStrategy(strategy);
    _revertIfNotAssetAsFirstToken(strategy);
    if (assignedId[strategy] != StrategyIdConstants.NO_STRATEGY) revert StrategyAlreadyRegistered();
    strategyId = _nextStrategyId;
    assignedId[strategy] = strategyId;
    getStrategy[strategyId] = strategy;
    owner[strategyId] = firstOwner;
    _nextStrategyId = strategyId.increment();
    emit StrategyRegistered(firstOwner, strategyId, strategy);
    // TODO: call strategy.strategyRegistered
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

  function _revertIfNotStrategy(IEarnStrategy strategyToCheck) internal view {
    bool isStrategy = ERC165Checker.supportsInterface(address(strategyToCheck), type(IEarnStrategy).interfaceId);
    if (!isStrategy) revert AddressIsNotStrategy(strategyToCheck);
  }

  function _revertIfNotAssetAsFirstToken(IEarnStrategy strategyToCheck) internal view {
    // slither-disable-next-line unused-return
    (address[] memory tokens,) = strategyToCheck.allTokens();
    bool isAssetFirstToken = (strategyToCheck.asset() == tokens[0]);
    if (!isAssetFirstToken) revert AssetIsNotFirstToken(strategyToCheck);
  }
}
// solhint-enable no-empty-blocks
// slither-disable-end unimplemented-functions
