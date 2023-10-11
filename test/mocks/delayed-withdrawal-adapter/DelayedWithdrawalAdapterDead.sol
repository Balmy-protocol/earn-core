// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IEarnVault } from "../../../src/interfaces/IEarnVault.sol";
import { IDelayedWithdrawalManager } from "../../../src/interfaces/IDelayedWithdrawalManager.sol";
import { IDelayedWithdrawalAdapter } from "../../../src/interfaces/IDelayedWithdrawalAdapter.sol";

/// @notice An implementation of IDelayedWithdrawalAdapter that always reverts
contract DelayedWithdrawalAdapterDead is IDelayedWithdrawalAdapter {
  error NotImplemented();

  function vault() external view virtual returns (IEarnVault) {
    revert NotImplemented();
  }

  function manager() external view virtual returns (IDelayedWithdrawalManager) {
    revert NotImplemented();
  }

  function estimatedPendingFunds(uint256, address) external view virtual returns (uint256) {
    revert NotImplemented();
  }

  function withdrawableFunds(uint256, address) external view virtual returns (uint256) {
    revert NotImplemented();
  }

  function initiateDelayedWithdrawal(uint256, address, uint256) external virtual {
    revert NotImplemented();
  }

  function withdraw(uint256, address, address) external virtual returns (uint256, uint256) {
    revert NotImplemented();
  }

  function supportsInterface(bytes4) external pure virtual returns (bool) {
    revert NotImplemented();
  }
}
