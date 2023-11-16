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
  TotalYieldDataKey, TotalYieldDataForToken, TotalYieldDataForTokenLibrary
} from "./types/TotalYieldDataForToken.sol";
import {
  PositionYieldDataKey,
  PositionYieldDataForToken,
  PositionYieldDataForTokenLibrary
} from "./types/PositionYieldDataForToken.sol";
import { RewardLossEventKey, RewardLossEvent, RewardLossEventLibrary } from "./types/RewardLossEvent.sol";
import { CalculatedDataForToken, CalculatedDataLibrary } from "./types/CalculatedDataForToken.sol";
import { UpdateAction } from "./types/UpdateAction.sol";
// solhint-disable no-unused-import

// TODO: remove once functions are implemented
// slither-disable-start locked-ether
// slither-disable-start unimplemented-functions
// solhint-disable no-empty-blocks
contract EarnVault is AccessControlDefaultAdminRules, NFTPermissions, Pausable, ReentrancyGuard, IEarnVault {
  using Token for address;
  using PositionDataLibrary for mapping(uint256 => PositionData);
  using TotalYieldDataForTokenLibrary for mapping(TotalYieldDataKey => TotalYieldDataForToken);
  using PositionYieldDataForTokenLibrary for mapping(PositionYieldDataKey => PositionYieldDataForToken);
  using RewardLossEventLibrary for mapping(RewardLossEventKey => RewardLossEvent);
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
  mapping(TotalYieldDataKey key => TotalYieldDataForToken yieldData) internal _totalYieldData;
  // Stores relevant yield data for a given position in the strategy, in the context of a specific reward token
  mapping(PositionYieldDataKey key => PositionYieldDataForToken yieldData) internal _positionYieldData;
  // Stores historical loss events for reward tokens
  mapping(RewardLossEventKey key => RewardLossEvent lossEvent) internal _lossEvents;
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
    returns (address[] memory, uint256[] memory, IEarnStrategy.WithdrawalType[] memory, bytes memory)
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
    uint256 yieldAccumulator;
    (yieldAccumulator, calculatedData.lastRecordedBalance, calculatedData.totalLossEvents) =
      _totalYieldData.read(strategyId, token);

    if (
      totalBalance < calculatedData.lastRecordedBalance || calculatedData.totalLossEvents == YieldMath.MAX_LOSS_EVENTS
    ) {
      // If we have just produced a loss, or we already reached the max allowed losses, then avoid updating the
      // accumulator
      calculatedData.newAccumulator = yieldAccumulator;
    } else {
      calculatedData.newAccumulator = YieldMath.calculateAccum({
        lastRecordedBalance: calculatedData.lastRecordedBalance,
        currentBalance: totalBalance,
        previousAccum: yieldAccumulator,
        totalShares: totalShares
      });
    }

    calculatedData.positionBalance = YieldMath.calculateBalance({
      positionId: positionId,
      strategyId: strategyId,
      token: token,
      totalBalance: totalBalance,
      totalLossEvents: calculatedData.totalLossEvents,
      lastRecordedBalance: calculatedData.lastRecordedBalance,
      newAccumulator: calculatedData.newAccumulator,
      positionShares: positionShares,
      positionRegistry: _positionYieldData,
      lossEventRegistry: _lossEvents
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
        totalBalanceBeforeUpdate: balancesBeforeUpdate[i],
        withdrawn: updateAmounts[i],
        totalBalanceAfterUpdate: balancesAfterUpdate[i]
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
    uint256 totalBalanceBeforeUpdate,
    uint256 withdrawn,
    uint256 totalBalanceAfterUpdate
  )
    internal
  {
    if (
      calculatedData.totalLossEvents < YieldMath.MAX_LOSS_EVENTS
        && totalBalanceBeforeUpdate < calculatedData.lastRecordedBalance
    ) {
      // There was a new loss event, let's register it
      _lossEvents.registerNew({
        strategyId: strategyId,
        token: token,
        eventIndex: calculatedData.totalLossEvents++,
        // Since there was a loss event, we know that the accumulator wasn't updated. So we can use the "new" accum
        // value
        accumPriorToLoss: calculatedData.newAccumulator,
        totalBalanceBeforeLoss: calculatedData.lastRecordedBalance,
        totalBalanceAfterLoss: totalBalanceBeforeUpdate
      });
    }
    _totalYieldData.update({
      strategyId: strategyId,
      token: token,
      newTotalBalance: totalBalanceAfterUpdate,
      newAccumulator: calculatedData.newAccumulator,
      newTotalLossEvents: calculatedData.totalLossEvents
    });
    _positionYieldData.update({
      positionId: positionId,
      token: token,
      newAccumulator: calculatedData.newAccumulator,
      newPositionBalance: calculatedData.positionBalance - withdrawn,
      newProccessedLossEvents: calculatedData.totalLossEvents,
      newShares: positionShares
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
// solhint-enable no-empty-blocks
// slither-disable-end unimplemented-functions
// slither-disable-end locked-ether
