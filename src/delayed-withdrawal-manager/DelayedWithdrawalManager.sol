// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { INFTPermissions } from "@balmy/nft-permissions/interfaces/INFTPermissions.sol";
import {
  IDelayedWithdrawalManager, IEarnVault, IEarnStrategyRegistry
} from "../interfaces/IDelayedWithdrawalManager.sol";
import { IDelayedWithdrawalAdapter } from "../interfaces/IDelayedWithdrawalAdapter.sol";
import { StrategyId, StrategyIdConstants } from "../types/StrategyId.sol";
// solhint-disable-next-line no-unused-import
import { RegisteredAdapter, RegisteredAdaptersLibrary, PositionIdTokenKey } from "./types/RegisteredAdapters.sol";

contract DelayedWithdrawalManager is IDelayedWithdrawalManager {
  using RegisteredAdaptersLibrary for mapping(uint256 => mapping(address => mapping(uint256 => RegisteredAdapter)));
  using RegisteredAdaptersLibrary for mapping(uint256 => RegisteredAdapter);

  // slither-disable-start naming-convention
  mapping(uint256 position => mapping(address token => mapping(uint256 index => RegisteredAdapter registeredAdapter)))
    internal _registeredAdapters;
  /// @inheritdoc IDelayedWithdrawalManager
  // solhint-disable-next-line var-name-mixedcase
  IEarnVault public immutable VAULT;
  /// @inheritdoc IDelayedWithdrawalManager
  // solhint-disable-next-line var-name-mixedcase
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;
  // solhint-disable-next-line var-name-mixedcase
  INFTPermissions.Permission private immutable WITHDRAW_PERMISSION;

  // slither-disable-end naming-convention

  constructor(IEarnVault vault) {
    VAULT = vault;
    STRATEGY_REGISTRY = vault.STRATEGY_REGISTRY();
    WITHDRAW_PERMISSION = vault.WITHDRAW_PERMISSION();
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function estimatedPendingFunds(uint256 positionId, address token) public view returns (uint256 pendingFunds) {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters =
      _registeredAdapters.get(positionId, token);
    uint256 i = 0;

    bool shouldContinue = true;
    while (shouldContinue) {
      RegisteredAdapter memory adapter = registeredAdapters[i];
      if (address(adapter.adapter) != address(0)) {
        // slither-disable-next-line calls-loop
        pendingFunds += adapter.adapter.estimatedPendingFunds(positionId, token);
        unchecked {
          ++i;
        }
      }
      shouldContinue = adapter.isNextFilled;
    }
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function withdrawableFunds(uint256 positionId, address token) public view returns (uint256 funds) {
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters =
      _registeredAdapters.get(positionId, token);
    uint256 i = 0;
    bool shouldContinue = true;
    while (shouldContinue) {
      RegisteredAdapter memory adapter = registeredAdapters[i];
      if (address(adapter.adapter) != address(0)) {
        // slither-disable-next-line calls-loop
        funds += adapter.adapter.withdrawableFunds(positionId, token);
        unchecked {
          ++i;
        }
      }
      shouldContinue = adapter.isNextFilled;
    }
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function allPositionFunds(uint256 positionId)
    external
    view
    returns (address[] memory tokens, uint256[] memory estimatedPending, uint256[] memory withdrawable)
  {
    // slither-disable-next-line unused-return
    (tokens,,) = VAULT.position(positionId);
    uint256 tokensQuantity = tokens.length;
    estimatedPending = new uint256[](tokensQuantity);
    withdrawable = new uint256[](tokensQuantity);
    // slither-disable-start calls-loop
    for (uint256 i; i < tokensQuantity; ++i) {
      address token = tokens[i];
      mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters =
        _registeredAdapters.get(positionId, token);
      uint256 j = 0;
      bool shouldContinue = true;
      while (shouldContinue) {
        RegisteredAdapter memory adapter = registeredAdapters[j];
        if (address(adapter.adapter) != address(0)) {
          withdrawable[i] += adapter.adapter.withdrawableFunds(positionId, token);
          estimatedPending[i] += adapter.adapter.estimatedPendingFunds(positionId, token);
          unchecked {
            ++j;
          }
        }
        shouldContinue = adapter.isNextFilled;
      }
      // slither-disable-end calls-loop
    }
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function registerDelayedWithdraw(uint256 positionId, address token) external {
    _revertIfNotCurrentStrategyAdapter(positionId, token);

    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters =
      _registeredAdapters.get(positionId, token);

    (bool isRepeated, uint256 length) = registeredAdapters.isRepeated(IDelayedWithdrawalAdapter(msg.sender));
    if (isRepeated) {
      revert AdapterDuplicated();
    }
    registeredAdapters.set(length, IDelayedWithdrawalAdapter(msg.sender));
    // slither-disable-next-line reentrancy-events
    emit DelayedWithdrawalRegistered(positionId, token, msg.sender);
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function withdraw(
    uint256 positionId,
    address token,
    address recipient
  )
    external
    returns (uint256 withdrawn, uint256 stillPending)
  {
    if (!VAULT.hasPermission(positionId, msg.sender, WITHDRAW_PERMISSION)) revert UnauthorizedWithdrawal();

    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters =
      _registeredAdapters.get(positionId, token);

    uint256 j = 0;
    uint256 i = 0;
    bool shouldContinue = true;
    while (shouldContinue) {
      RegisteredAdapter memory adapter = registeredAdapters[i];
      if (address(adapter.adapter) != address(0)) {
        // slither-disable-next-line calls-loop
        (uint256 _withdrawn, uint256 _stillPending) = adapter.adapter.withdraw(positionId, token, recipient);
        withdrawn += _withdrawn;
        stillPending += _stillPending;
        if (_stillPending != 0) {
          if (i != j) {
            registeredAdapters.set(j, adapter.adapter);
          }
          unchecked {
            ++j;
          }
        }
        unchecked {
          ++i;
        }
      }
      shouldContinue = adapter.isNextFilled;
    }
    registeredAdapters.pop({ start: j, end: i });
    // slither-disable-next-line reentrancy-events
    emit WithdrawnFunds(positionId, token, recipient, withdrawn);
  }

  function _revertIfNotCurrentStrategyAdapter(uint256 positionId, address token) internal view {
    StrategyId strategyId = VAULT.positionsStrategy(positionId);
    if (strategyId == StrategyIdConstants.NO_STRATEGY) revert AdapterMismatch();
    IDelayedWithdrawalAdapter adapter = STRATEGY_REGISTRY.getStrategy(strategyId).delayedWithdrawalAdapter(token);
    if (address(adapter) != msg.sender) revert AdapterMismatch();
  }
}
