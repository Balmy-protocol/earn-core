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
  function estimatedPendingFunds(uint256 positionId, address token) external view returns (uint256) { }

  /// @inheritdoc IDelayedWithdrawalManager
  function withdrawableFunds(uint256 positionId, address token) external view returns (uint256) { }

  /// @inheritdoc IDelayedWithdrawalManager
  function allPositionFunds(uint256 positionId)
    external
    view
    returns (address[] memory tokens, uint256[] memory estimatedPending, uint256[] memory withdrawable)
  { }

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
  function withdraw(uint256 positionId, address token, address recipient) external returns (uint256 withdrawn) { }

  function _revertIfNotCurrentStrategyAdapter(uint256 positionId, address token) internal view {
    StrategyId strategyId = vault.positionsStrategy(positionId);
    if (strategyId == StrategyIdConstants.NO_STRATEGY) revert AdapterMismatch();
    IDelayedWithdrawalAdapter adapter =
      vault.STRATEGY_REGISTRY().getStrategy(strategyId).delayedWithdrawalAdapter(token);
    if (address(adapter) != msg.sender) revert AdapterMismatch();
  }
}

// solhint-enable no-empty-blocks
