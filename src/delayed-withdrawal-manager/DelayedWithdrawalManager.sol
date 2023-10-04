// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { IDelayedWithdrawalManager, IEarnVault } from "../interfaces/IDelayedWithdrawalManager.sol";
import { IDelayedWithdrawalAdapter } from "../interfaces/IDelayedWithdrawalAdapter.sol";
import { StrategyId, StrategyIdConstants } from "../types/StrategyId.sol";

// TODO: remove once functions are implemented
// solhint-disable no-empty-blocks
contract DelayedWithdrawalManager is IDelayedWithdrawalManager {
  /// @notice A key composed of a position id and a token address
  type PositionIdTokenKey is bytes32;

  // slither-disable-next-line naming-convention
  mapping(PositionIdTokenKey key => address[] adapter) internal _registeredAdapters;

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
    _revertIfAdapterIsDuplicated(positionId, token);
    _registeredAdapters[_keyFrom(positionId, token)].push(msg.sender);

    emit DelayedWithdrawRegistered(positionId, token, msg.sender);
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

  function _revertIfAdapterIsDuplicated(uint256 positionId, address token) internal view {
    address[] memory adapters = _registeredAdapters[_keyFrom(positionId, token)];
    for (uint256 i; i < adapters.length;) {
      if (adapters[i] == msg.sender) revert AdapterDuplicated();
      unchecked {
        ++i;
      }
    }
  }

  function _keyFrom(uint256 positionId, address token) internal pure returns (PositionIdTokenKey) {
    return PositionIdTokenKey.wrap(keccak256(abi.encode(positionId, token)));
  }
}

// solhint-enable no-empty-blocks
