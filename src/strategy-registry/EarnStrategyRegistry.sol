// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategyRegistry, IEarnStrategy } from "../interfaces/IEarnStrategyRegistry.sol";
import { StrategyId, StrategyIdConstants } from "../types/StrategyId.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Utils } from "./utils/Utils.sol";

contract EarnStrategyRegistry is IEarnStrategyRegistry {
  using Utils for address[];

  struct ProposedUpdate {
    IEarnStrategy newStrategy;
    uint96 executableAt;
    bytes32 migrationDataHash;
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
  mapping(StrategyId strategyId => address newOwner) public proposedOwnershipTransfer;

  /// @inheritdoc IEarnStrategyRegistry
  function totalRegistered() external view returns (uint256) {
    return StrategyId.unwrap(_nextStrategyId) - 1;
  }

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
    strategy.strategyRegistered(strategyId, IEarnStrategy(address(0)), "");
  }

  /// @inheritdoc IEarnStrategyRegistry
  function proposeOwnershipTransfer(StrategyId strategyId, address newOwner) external onlyOwner(strategyId) {
    if (proposedOwnershipTransfer[strategyId] != address(0)) revert StrategyOwnershipTransferAlreadyProposed();
    proposedOwnershipTransfer[strategyId] = newOwner;
    emit StrategyOwnershipTransferProposed(strategyId, newOwner);
  }

  /// @inheritdoc IEarnStrategyRegistry
  function cancelOwnershipTransfer(StrategyId strategyId) external onlyOwner(strategyId) {
    address proposedOwner = proposedOwnershipTransfer[strategyId];
    if (proposedOwner == address(0)) revert StrategyOwnershipTransferWithoutPendingProposal();
    delete proposedOwnershipTransfer[strategyId];
    emit StrategyOwnershipTransferCanceled(strategyId, proposedOwner);
  }

  /// @inheritdoc IEarnStrategyRegistry
  function acceptOwnershipTransfer(StrategyId strategyId) external {
    address newOwner = proposedOwnershipTransfer[strategyId];
    if (newOwner != msg.sender) revert UnauthorizedOwnershipReceiver();
    owner[strategyId] = newOwner;
    delete proposedOwnershipTransfer[strategyId];
    emit StrategyOwnershipTransferred(strategyId, newOwner);
  }

  /// @inheritdoc IEarnStrategyRegistry
  function proposeStrategyUpdate(
    StrategyId strategyId,
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    external
    onlyOwner(strategyId)
  {
    _revertIfNotStrategy(newStrategy);
    _revertIfNotAssetAsFirstToken(newStrategy);
    if (proposedUpdate[strategyId].executableAt != 0) revert StrategyAlreadyProposedUpdate();
    if (assignedId[newStrategy] != StrategyIdConstants.NO_STRATEGY) revert StrategyAlreadyRegistered();
    _revertIfTokensAreNotSuperset(strategyId, newStrategy);
    proposedUpdate[strategyId] =
      ProposedUpdate(newStrategy, uint96(block.timestamp + STRATEGY_UPDATE_DELAY), keccak256(migrationData));
    assignedId[newStrategy] = strategyId;
    emit StrategyUpdateProposed(strategyId, newStrategy, migrationData);
  }

  /// @inheritdoc IEarnStrategyRegistry
  function cancelStrategyUpdate(StrategyId strategyId) external onlyOwner(strategyId) {
    ProposedUpdate memory proposedStrategyUpdate = proposedUpdate[strategyId];
    if (proposedStrategyUpdate.executableAt == 0) revert MissingStrategyProposedUpdate(strategyId);
    assignedId[proposedStrategyUpdate.newStrategy] = StrategyIdConstants.NO_STRATEGY;
    delete proposedUpdate[strategyId];
    emit StrategyUpdateCanceled(strategyId, proposedStrategyUpdate.newStrategy);
  }

  /// @inheritdoc IEarnStrategyRegistry
  function updateStrategy(StrategyId strategyId, bytes calldata migrationData) external onlyOwner(strategyId) {
    ProposedUpdate memory proposedStrategyUpdate = proposedUpdate[strategyId];

    if (proposedStrategyUpdate.executableAt == 0) revert MissingStrategyProposedUpdate(strategyId);
    if (proposedStrategyUpdate.migrationDataHash != keccak256(migrationData)) revert MigrationDataMismatch(strategyId);
    //slither-disable-next-line timestamp
    if (proposedStrategyUpdate.executableAt > block.timestamp) revert StrategyUpdateBeforeDelay(strategyId);

    IEarnStrategy oldStrategy = getStrategy[strategyId];

    getStrategy[strategyId] = proposedStrategyUpdate.newStrategy;
    assignedId[oldStrategy] = StrategyIdConstants.NO_STRATEGY;
    delete proposedUpdate[strategyId];
    emit StrategyUpdated(strategyId, proposedStrategyUpdate.newStrategy);
    (address[] memory oldStrategyTokens, uint256[] memory oldStrategyBalances) = oldStrategy.totalBalances();
    // slither-disable-next-line reentrancy-no-eth
    bytes memory migrationResultData =
      oldStrategy.migrateToNewStrategy(proposedStrategyUpdate.newStrategy, migrationData);
    (address[] memory newStrategyTokens, uint256[] memory newStrategyBalances) =
      proposedStrategyUpdate.newStrategy.totalBalances();
    _revertIfNewStrategyBalancesAreLowerThanOldStrategyBalances(
      oldStrategyTokens, oldStrategyBalances, newStrategyTokens, newStrategyBalances
    );
    proposedStrategyUpdate.newStrategy.strategyRegistered(strategyId, oldStrategy, migrationResultData);
  }

  function _revertIfNotStrategy(IEarnStrategy strategyToCheck) internal view {
    bool isStrategy = ERC165Checker.supportsInterface(address(strategyToCheck), type(IEarnStrategy).interfaceId);
    if (!isStrategy) revert AddressIsNotStrategy(strategyToCheck);
  }

  function _revertIfNotAssetAsFirstToken(IEarnStrategy strategyToCheck) internal view {
    address[] memory tokens = strategyToCheck.allTokens();
    bool isAssetFirstToken = (strategyToCheck.asset() == tokens[0]);
    if (!isAssetFirstToken) revert AssetIsNotFirstToken(strategyToCheck);
  }

  function _revertIfTokensAreNotSuperset(StrategyId strategyId, IEarnStrategy newStrategyToCheck) internal view {
    IEarnStrategy currentStrategy = getStrategy[strategyId];
    bool isSameAsset = newStrategyToCheck.asset() == currentStrategy.asset();
    if (!isSameAsset) revert AssetMismatch();
    address[] memory newTokens = newStrategyToCheck.allTokens();
    address[] memory currentTokens = currentStrategy.allTokens();
    bool sameOrMoreTokensSupported = newTokens.isSupersetOf(currentTokens);
    if (!sameOrMoreTokensSupported) revert TokensSupportedMismatch();
  }

  function _revertIfNewStrategyBalancesAreLowerThanOldStrategyBalances(
    address[] memory oldStrategyTokens,
    uint256[] memory oldStrategyBalances,
    address[] memory newStrategyTokens,
    uint256[] memory newStrategyBalances
  )
    internal
    pure
  {
    // While nested loops can be very expensive, we expect strategies to have a small number of tokens. We assume
    // that almost all of them will have one token, with some having maybe two tokens, and very rarely having three.
    for (uint256 i; i < oldStrategyTokens.length; ++i) {
      uint256 j;
      while (j < newStrategyTokens.length && oldStrategyTokens[i] != newStrategyTokens[j]) {
        unchecked {
          ++j;
        }
      }
      if (j == newStrategyTokens.length) {
        // Token wasn't found
        revert TokensSupportedMismatch();
      } else if (oldStrategyBalances[i] > newStrategyBalances[j]) {
        // Token was there, but it seems balance was lost somehow
        revert ProposedStrategyBalancesAreLowerThanCurrentStrategy();
      }
    }
  }

  modifier onlyOwner(StrategyId strategyId) {
    if (owner[strategyId] != msg.sender) revert UnauthorizedStrategyOwner();
    _;
  }
}
