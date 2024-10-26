// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  IEarnVault,
  EarnVault,
  SpecialWithdrawalCode,
  IEarnStrategy,
  IEarnStrategyRegistry,
  StrategyId,
  IEarnNFTDescriptor
} from "./EarnVault.sol";

import "@forta/firewall/InternalFirewall.sol";
import "@forta/firewall/interfaces/Checkpoint.sol";

contract FirewalledEarnVault is EarnVault, InternalFirewall {
  constructor(
    IEarnStrategyRegistry strategyRegistry,
    address superAdmin,
    address[] memory initialPauseAdmins,
    IEarnNFTDescriptor nftDescriptor,
    ISecurityValidator validator,
    ICheckpointHook checkpointHook,
    bytes32 attesterControllerId,
    IFirewallAccess firewallAccess
  )
    EarnVault(strategyRegistry, superAdmin, initialPauseAdmins, nftDescriptor)
    InternalFirewall(validator, checkpointHook, attesterControllerId, firewallAccess)
  {
    Checkpoint memory checkpoint;
    checkpoint.refStart = 4;
    /// exclude selector
    checkpoint.refEnd = 65_535;
    /// max uint16 - defaults to call data size if that is smaller
    checkpoint.activation = Activation.AlwaysActive;
    setCheckpoint(EarnVault.createPosition.selector, checkpoint);
    setCheckpoint(EarnVault.increasePosition.selector, checkpoint);
    setCheckpoint(EarnVault.withdraw.selector, checkpoint);
    setCheckpoint(EarnVault.specialWithdraw.selector, checkpoint);
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
    returns (uint256[] memory withdrawn, IEarnStrategy.WithdrawalType[] memory withdrawalTypes)
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
}
