// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IEarnStrategyRegistry, IEarnStrategy } from "../interfaces/IEarnStrategyRegistry.sol";
import { StrategyId, StrategyIdConstants } from "../types/StrategyId.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Utils } from "./utils/Utils.sol";

// TODO: remove once functions are implemented
// slither-disable-start unimplemented-functions
// solhint-disable no-empty-blocks

contract EarnStrategyRegistry is IEarnStrategyRegistry {
  using Utils for address[];

  struct ProposedUpdate {
    IEarnStrategy newStrategy;
    uint256 executableAt;
  }

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
  mapping(StrategyId strategyId => ProposedUpdate proposedUpdate) public proposedUpdate;

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
  function proposeStrategyUpdate(StrategyId strategyId, IEarnStrategy newStrategy) external onlyOwner(strategyId) {
    _revertIfNotStrategy(newStrategy);
    _revertIfNotAssetAsFirstToken(newStrategy);
    if (proposedUpdate[strategyId].executableAt != 0) revert StrategyAlreadyProposedUpdate();
    if (assignedId[newStrategy] != StrategyIdConstants.NO_STRATEGY) revert StrategyAlreadyRegistered();
    _revertIfTokensAreNotSuperset(strategyId, newStrategy);
    proposedUpdate[strategyId] = ProposedUpdate(newStrategy, block.timestamp + STRATEGY_UPDATE_DELAY);
    assignedId[newStrategy] = strategyId;
    emit StrategyUpdateProposed(strategyId, newStrategy);
  }

  /// @inheritdoc IEarnStrategyRegistry
  function cancelStrategyUpdate(StrategyId strategyId) external onlyOwner(strategyId) {
    ProposedUpdate memory proposedStrategyUpdate = proposedUpdate[strategyId];
    if (proposedStrategyUpdate.executableAt == 0) revert MissingStrategyProposedUpdate(strategyId);
    assignedId[proposedStrategyUpdate.newStrategy] = StrategyIdConstants.NO_STRATEGY;
    delete proposedUpdate[strategyId];
    emit StrategyUpdateCanceled(strategyId);
  }

  /// @inheritdoc IEarnStrategyRegistry
  function updateStrategy(StrategyId strategyId) external onlyOwner(strategyId) {
    ProposedUpdate memory proposedStrategyUpdate = proposedUpdate[strategyId];

    if (proposedStrategyUpdate.executableAt == 0) revert MissingStrategyProposedUpdate(strategyId);
    //slither-disable-next-line timestamp
    if (proposedStrategyUpdate.executableAt > block.timestamp) revert StrategyUpdateBeforeDelay(strategyId);

    IEarnStrategy oldStrategy = getStrategy[strategyId];
    getStrategy[strategyId] = proposedStrategyUpdate.newStrategy;
    assignedId[oldStrategy] = StrategyIdConstants.NO_STRATEGY;
    delete proposedUpdate[strategyId];
    emit StrategyUpdated(strategyId, proposedStrategyUpdate.newStrategy);
  }

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

  function _revertIfTokensAreNotSuperset(StrategyId strategyId, IEarnStrategy newStrategyToCheck) internal view {
    IEarnStrategy currentStrategy = getStrategy[strategyId];
    bool isSameAsset = newStrategyToCheck.asset() == currentStrategy.asset();
    if (!isSameAsset) revert AssetMismatch();
    // slither-disable-start unused-return
    (address[] memory newTokens,) = newStrategyToCheck.allTokens();
    (address[] memory currentTokens,) = currentStrategy.allTokens();
    // slither-disable-end unused-return
    bool sameOrMoreTokensSupported = newTokens.isSupersetOf(currentTokens);
    if (!sameOrMoreTokensSupported) revert TokensSupportedMismatch();
  }

  modifier onlyOwner(StrategyId strategyId) {
    if (owner[strategyId] != msg.sender) revert UnauthorizedStrategyOwner();
    _;
  }
}
// solhint-enable no-empty-blocks
// slither-disable-end unimplemented-functions
