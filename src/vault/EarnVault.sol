// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
// solhint-disable-next-line no-unused-import
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NFTPermissions, ERC721 } from "@balmy/nft-permissions/NFTPermissions.sol";

import { IEarnVault, IEarnStrategyRegistry } from "../interfaces/IEarnVault.sol";
import { IEarnStrategy } from "../interfaces/IEarnStrategy.sol";
import { IEarnNFTDescriptor } from "../interfaces/IEarnNFTDescriptor.sol";

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

contract EarnVault is AccessControl, NFTPermissions, Pausable, ReentrancyGuard, IEarnVault {
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
  /// @inheritdoc IEarnVault
  // solhint-disable-next-line var-name-mixedcase
  IEarnNFTDescriptor public immutable NFT_DESCRIPTOR;

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
    address[] memory initialPauseAdmins,
    IEarnNFTDescriptor nftDescriptor
  )
    NFTPermissions("Balmy Earn NFT Position", "EARN", "1.0")
  {
    STRATEGY_REGISTRY = strategyRegistry;
    NFT_DESCRIPTOR = nftDescriptor;
    _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
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
  function position(uint256 positionId) external view returns (address[] memory, uint256[] memory, IEarnStrategy) {
    (
      uint256 positionAssetBalance,
      CalculatedDataForToken[] memory calculatedData,
      ,
      IEarnStrategy strategy,
      ,
      ,
      address[] memory tokens,
    ) = _loadCurrentState(positionId);
    uint256[] memory balances = calculatedData.extractBalances(positionAssetBalance);
    return (tokens, balances, strategy);
  }

  /// @inheritdoc IEarnVault
  function paused() public view override(IEarnVault, Pausable) returns (bool) {
    return super.paused();
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public view override(AccessControl, ERC721, IERC165) returns (bool) {
    return AccessControl.supportsInterface(interfaceId) || ERC721.supportsInterface(interfaceId)
      || interfaceId == type(IEarnVault).interfaceId;
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
    external
    payable
    nonReentrant
    whenNotPaused
    returns (uint256 positionId, uint256 assetsDeposited)
  {
    (
      ,
      CalculatedDataForToken[] memory calculatedData,
      IEarnStrategy strategy,
      uint256 totalShares,
      address[] memory tokens,
      uint256[] memory totalBalances
    ) = _loadCurrentState({ positionId: YieldMath.POSITION_BEING_CREATED, strategyId: strategyId, positionShares: 0 });

    strategy.validatePositionCreation(msg.sender, strategyValidationData);

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
      ,
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
      uint256 positionAssetBalance,
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

    withdrawn =
      _calculateWithdrawnAmount(positionAssetBalance, calculatedData, tokens, tokensToWithdraw, intendedWithdraw);

    // slither-disable-next-line reentrancy-no-eth
    withdrawalTypes = strategy.withdraw({
      positionId: positionId,
      tokens: tokensToWithdraw,
      toWithdraw: withdrawn,
      recipient: recipient
    });

    // slither-disable-next-line unused-return
    (, uint256[] memory balancesAfterUpdate) = strategy.totalBalances();

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
      ,
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
      uint256 positionAssetBalance,
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
    (positionAssetBalance, calculatedData, strategy, totalShares, tokens, totalBalances) =
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
      uint256 positionAssetBalance,
      CalculatedDataForToken[] memory calculatedData,
      IEarnStrategy strategy,
      uint256 totalShares,
      address[] memory tokens,
      uint256[] memory totalBalances
    )
  {
    totalShares = _totalSharesInStrategy[strategyId];
    strategy = STRATEGY_REGISTRY.getStrategy(strategyId);
    (positionAssetBalance, calculatedData, tokens, totalBalances) = _calculateAllData({
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
    returns (
      uint256 positionAssetBalance,
      CalculatedDataForToken[] memory calculatedData,
      address[] memory tokens,
      uint256[] memory totalBalances
    )
  {
    (tokens, totalBalances) = strategy.totalBalances();

    positionAssetBalance = SharesMath.convertToAssets({
      shares: positionShares,
      totalAssets: totalBalances[0],
      totalShares: totalShares,
      rounding: Math.Rounding.Floor
    });
    calculatedData = new CalculatedDataForToken[](tokens.length - 1);
    for (uint256 i = 1; i < tokens.length; ++i) {
      calculatedData[i - 1] = _calculateAllDataForRewardToken({
        positionId: positionId,
        strategyId: strategyId,
        totalShares: totalShares,
        positionShares: positionShares,
        token: tokens[i],
        totalBalance: totalBalances[i]
      });
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
    (uint256 strategyYieldAccum, uint256 lastRecordedBalance, bool strategyHadLoss) =
      _strategyYieldData.read(strategyId, token);

    (uint256 strategyLossAccum, uint256 strategyCompleteLossEvents) =
      strategyHadLoss ? _strategyYieldLossData.read(strategyId, token) : (YieldMath.LOSS_ACCUM_INITIAL, 0);

    (
      calculatedData.newStrategyYieldAccum,
      calculatedData.newStrategyLossAccum,
      calculatedData.newStrategyCompleteLossEvents
    ) = YieldMath.calculateAccum({
      lastRecordedBalance: lastRecordedBalance,
      currentBalance: totalBalance,
      previousStrategyYieldAccum: strategyYieldAccum,
      totalShares: totalShares,
      previousStrategyLossAccum: strategyLossAccum,
      previousStrategyCompleteLossEvents: strategyCompleteLossEvents
    });

    calculatedData.positionBalance = YieldMath.calculateBalance({
      positionId: positionId,
      token: token,
      totalBalance: totalBalance,
      newStrategyLossAccum: calculatedData.newStrategyLossAccum,
      newStrategyCompleteLossEvents: calculatedData.newStrategyCompleteLossEvents,
      lastRecordedBalance: lastRecordedBalance,
      newStrategyYieldAccum: calculatedData.newStrategyYieldAccum,
      positionShares: positionShares,
      positionRegistry: _positionYieldData,
      positionLossRegistry: _positionYieldLossData
    });
  }

  function _calculateWithdrawnAmount(
    uint256 positionAssetBalance,
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
    for (uint256 i = 0; i < tokensToWithdraw.length; ++i) {
      if (tokensToWithdraw[i] != tokens[i]) {
        revert InvalidWithdrawInput();
      }
      uint256 balance = i == 0 ? positionAssetBalance : calculatedData[i - 1].positionBalance;
      if (intendedWithdraw[i] != type(uint256).max && balance < intendedWithdraw[i]) {
        revert InsufficientFunds();
      }
      withdrawn[i] = Math.min(balance, intendedWithdraw[i]);
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

    uint256[] memory deposits = new uint256[](tokens.length);
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

    for (uint256 i = 1; i <= calculatedData.length; ++i) {
      _updateAccountingForRewardToken({
        positionId: positionId,
        strategyId: strategyId,
        positionShares: newPositionShares,
        token: tokens[i],
        calculatedData: calculatedData[i - 1],
        withdrawn: updateAmounts[i],
        newStrategyBalance: balancesAfterUpdate[i]
      });
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
        revert ZeroSharesDeposit();
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
    bool strategyHadLoss = false;
    if (
      calculatedData.newStrategyLossAccum != YieldMath.LOSS_ACCUM_INITIAL
        || calculatedData.newStrategyCompleteLossEvents != 0
    ) {
      _strategyYieldLossData.update({
        strategyId: strategyId,
        token: token,
        newStrategyLossAccum: calculatedData.newStrategyLossAccum,
        newStrategyCompleteLossEvents: calculatedData.newStrategyCompleteLossEvents
      });
      _positionYieldLossData.update({
        positionId: positionId,
        token: token,
        newPositionLossAccum: calculatedData.newStrategyLossAccum,
        newPositionCompleteLossEvents: calculatedData.newStrategyCompleteLossEvents
      });
      strategyHadLoss = true;
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

  /// @inheritdoc ERC721
  // slither-disable-next-line naming-convention
  function tokenURI(uint256 positionId) public view override returns (string memory) {
    return NFT_DESCRIPTOR.tokenURI(this, positionId);
  }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }
}
