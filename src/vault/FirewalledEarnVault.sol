// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  IEarnVault,
  EarnVault,
  SpecialWithdrawalCode,
  IEarnStrategyRegistry,
  StrategyId,
  IEarnNFTDescriptor
} from "./EarnVault.sol";

import { CheckpointExecutor } from "@forta/firewall/CheckpointExecutor.sol";
import { IExternalFirewall } from "@forta/firewall/interfaces/IExternalFirewall.sol";

contract FirewalledEarnVault is EarnVault, CheckpointExecutor {
  constructor(
    IEarnStrategyRegistry strategyRegistry,
    address superAdmin,
    address[] memory initialPauseAdmins,
    IEarnNFTDescriptor nftDescriptor,
    IExternalFirewall externalFirewall
  )
    EarnVault(strategyRegistry, superAdmin, initialPauseAdmins, nftDescriptor)
  {
    _setExternalFirewall(externalFirewall);
  }

  /// @inheritdoc IEarnVault
  function createPosition(
    StrategyId strategyId,
    address depositToken,
    uint256 depositAmount,
    address owner,
    PermissionSet[] calldata permissions,
    bytes calldata strategyValidationData,
    bytes calldata misc
  )
    public
    payable
    override
    safeExecution
    returns (uint256, uint256)
  {
    return
      super.createPosition(strategyId, depositToken, depositAmount, owner, permissions, strategyValidationData, misc);
  }

  /// @inheritdoc IEarnVault
  function increasePosition(
    uint256 positionId,
    address depositToken,
    uint256 depositAmount
  )
    public
    payable
    override
    safeExecution
    returns (uint256)
  {
    return super.increasePosition(positionId, depositToken, depositAmount);
  }

  /// @inheritdoc IEarnVault
  function withdraw(
    uint256 positionId,
    address[] calldata tokensToWithdraw,
    uint256[] calldata intendedWithdraw,
    address recipient
  )
    public
    payable
    override
    safeExecution
    returns (uint256[] memory withdrawn)
  {
    return super.withdraw(positionId, tokensToWithdraw, intendedWithdraw, recipient);
  }

  /// @inheritdoc IEarnVault
  function specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawalData,
    address recipient
  )
    public
    payable
    override
    safeExecution
    returns (
      address[] memory tokens,
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    return super.specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawalData, recipient);
  }

  modifier safeExecution() {
    _executeCheckpoint(msg.sig, keccak256(msg.data));
    _;
  }
}
