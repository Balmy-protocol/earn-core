// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { DelayedWithdrawalAdapterDead } from "./DelayedWithdrawalAdapterDead.sol";

contract DelayedWithdrawalAdapterMock is DelayedWithdrawalAdapterDead {
  mapping(uint256 positionId => mapping(address token => uint256 withdrawn)) private _withdrawnFunds;

  function estimatedPendingFunds(uint256 positionId, address) external view virtual override returns (uint256) {
    return positionId;
  }

  function withdrawableFunds(uint256 positionId, address token) public view virtual override returns (uint256) {
    return positionId - _withdrawnFunds[positionId][token];
  }

  function withdraw(
    uint256 positionId,
    address token,
    address
  )
    external
    virtual
    override
    returns (uint256 withdrawn, uint256 stillPending)
  {
    _withdrawnFunds[positionId][token] += withdrawn = withdrawableFunds(positionId, token);
    stillPending = 0;
  }
}
