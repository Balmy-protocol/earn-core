// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { DelayedWithdrawalAdapterDead } from "./DelayedWithdrawalAdapterDead.sol";

contract DelayedWithdrawalAdapterMock is DelayedWithdrawalAdapterDead {
  function estimatedPendingFunds(uint256 positionId, address) external view virtual override returns (uint256) {
    return positionId;
  }
}
