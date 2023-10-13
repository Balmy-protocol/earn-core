// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IDelayedWithdrawalManager, IEarnVault } from "../interfaces/IDelayedWithdrawalManager.sol";
import { IDelayedWithdrawalAdapter } from "../interfaces/IDelayedWithdrawalAdapter.sol";
import { StrategyId, StrategyIdConstants } from "../types/StrategyId.sol";
// solhint-disable-next-line no-unused-import
import { RegisteredAdapters, RegisteredAdaptersLibrary, PositionIdTokenKey } from "./types/RegisteredAdapters.sol";

// TODO: remove once functions are implemented
// solhint-disable no-empty-blocks
contract DelayedWithdrawalManager is IDelayedWithdrawalManager {
  using RegisteredAdaptersLibrary for mapping(PositionIdTokenKey => RegisteredAdapters);

  // slither-disable-next-line naming-convention
  mapping(PositionIdTokenKey key => RegisteredAdapters registeredAdapters) internal _registeredAdapters;

  /// @inheritdoc IDelayedWithdrawalManager
  IEarnVault public immutable vault;

  constructor(IEarnVault _vault) {
    vault = _vault;
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function estimatedPendingFunds(uint256 positionId, address token) public view returns (uint256 pendingFunds) {
    IDelayedWithdrawalAdapter[] memory adapters = _registeredAdapters.get(positionId, token);
    for (uint256 i; i < adapters.length;) {
      // slither-disable-next-line calls-loop
      pendingFunds += adapters[i].estimatedPendingFunds(positionId, token);
      unchecked {
        ++i;
      }
    }
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function withdrawableFunds(uint256 positionId, address token) public view returns (uint256 funds) {
    IDelayedWithdrawalAdapter[] memory adapters = _registeredAdapters.get(positionId, token);
    for (uint256 i; i < adapters.length;) {
      // slither-disable-next-line calls-loop
      funds += adapters[i].withdrawableFunds(positionId, token);
      unchecked {
        ++i;
      }
    }
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function allPositionFunds(uint256 positionId)
    external
    view
    returns (address[] memory tokens, uint256[] memory estimatedPending, uint256[] memory withdrawable)
  {
    // slither-disable-next-line unused-return
    (tokens,,) = vault.position(positionId);
    uint256 tokensQuantity = tokens.length;
    estimatedPending = new uint256[](tokensQuantity);
    withdrawable = new uint256[](tokensQuantity);

    for (uint256 i; i < tokensQuantity;) {
      address token = tokens[i];
      // slither-disable-start calls-loop
      estimatedPending[i] = estimatedPendingFunds(positionId, token);
      withdrawable[i] = withdrawableFunds(positionId, token);
      // slither-disable-end calls-loop
      unchecked {
        ++i;
      }
    }
  }

  /// @inheritdoc IDelayedWithdrawalManager
  function registerDelayedWithdraw(uint256 positionId, address token) external {
    _revertIfNotCurrentStrategyAdapter(positionId, token);
    if (_registeredAdapters.isRepeated(positionId, token, IDelayedWithdrawalAdapter(msg.sender))) {
      revert AdapterDuplicated();
    }
    _registeredAdapters.register(positionId, token, IDelayedWithdrawalAdapter(msg.sender));

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
    if (!vault.hasPermission(positionId, msg.sender, vault.WITHDRAW_PERMISSION())) revert UnauthorizedWithdrawal();

    IDelayedWithdrawalAdapter[] memory adapters = _registeredAdapters.get(positionId, token);
    uint256 j = 0;
    for (uint256 i; i < adapters.length;) {
      // slither-disable-next-line calls-loop
      (uint256 _withdrawn, uint256 _stillPending) = adapters[i].withdraw(positionId, token, recipient);
      withdrawn += _withdrawn;
      stillPending += _stillPending;
      if (_stillPending != 0 && i != j) {
        _registeredAdapters.set(positionId, token, j, adapters[i]);
        unchecked {
          ++j;
        }
      }
      unchecked {
        ++i;
      }
    }
    _registeredAdapters.pop({ positionId: positionId, token: token, times: adapters.length - j });
    // slither-disable-next-line reentrancy-events
    emit WithdrawnFunds(positionId, token, recipient, withdrawn);
  }

  function _revertIfNotCurrentStrategyAdapter(uint256 positionId, address token) internal view {
    StrategyId strategyId = vault.positionsStrategy(positionId);
    if (strategyId == StrategyIdConstants.NO_STRATEGY) revert AdapterMismatch();
    IDelayedWithdrawalAdapter adapter =
      vault.STRATEGY_REGISTRY().getStrategy(strategyId).delayedWithdrawalAdapter(token);
    if (address(adapter) != msg.sender) revert AdapterMismatch();
  }
}

// solhint-enable no-empty-blocks
