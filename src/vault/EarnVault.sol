// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
// solhint-disable-next-line no-unused-import
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NFTPermissions, ERC721 } from "@mean-finance/nft-permissions/NFTPermissions.sol";

import { IEarnVault, IEarnStrategyRegistry } from "../interfaces/IEarnVault.sol";
import { IEarnStrategy } from "../interfaces/IEarnStrategy.sol";

import { Token } from "../libraries/Token.sol";
import { SharesMath } from "./libraries/SharesMath.sol";
import { YieldMath } from "./libraries/YieldMath.sol";
import { StrategyId } from "../types/StrategyId.sol";
import { SpecialWithdrawalCode } from "../types/SpecialWithdrawals.sol";
// solhint-disable no-unused-import
import { PositionData, PositionDataLibrary } from "./types/PositionData.sol";
import {
  StrategyYieldDataKey,
  StrategyYieldDataForToken,
  StrategyYieldDataForTokenLibrary
} from "./types/StrategyYieldDataForToken.sol";
import {
  StrategyYieldLossDataKey,
  StrategyYieldLossDataForToken,
  StrategyYieldLossDataForTokenLibrary
} from "./types/StrategyYieldLossDataForToken.sol";
import {
  PositionYieldDataKey,
  PositionYieldDataForToken,
  PositionYieldDataForTokenLibrary
} from "./types/PositionYieldDataForToken.sol";

import {
  PositionYieldLossDataKey,
  PositionYieldLossDataForTokenLibrary,
  PositionYieldLossDataForToken
} from "./types/PositionYieldLossDataForToken.sol";
import { CalculatedDataForToken, CalculatedDataLibrary } from "./types/CalculatedDataForToken.sol";
import { UpdateAction } from "./types/UpdateAction.sol";

// solhint-enable no-unused-import

contract EarnVault is AccessControlDefaultAdminRules, NFTPermissions, Pausable, ReentrancyGuard, IEarnVault {
  using Math for uint256;
  using Token for address;
  using PositionDataLibrary for mapping(uint256 => PositionData);
  using StrategyYieldDataForTokenLibrary for mapping(StrategyYieldDataKey => StrategyYieldDataForToken);
  using StrategyYieldLossDataForTokenLibrary for mapping(StrategyYieldLossDataKey => StrategyYieldLossDataForToken);
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);
  using PositionYieldLossDataForTokenLibrary for mapping(PositionYieldLossDataKey => PositionYieldLossDataForToken);
  using CalculatedDataLibrary for CalculatedDataForToken[];

  /// @inheritdoc IEarnVault
  bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
  /// @inheritdoc IEarnVault
  Permission public constant INCREASE_PERMISSION = Permission.wrap(0);
  /// @inheritdoc IEarnVault
  Permission public constant WITHDRAW_PERMISSION = Permission.wrap(1);
  // slither-disable-start naming-convention
  /// @inheritdoc IEarnVault
  // solhint-disable-next-line var-name-mixedcase
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;

  // Stores total amount of shares per strategy
  mapping(StrategyId strategyId => uint256 totalShares) internal _totalSharesInStrategy;
  // Stores shares and strategy id per position
  mapping(uint256 positionId => PositionData positionData) internal _positions;
  // Stores relevant yield data for all positions in the strategy, in the context of a specific reward token
  mapping(StrategyYieldDataKey key => StrategyYieldDataForToken yieldData) internal _strategyYieldData;
  // Stores relevant data for all positions in the strategy, in the context of a specific reward token loss
  mapping(StrategyYieldLossDataKey key => StrategyYieldLossDataForToken strategyLossAccum) internal
    _strategyYieldLossData;
  // Stores relevant yield data for a given position in the strategy, in the context of a specific reward token
  mapping(PositionYieldDataKey key => PositionYieldDataForToken yieldData) internal _positionYieldData;
  // Stores relevant data for a given position in the strategy, in the context of a specific reward token loss
  mapping(PositionYieldLossDataKey key => PositionYieldLossDataForToken positionLossAccum) internal
    _positionYieldLossData;
  // slither-disable-end naming-convention

  constructor(
    IEarnStrategyRegistry strategyRegistry,
    address superAdmin,
    address[] memory initialPauseAdmins
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
    NFTPermissions("Balmy Earn NFT Position", "EARN", "1.0")
  {
    STRATEGY_REGISTRY = strategyRegistry;

    _assignRoles(PAUSE_ROLE, initialPauseAdmins);
  }

  /// @dev Needed to receive native tokens
  // solhint-disable-next-line no-empty-blocks
  receive() external payable { }

  /// @inheritdoc IEarnVault
  function positionsStrategy(uint256 positionId) external view returns (StrategyId strategyId) {
    // slither-disable-next-line unused-return
    (strategyId,) = _positions.read(positionId);
  }

  /// @inheritdoc IEarnVault
  function position(uint256 positionId)
    external
    view
    returns (address[] memory, IEarnStrategy.WithdrawalType[] memory, uint256[] memory)
  {
    (CalculatedDataForToken[] memory calculatedData,, IEarnStrategy strategy,,, address[] memory tokens,) =
      _loadCurrentState(positionId);
    uint256[] memory balances = calculatedData.extractBalances();
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = strategy.supportedWithdrawals();
    return (tokens, withdrawalTypes, balances);
  }

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
      address[] memory tokens,
      uint256[] memory totalBalances
    ) = _loadCurrentState({ positionId: YieldMath.POSITION_BEING_CREATED, strategyId: strategyId, positionShares: 0 });

    positionId = _mintWithPermissions(owner, permissions);

    assetsDeposited = _increasePosition({
      positionId: positionId,
      strategyId: strategyId,
      strategy: strategy,
      totalShares: totalShares,
      positionShares: 0,
      tokens: tokens,
      totalBalances: totalBalances,
      calculatedData: calculatedData,
      depositToken: depositToken,
      depositAmount: depositAmount
    });

    emit PositionCreated(positionId, strategyId, assetsDeposited, owner, permissions, misc);
  }

  /// @inheritdoc IEarnVault
  function increasePosition(
    uint256 positionId,
    address depositToken,
    uint256 depositAmount
  )
    external
    payable
    onlyWithPermission(positionId, INCREASE_PERMISSION)
    nonReentrant
    whenNotPaused
    returns (uint256 assetsDeposited)
  {
    (
      CalculatedDataForToken[] memory calculatedData,
      StrategyId strategyId,
      IEarnStrategy strategy,
      uint256 totalShares,
      uint256 positionShares,
      address[] memory tokens,
      uint256[] memory totalBalances
    ) = _loadCurrentState(positionId);

    assetsDeposited = _increasePosition({
      positionId: positionId,
      strategyId: strategyId,
      strategy: strategy,
      totalShares: totalShares,
      positionShares: positionShares,
      tokens: tokens,
      totalBalances: totalBalances,
      calculatedData: calculatedData,
      depositToken: depositToken,
      depositAmount: depositAmount
    });

    emit PositionIncreased(positionId, assetsDeposited);
  }

  /// @inheritdoc IEarnVault
  // slither-disable-next-line reentrancy-benign
  function withdraw(
    uint256 positionId,
    address[] calldata tokensToWithdraw,
    uint256[] calldata intendedWithdraw,
    address recipient
  )
    external
    payable
    onlyWithPermission(positionId, WITHDRAW_PERMISSION)
    nonReentrant
    returns (uint256[] memory withdrawn, IEarnStrategy.WithdrawalType[] memory withdrawalTypes)
  {
    (
      CalculatedDataForToken[] memory calculatedData,
      StrategyId strategyId,
      IEarnStrategy strategy,
      uint256 totalShares,
      uint256 positionShares,
      address[] memory tokens,
      uint256[] memory balancesBeforeUpdate
    ) = _loadCurrentState(positionId);

    if (tokensToWithdraw.length != tokens.length || intendedWithdraw.length != tokensToWithdraw.length) {
      revert InvalidWithdrawInput();
    }

    withdrawn = _calculateWithdrawnAmount(calculatedData, tokens, tokensToWithdraw, intendedWithdraw);

    // slither-disable-next-line reentrancy-no-eth
    withdrawalTypes = strategy.withdraw({
      positionId: positionId,
      tokens: tokensToWithdraw,
      toWithdraw: withdrawn,
      recipient: recipient
    });

    // slither-disable-next-line unused-return
    (, uint256[] memory balancesAfterUpdate) = strategy.totalBalances();

    // TODO: balancesAfterUpdate won't be needed if we support unlimited losses
    _updateAccounting({
      positionId: positionId,
      strategyId: strategyId,
      totalShares: totalShares,
      positionShares: positionShares,
      tokens: tokensToWithdraw,
      calculatedData: calculatedData,
      balancesBeforeUpdate: balancesBeforeUpdate,
      updateAmounts: withdrawn,
      balancesAfterUpdate: balancesAfterUpdate,
      action: UpdateAction.WITHDRAW
    });

    emit PositionWithdrawn(positionId, tokensToWithdraw, withdrawn, recipient);
  }

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
    onlyWithPermission(positionId, WITHDRAW_PERMISSION)
    nonReentrant
    returns (
      address[] memory tokens,
      uint256[] memory withdrawn,
      IEarnStrategy.WithdrawalType[] memory withdrawalTypes,
      bytes memory result
    )
  {
    (
      CalculatedDataForToken[] memory calculatedData,
      StrategyId strategyId,
      IEarnStrategy strategy,
      uint256 totalShares,
      uint256 positionShares,
      address[] memory tokens_,
      uint256[] memory balancesBeforeUpdate
    ) = _loadCurrentState(positionId);

    // slither-disable-next-line reentrancy-no-eth
    (withdrawn, withdrawalTypes, result) = strategy.specialWithdraw({
      positionId: positionId,
      withdrawCode: withdrawalCode,
      withdrawData: withdrawalData,
      recipient: recipient
    });
    // slither-disable-next-line unused-return
    (, uint256[] memory balancesAfterUpdate) = strategy.totalBalances();

    // TODO: balancesAfterUpdate won't be needed if we support unlimited losses
    _updateAccounting({
      positionId: positionId,
      strategyId: strategyId,
      totalShares: totalShares,
      positionShares: positionShares,
      tokens: tokens_,
      calculatedData: calculatedData,
      balancesBeforeUpdate: balancesBeforeUpdate,
      updateAmounts: withdrawn,
      balancesAfterUpdate: balancesAfterUpdate,
      action: UpdateAction.WITHDRAW
    });

    tokens = tokens_;

    emit PositionWithdrawn(positionId, tokens, withdrawn, recipient);
  }

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
      address[] memory tokens,
      uint256[] memory totalBalances
    )
  {
    (strategyId, positionShares) = _positions.read(positionId);
    (calculatedData, strategy, totalShares, tokens, totalBalances) =
      _loadCurrentState(positionId, strategyId, positionShares);
  }

  function _loadCurrentState(
    uint256 positionId,
    StrategyId strategyId,
    uint256 positionShares
  )
    internal
    view
    returns (
      CalculatedDataForToken[] memory calculatedData,
      IEarnStrategy strategy,
      uint256 totalShares,
      address[] memory tokens,
      uint256[] memory totalBalances
    )
  {
    totalShares = _totalSharesInStrategy[strategyId];
    strategy = STRATEGY_REGISTRY.getStrategy(strategyId);
    (calculatedData, tokens, totalBalances) = _calculateAllData({
      positionId: positionId,
      strategyId: strategyId,
      strategy: strategy,
      totalShares: totalShares,
      positionShares: positionShares
    });
  }

  function _calculateAllData(
    uint256 positionId,
    StrategyId strategyId,
    IEarnStrategy strategy,
    uint256 totalShares,
    uint256 positionShares
  )
    internal
    view
    returns (CalculatedDataForToken[] memory calculatedData, address[] memory tokens, uint256[] memory totalBalances)
  {
    (tokens, totalBalances) = strategy.totalBalances();

    calculatedData = new CalculatedDataForToken[](tokens.length);
    // TODO: test if it's cheaper to avoid using the entire `CalculatedDataForToken` for the asset
    calculatedData[0].positionBalance = SharesMath.convertToAssets({
      shares: positionShares,
      totalAssets: totalBalances[0],
      totalShares: totalShares,
      rounding: Math.Rounding.Floor
    });
    for (uint256 i = 1; i < tokens.length;) {
      calculatedData[i] = _calculateAllDataForRewardToken({
        positionId: positionId,
        strategyId: strategyId,
        totalShares: totalShares,
        positionShares: positionShares,
        token: tokens[i],
        totalBalance: totalBalances[i]
      });
      unchecked {
        ++i;
      }
    }
  }

  function _calculateAllDataForRewardToken(
    uint256 positionId,
    StrategyId strategyId,
    uint256 totalShares,
    uint256 positionShares,
    address token,
    uint256 totalBalance
  )
    internal
    view
    returns (CalculatedDataForToken memory calculatedData)
  {
    (uint256 strategyYieldAccum, uint256 lastRecordedBalance, uint256 strategyHadLoss) =
      _strategyYieldData.read(strategyId, token);

    (uint256 strategyLossAccum, uint256 strategyCompleteLossEvents) =
      strategyHadLoss == 1 ? _strategyYieldLossData.read(strategyId, token) : (YieldMath.LOSS_ACCUM_INITIAL, 0);

    (
      calculatedData.newStrategyYieldAccum,
      calculatedData.newStrategyLossAccum,
      calculatedData.strategyCompleteLossEvents
    ) = YieldMath.calculateAccum({
      lastRecordedBalance: lastRecordedBalance,
      currentBalance: totalBalance,
      previousStrategyYieldAccum: strategyYieldAccum,
      totalShares: totalShares,
      previousStrategyLossAccum: strategyLossAccum,
      strategyCompleteLossEvents: strategyCompleteLossEvents
    });

    calculatedData.positionBalance = YieldMath.calculateBalance({
      positionId: positionId,
      token: token,
      totalBalance: totalBalance,
      newStrategyLossAccum: calculatedData.newStrategyLossAccum,
      strategyCompleteLossEvents: calculatedData.strategyCompleteLossEvents,
      lastRecordedBalance: lastRecordedBalance,
      newStrategyYieldAccum: calculatedData.newStrategyYieldAccum,
      positionShares: positionShares,
      positionRegistry: _positionYieldData,
      positionLossRegistry: _positionYieldLossData
    });
  }

  function _calculateWithdrawnAmount(
    CalculatedDataForToken[] memory calculatedData,
    address[] memory tokens,
    address[] memory tokensToWithdraw,
    uint256[] memory intendedWithdraw
  )
    internal
    pure
    returns (uint256[] memory withdrawn)
  {
    withdrawn = new uint256[](intendedWithdraw.length);
    for (uint256 i = 0; i < tokensToWithdraw.length;) {
      if (tokensToWithdraw[i] != tokens[i]) {
        revert InvalidWithdrawInput();
      }
      uint256 balance = calculatedData[i].positionBalance;
      if (intendedWithdraw[i] != type(uint256).max && balance < intendedWithdraw[i]) {
        revert InsufficientFunds();
      }
      withdrawn[i] = Math.min(balance, intendedWithdraw[i]);
      unchecked {
        ++i;
      }
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
    uint256[] memory totalBalances,
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
      balancesBeforeUpdate: totalBalances,
      // We use balancesAfterUpdate only for reward tokens, that are not expected to change on a deposit. So we can
      // reuse totalBalances
      balancesAfterUpdate: totalBalances,
      updateAmounts: deposits,
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
    uint256[] memory balancesBeforeUpdate,
    uint256[] memory updateAmounts,
    uint256[] memory balancesAfterUpdate,
    UpdateAction action
  )
    internal
  {
    uint256 newPositionShares = _updateAccountingForAsset({
      positionId: positionId,
      strategyId: strategyId,
      totalShares: totalShares,
      positionShares: positionShares,
      totalAssetsBeforeUpdate: balancesBeforeUpdate[0],
      updateAmount: updateAmounts[0],
      action: action
    });

    for (uint256 i = 1; i < calculatedData.length;) {
      _updateAccountingForRewardToken({
        positionId: positionId,
        strategyId: strategyId,
        positionShares: newPositionShares,
        token: tokens[i],
        calculatedData: calculatedData[i],
        withdrawn: updateAmounts[i],
        newStrategyBalance: balancesAfterUpdate[i]
      });
      unchecked {
        ++i;
      }
    }
  }

  function _updateAccountingForAsset(
    uint256 positionId,
    StrategyId strategyId,
    uint256 totalShares,
    uint256 positionShares,
    uint256 totalAssetsBeforeUpdate,
    uint256 updateAmount,
    UpdateAction action
  )
    internal
    returns (uint256)
  {
    uint256 shares = SharesMath.convertToShares({
      assets: updateAmount,
      totalAssets: totalAssetsBeforeUpdate,
      totalShares: totalShares,
      rounding: action == UpdateAction.DEPOSIT ? Math.Rounding.Floor : Math.Rounding.Ceil
    });
    if (shares == 0) {
      // solhint-disable-next-line no-empty-blocks
      if (action == UpdateAction.DEPOSIT) {
        // If we get to this point, then the user deposited a non-zero amount of assets and is getting zero shares in
        // return. We don't want this to happen, so we'll revert
        // TODO: implement and add test for this scenario
        // revert ZeroSharesDeposit();
      } else {
        return positionShares;
      }
    }
    (uint256 newTotalShares, uint256 newPositionShares) = action == UpdateAction.DEPOSIT
      ? (totalShares + shares, positionShares + shares)
      : (totalShares - shares, positionShares - shares);
    _totalSharesInStrategy[strategyId] = newTotalShares;
    _positions.update({ positionId: positionId, newPositionShares: newPositionShares, strategyId: strategyId });
    return newPositionShares;
  }

  function _updateAccountingForRewardToken(
    uint256 positionId,
    StrategyId strategyId,
    uint256 positionShares,
    address token,
    CalculatedDataForToken memory calculatedData,
    uint256 withdrawn,
    uint256 newStrategyBalance
  )
    internal
  {
    uint8 strategyHadLoss;

    if (
      calculatedData.newStrategyLossAccum != YieldMath.LOSS_ACCUM_INITIAL
        || calculatedData.strategyCompleteLossEvents != 0
    ) {
      _strategyYieldLossData.update({
        strategyId: strategyId,
        token: token,
        newStrategyLossAccum: calculatedData.newStrategyLossAccum,
        newStrategyCompleteLossEvents: calculatedData.strategyCompleteLossEvents
      });
      // TODO: If strategyLossAccum wasn't updated, skip the write in the next line.
      _positionYieldLossData.update({
        positionId: positionId,
        token: token,
        newPositionLossAccum: calculatedData.newStrategyLossAccum,
        newPositionCompleteLossEvents: calculatedData.strategyCompleteLossEvents
      });
      strategyHadLoss = 1;
    }

    _strategyYieldData.update({
      strategyId: strategyId,
      token: token,
      newTotalBalance: newStrategyBalance,
      newStrategyYieldAccum: calculatedData.newStrategyYieldAccum,
      newStrategyHadLoss: strategyHadLoss
    });
    _positionYieldData.update({
      positionId: positionId,
      token: token,
      newPositionYieldAccum: calculatedData.newStrategyYieldAccum,
      newPositionBalance: calculatedData.positionBalance - withdrawn,
      newShares: positionShares,
      newPositionHadLoss: strategyHadLoss
    });
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
