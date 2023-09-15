// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
// solhint-disable-next-line no-unused-import
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NFTPermissions, ERC721 } from "@mean-finance/nft-permissions/NFTPermissions.sol";

import { IEarnVault, IEarnStrategyRegistry, IEarnFeeManager } from "../interfaces/IEarnVault.sol";
import { IEarnStrategy } from "../interfaces/IEarnStrategy.sol";

import { Token } from "../libraries/Token.sol";
import { YieldMath } from "./libraries/YieldMath.sol";
import { SharesMath } from "./libraries/SharesMath.sol";
import { StorageHelper } from "./libraries/StorageHelper.sol";
import { DataCalculations } from "./libraries/DataCalculations.sol";

import { StrategyId } from "../types/StrategyId.sol";
import { SpecialWithdrawalCode } from "../types/SpecialWithdrawals.sol";
// solhint-disable no-unused-import
import { PositionData, TotalYieldDataForToken } from "./types/Storage.sol";
import { KeyEncoding, StrategyAndToken } from "./types/KeyEncoding.sol";
import { CalculatedDataForToken, UpdateAction } from "./types/Memory.sol";
// solhint-disable no-unused-import

// TODO: remove once functions are implemented
// slither-disable-start locked-ether
// slither-disable-start unimplemented-functions
// solhint-disable no-empty-blocks
contract EarnVault is AccessControlDefaultAdminRules, NFTPermissions, Pausable, ReentrancyGuard, IEarnVault {
  using SafeCast for uint256;
  using Token for address;
  using StorageHelper for mapping(StrategyAndToken => TotalYieldDataForToken);
  using DataCalculations for CalculatedDataForToken[];

  /// @inheritdoc IEarnVault
  bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
  /// @inheritdoc IEarnVault
  bytes32 public constant WITHDRAW_FEES_ROLE = keccak256("WITHDRAW_FEES_ROLE");
  /// @inheritdoc IEarnVault
  Permission public constant INCREASE_PERMISSION = Permission.wrap(0);
  /// @inheritdoc IEarnVault
  Permission public constant WITHDRAW_PERMISSION = Permission.wrap(1);
  // slither-disable-start naming-convention
  // solhint-disable var-name-mixedcase
  /// @inheritdoc IEarnVault
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;
  /// @inheritdoc IEarnVault
  IEarnFeeManager public immutable FEE_MANAGER;
  // solhint-enable var-name-mixedcase

  // Stores total amount of shares per strategy
  mapping(StrategyId strategyId => uint256 totalShares) internal _totalSharesInStrategy;
  // Stores shares and strategy id per position
  mapping(uint256 positionId => PositionData positionData) internal _positions;
  // Store relevant yield data for all positions in the strategy, in the context of a specific token
  mapping(StrategyAndToken strategyAndToken => TotalYieldDataForToken yieldData) internal _totalYieldData;
  // slither-disable-end naming-convention

  constructor(
    IEarnStrategyRegistry strategyRegistry,
    IEarnFeeManager feeManager,
    address superAdmin,
    address[] memory initialPauseAdmins,
    address[] memory initialWithdrawFeeAdmins
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
    NFTPermissions("Balmy Earn NFT Position", "EARN", "1.0")
  {
    STRATEGY_REGISTRY = strategyRegistry;
    FEE_MANAGER = feeManager;

    _assignRoles(PAUSE_ROLE, initialPauseAdmins);
    _assignRoles(WITHDRAW_FEES_ROLE, initialWithdrawFeeAdmins);
  }

  /// @dev Needed to receive native tokens
  receive() external payable { }

  /// @inheritdoc IEarnVault
  function positionsStrategy(uint256 positionId) external view returns (StrategyId) {
    return _positions[positionId].strategyId;
  }

  /// @inheritdoc IEarnVault
  function position(uint256 positionId)
    external
    view
    returns (address[] memory, IEarnStrategy.WithdrawalType[] memory, uint256[] memory)
  {
    (CalculatedDataForToken[] memory calculatedData,, IEarnStrategy strategy,,, address[] memory tokens) =
      _loadCurrentState(positionId);
    uint256[] memory balances = calculatedData.calculateBalances();
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = strategy.supportedWithdrawals();
    return (tokens, withdrawalTypes, balances);
  }

  /// @inheritdoc IEarnVault
  function generatedFees(StrategyId[] calldata strategies) external view returns (FundsInStrategy[] memory generated) { }

  /// @inheritdoc IEarnVault
  function paused() public view override(IEarnVault, Pausable) returns (bool) {
    return super.paused();
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlDefaultAdminRules, ERC721, IERC165)
    returns (bool)
  {
    return AccessControlDefaultAdminRules.supportsInterface(interfaceId) || ERC721.supportsInterface(interfaceId)
      || interfaceId == type(IEarnVault).interfaceId;
  }

  /// @inheritdoc IEarnVault
  function createPosition(
    StrategyId strategyId,
    address depositToken,
    uint256 depositAmount,
    address owner,
    PermissionSet[] calldata permissions,
    bytes calldata misc
  )
    external
    payable
    nonReentrant
    whenNotPaused
    returns (uint256 positionId, uint256 assetsDeposited)
  {
    (
      CalculatedDataForToken[] memory calculatedData,
      IEarnStrategy strategy,
      uint256 totalShares,
      address[] memory tokens
    ) = _loadCurrentState({ strategyId: strategyId, positionShares: 0 });

    positionId = _mintWithPermissions(owner, permissions);

    assetsDeposited = _increasePosition({
      positionId: positionId,
      strategyId: strategyId,
      strategy: strategy,
      totalShares: totalShares,
      positionShares: 0,
      tokens: tokens,
      calculatedData: calculatedData,
      depositToken: depositToken,
      depositAmount: depositAmount
    });

    emit PositionCreated(positionId, strategyId, assetsDeposited, owner, permissions, misc);
  }

  // TODO: Add nonReentrant & whenNotPaused
  /// @inheritdoc IEarnVault
  function increasePosition(
    uint256 positionId,
    address depositToken,
    uint256 depositAmount
  )
    external
    payable
    returns (uint256 assetsDeposited)
  { }

  // TODO: Add nonReentrant
  /// @inheritdoc IEarnVault
  function withdraw(
    uint256 positionId,
    address[] calldata tokensToWithdraw,
    uint256[] calldata intendedWithdraw,
    address recipient
  )
    external
    payable
    returns (uint256[] memory, IEarnStrategy.WithdrawalType[] memory)
  { }

  // TODO: Add nonReentrant
  /// @inheritdoc IEarnVault
  function specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    bytes calldata withdrawalData,
    address recipient
  )
    external
    payable
    returns (address[] memory, uint256[] memory, IEarnStrategy.WithdrawalType[] memory, bytes memory)
  { }

  // TODO: Add nonReentrant
  /// @inheritdoc IEarnVault
  function withdrawFees(
    StrategyId[] calldata strategies,
    address recipient
  )
    external
    payable
    returns (WithdrawnFromStrategy[] memory withdrawn)
  { }

  /// @inheritdoc IEarnVault
  function pause() external payable onlyRole(PAUSE_ROLE) {
    _pause();
  }

  /// @inheritdoc IEarnVault
  function unpause() external payable onlyRole(PAUSE_ROLE) {
    _unpause();
  }

  function _loadCurrentState(uint256 positionId)
    internal
    view
    returns (
      CalculatedDataForToken[] memory calculatedData,
      StrategyId strategyId,
      IEarnStrategy strategy,
      uint256 totalShares,
      uint256 positionShares,
      address[] memory tokens
    )
  {
    PositionData memory positionData = _positions[positionId];
    positionShares = positionData.shares;
    strategyId = positionData.strategyId;
    (calculatedData, strategy, totalShares, tokens) = _loadCurrentState(strategyId, positionShares);
  }

  function _loadCurrentState(
    StrategyId strategyId,
    uint256 positionShares
  )
    internal
    view
    returns (
      CalculatedDataForToken[] memory calculatedData,
      IEarnStrategy strategy,
      uint256 totalShares,
      address[] memory tokens
    )
  {
    totalShares = _totalSharesInStrategy[strategyId];
    strategy = STRATEGY_REGISTRY.getStrategy(strategyId);
    uint256 feeBps = FEE_MANAGER.getPerformanceFeeForStrategy(strategyId);
    (calculatedData, tokens) = _calculateAllData({
      strategyId: strategyId,
      strategy: strategy,
      totalShares: totalShares,
      positionShares: positionShares,
      feeBps: feeBps
    });
  }

  function _calculateAllData(
    StrategyId strategyId,
    IEarnStrategy strategy,
    uint256 totalShares,
    uint256 positionShares,
    uint256 feeBps
  )
    internal
    view
    returns (CalculatedDataForToken[] memory calculatedData, address[] memory tokens)
  {
    uint256[] memory totalBalances;
    (tokens, totalBalances) = strategy.totalBalances();

    calculatedData = new CalculatedDataForToken[](tokens.length);
    for (uint256 i = 0; i < tokens.length;) {
      calculatedData[i] = _calculateAllDataForToken({
        strategyId: strategyId,
        totalShares: totalShares,
        positionShares: positionShares,
        feeBps: feeBps,
        token: tokens[i],
        totalBalance: totalBalances[i],
        isAsset: i == 0
      });
      unchecked {
        ++i;
      }
    }
  }

  function _calculateAllDataForToken(
    StrategyId strategyId,
    uint256 totalShares,
    uint256 positionShares,
    uint256 feeBps,
    address token,
    uint256 totalBalance,
    bool isAsset
  )
    internal
    view
    returns (CalculatedDataForToken memory calculatedData)
  {
    calculatedData.totalBalance = totalBalance;
    calculatedData.totalYieldData = _totalYieldData.read(strategyId, token);

    int256 yielded;
    (yielded, calculatedData.earnedFees) = YieldMath.calculateYielded({
      currentBalance: totalBalance,
      lastRecordedBalance: calculatedData.totalYieldData.lastRecordedBalance,
      lastRecordedEarnedFees: calculatedData.earnedFees,
      feeBps: feeBps
    });

    if (isAsset) {
      // If we are calculating for the asset, then simply divide available balance based on shares
      if (positionShares > 0) {
        calculatedData.positionBalance = SharesMath.convertToAssets({
          shares: positionShares,
          totalAssets: totalBalance - calculatedData.earnedFees,
          totalShares: totalShares,
          rounding: Math.Rounding.Floor
        }).toInt256();
      }
    } else {
      // TODO
    }
  }

  // slither-disable-next-line reentrancy-benign
  function _increasePosition(
    uint256 positionId,
    StrategyId strategyId,
    IEarnStrategy strategy,
    uint256 totalShares,
    uint256 positionShares,
    address[] memory tokens,
    CalculatedDataForToken[] memory calculatedData,
    address depositToken,
    uint256 depositAmount
  )
    internal
    returns (uint256 assetsDeposited)
  {
    if (depositAmount == type(uint256).max) {
      depositToken.assertNonNative(); // This operation is only supported with ERC20s
      depositAmount = depositToken.balanceOf(msg.sender);
    }
    if (depositAmount == 0) {
      revert ZeroAmountDeposit();
    }

    depositToken.transferIfNativeOrTransferFromIfERC20({ recipient: address(strategy), amount: depositAmount });
    assetsDeposited = strategy.deposited(depositToken, depositAmount);

    uint256[] memory deposits = new uint256[](calculatedData.length);
    deposits[0] = assetsDeposited;

    _updateAccounting({
      positionId: positionId,
      strategyId: strategyId,
      totalShares: totalShares,
      positionShares: positionShares,
      tokens: tokens,
      calculatedData: calculatedData,
      amounts: deposits,
      action: UpdateAction.DEPOSIT
    });
  }

  function _updateAccounting(
    uint256 positionId,
    StrategyId strategyId,
    uint256 totalShares,
    uint256 positionShares,
    address[] memory tokens,
    CalculatedDataForToken[] memory calculatedData,
    uint256[] memory amounts,
    UpdateAction action
  )
    internal
  {
    uint256 shares = SharesMath.convertToShares({
      assets: amounts[0],
      totalAssets: calculatedData[0].totalBalance,
      totalShares: totalShares,
      rounding: action == UpdateAction.DEPOSIT ? Math.Rounding.Floor : Math.Rounding.Ceil
    });
    (uint256 newTotalShares, uint256 newPositionShares) = action == UpdateAction.DEPOSIT
      ? (totalShares + shares, positionShares + shares)
      : (totalShares - shares, positionShares - shares);

    if (shares != 0) {
      _totalSharesInStrategy[strategyId] = newTotalShares;
      _positions[positionId] = PositionData({ shares: newPositionShares.toUint160(), strategyId: strategyId });
    }

    for (uint256 i = 0; i < calculatedData.length;) {
      _updateAccountingForToken({
        strategyId: strategyId,
        token: tokens[i],
        calculatedData: calculatedData[i],
        amount: amounts[i],
        action: action,
        isAsset: i == 0
      });
      unchecked {
        ++i;
      }
    }
  }

  function _updateAccountingForToken(
    StrategyId strategyId,
    address token,
    CalculatedDataForToken memory calculatedData,
    uint256 amount,
    UpdateAction action,
    bool isAsset
  )
    internal
  {
    // TODO: Remove when withdraws are supported
    // slither-disable-next-line uninitialized-local
    uint256 newTotalBalance;
    int256 newPositionBalance;

    int256 signedAmount = amount.toInt256();
    if (action == UpdateAction.DEPOSIT) {
      newTotalBalance = calculatedData.totalBalance + amount;
      newPositionBalance = calculatedData.positionBalance + signedAmount;
    } else {
      // TODO: support withdrawals
    }

    _totalYieldData.update({
      strategyId: strategyId,
      token: token,
      newTotalBalance: newTotalBalance,
      newAccumulator: calculatedData.newAccumulator,
      newEarnedFees: calculatedData.earnedFees,
      previousValues: calculatedData.totalYieldData
    });

    if (!isAsset) {
      // TODO
    }
  }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length;) {
      _grantRole(role, accounts[i]);
      unchecked {
        ++i;
      }
    }
  }
}
// solhint-enable no-empty-blocks
// slither-disable-end unimplemented-functions
// slither-disable-end locked-ether
