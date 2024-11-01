// SPDX-License-Identifier: MIT
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
import { PositionData, PositionDataLibrary } from "./types/PositionData.sol";
import { YieldDataForToken, YieldLossDataForToken, YieldDataForTokenLibrary } from "./types/YieldDataForToken.sol";

import { CalculatedDataForToken, CalculatedDataLibrary } from "./types/CalculatedDataForToken.sol";
import { UpdateAction } from "./types/UpdateAction.sol";

contract EarnVault is AccessControl, NFTPermissions, Pausable, ReentrancyGuard, IEarnVault {
  using Math for uint256;
  using Token for address;
  using PositionDataLibrary for mapping(uint256 => PositionData);
  using YieldDataForTokenLibrary for mapping(bytes32 => YieldDataForToken);
  using YieldDataForTokenLibrary for mapping(bytes32 => YieldLossDataForToken);
  using CalculatedDataLibrary for CalculatedDataForToken[];

  /// @inheritdoc IEarnVault
  bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
  /// @inheritdoc IEarnVault
  // slither-disable-next-line uninitialized-state
  Permission public constant INCREASE_PERMISSION = Permission.wrap(0);
  /// @inheritdoc IEarnVault
  // slither-disable-next-line uninitialized-state
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
  mapping(bytes32 key => YieldDataForToken yieldData) internal _strategyYieldData;
  // Stores relevant data for all positions in the strategy, in the context of a specific reward token loss
  mapping(bytes32 key => YieldLossDataForToken strategyLossAccum) internal _strategyYieldLossData;
  // Stores relevant yield data for a given position in the strategy, in the context of a specific reward token
  mapping(bytes32 key => YieldDataForToken yieldData) internal _positionYieldData;
  // Stores relevant data for a given position in the strategy, in the context of a specific reward token loss
  mapping(bytes32 key => YieldLossDataForToken positionLossAccum) internal _positionYieldLossData;
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
  function positionsStrategy(uint256 positionId) external view returns (StrategyId strategyId, IEarnStrategy strategy) {
    (strategyId,, strategy) = _loadPositionState(positionId);
  }

  /// @inheritdoc IEarnVault
  function position(uint256 positionId)
    external
    view
    returns (address[] memory, uint256[] memory, StrategyId, IEarnStrategy)
  {
    (
      uint256 positionAssetBalance,
      CalculatedDataForToken[] memory calculatedData,
      StrategyId strategyId,
      IEarnStrategy strategy,
      ,
      ,
      address[] memory tokens,
    ) = _loadCurrentState(positionId);
    uint256[] memory balances = calculatedData.extractBalances(positionAssetBalance);
    return (tokens, balances, strategyId, strategy);
  }

  /// @inheritdoc IEarnVault
  function paused() public view override(IEarnVault, Pausable) returns (bool) {
    return super.paused();
  }

  function getStrategyYieldData(StrategyId strategyId)
    external
    view
    returns (
      uint256 totalShares,
      address[] memory tokens,
      YieldDataForToken[] memory yieldData,
      YieldLossDataForToken[] memory yieldLossData
    )
  {
    totalShares = _totalSharesInStrategy[strategyId];
    tokens = STRATEGY_REGISTRY.getStrategy(strategyId).allTokens();
    yieldData = new YieldDataForToken[](tokens.length - 1);
    yieldLossData = new YieldLossDataForToken[](tokens.length - 1);
    for (uint256 i = 1; i < tokens.length; ++i) {
      yieldData[i - 1] = _strategyYieldData.readRaw(strategyId, tokens[i]);
      yieldLossData[i - 1] = _strategyYieldLossData.readRaw(strategyId, tokens[i]);
    }
  }

  function getPositionYieldData(uint256 positionId)
    external
    view
    returns (
      StrategyId strategyId,
      uint256 positionShares,
      address[] memory tokens,
      YieldDataForToken[] memory yieldData,
      YieldLossDataForToken[] memory yieldLossData
    )
  {
    (strategyId, positionShares) = _positions.read(positionId);
    tokens = STRATEGY_REGISTRY.getStrategy(strategyId).allTokens();
    yieldData = new YieldDataForToken[](tokens.length - 1);
    yieldLossData = new YieldLossDataForToken[](tokens.length - 1);
    for (uint256 i = 1; i < tokens.length; ++i) {
      yieldData[i - 1] = _positionYieldData.readRaw(positionId, tokens[i]);
      yieldLossData[i - 1] = _positionYieldLossData.readRaw(positionId, tokens[i]);
    }
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
    public
    payable
    virtual
    nonReentrant
    whenNotPaused
    returns (uint256, uint256)
  {
    IEarnStrategy strategy = STRATEGY_REGISTRY.getStrategy(strategyId);
    (
      ,
      CalculatedDataForToken[] memory calculatedData,
      uint256 totalShares,
      address[] memory tokens,
      uint256[] memory totalBalances
    ) = _loadCurrentState({
      positionId: YieldMath.POSITION_BEING_CREATED,
      strategyId: strategyId,
      strategy: strategy,
      positionShares: 0
    });

    strategy.validatePositionCreation(msg.sender, strategyValidationData);

    uint256 positionId = _mintWithPermissions(owner, permissions);

    (uint256 depositedAmount, uint256 assetsDeposited) = _increasePosition({
      positionId: positionId,
      strategyId: strategyId,
      strategy: strategy,
      totalShares: totalShares,
      positionAssetBalance: 0,
      positionShares: 0,
      tokens: tokens,
      totalBalances: totalBalances,
      calculatedData: calculatedData,
      depositToken: depositToken,
      depositAmount: depositAmount
    });

    emit PositionCreated(
      positionId, owner, strategyId, depositToken, depositedAmount, assetsDeposited, permissions, misc
    );

    return (positionId, assetsDeposited);
  }

  /// @inheritdoc IEarnVault
  function increasePosition(
    uint256 positionId,
    address depositToken,
    uint256 depositAmount
  )
    public
    payable
    virtual
    onlyWithPermission(positionId, INCREASE_PERMISSION)
    nonReentrant
    whenNotPaused
    returns (uint256)
  {
    (
      uint256 positionAssetBalance,
      CalculatedDataForToken[] memory calculatedData,
      StrategyId strategyId,
      IEarnStrategy strategy,
      uint256 totalShares,
      uint256 positionShares,
      address[] memory tokens,
      uint256[] memory totalBalances
    ) = _loadCurrentState(positionId);

    (uint256 depositedAmount, uint256 assetsDeposited) = _increasePosition({
      positionId: positionId,
      strategyId: strategyId,
      strategy: strategy,
      totalShares: totalShares,
      positionShares: positionShares,
      positionAssetBalance: positionAssetBalance,
      tokens: tokens,
      totalBalances: totalBalances,
      calculatedData: calculatedData,
      depositToken: depositToken,
      depositAmount: depositAmount
    });

    emit PositionIncreased(positionId, depositToken, depositedAmount, assetsDeposited);

    return assetsDeposited;
  }

  /// @inheritdoc IEarnVault
  // slither-disable-next-line reentrancy-benign
  function withdraw(
    uint256 positionId,
    address[] calldata tokensToWithdraw,
    uint256[] calldata intendedWithdraw,
    address recipient
  )
    public
    payable
    virtual
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
      positionAssetBalanceBeforeUpdate: positionAssetBalance,
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
    uint256[] calldata toWithdraw,
    bytes calldata withdrawalData,
    address recipient
  )
    public
    payable
    virtual
    onlyWithPermission(positionId, WITHDRAW_PERMISSION)
    nonReentrant
    returns (
      address[] memory tokens,
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    (
      uint256 positionAssetBalance,
      CalculatedDataForToken[] memory calculatedData,
      StrategyId strategyId,
      IEarnStrategy strategy,
      uint256 totalShares,
      uint256 positionShares,
      address[] memory tokens_,
      uint256[] memory balancesBeforeUpdate
    ) = _loadCurrentState(positionId);

    // slither-disable-next-line reentrancy-no-eth
    (balanceChanges, actualWithdrawnTokens, actualWithdrawnAmounts, result) = strategy.specialWithdraw({
      positionId: positionId,
      withdrawalCode: withdrawalCode,
      toWithdraw: toWithdraw,
      withdrawalData: withdrawalData,
      recipient: recipient
    });
    // slither-disable-next-line unused-return
    (, uint256[] memory balancesAfterUpdate) = strategy.totalBalances();

    _updateAccounting({
      positionId: positionId,
      strategyId: strategyId,
      totalShares: totalShares,
      positionShares: positionShares,
      positionAssetBalanceBeforeUpdate: positionAssetBalance,
      tokens: tokens_,
      calculatedData: calculatedData,
      balancesBeforeUpdate: balancesBeforeUpdate,
      updateAmounts: balanceChanges,
      balancesAfterUpdate: balancesAfterUpdate,
      action: UpdateAction.WITHDRAW
    });

    tokens = tokens_;

    emit PositionWithdrawnSpecially(
      positionId, tokens, balanceChanges, actualWithdrawnTokens, actualWithdrawnAmounts, result, recipient
    );
  }

  /// @inheritdoc IEarnVault
  function pause() external payable onlyRole(PAUSE_ROLE) {
    _pause();
  }

  /// @inheritdoc IEarnVault
  function unpause() external payable onlyRole(PAUSE_ROLE) {
    _unpause();
  }

  function _loadPositionState(uint256 positionId)
    internal
    view
    returns (StrategyId strategyId, uint256 positionShares, IEarnStrategy strategy)
  {
    (strategyId, positionShares) = _positions.read(positionId);
    strategy = STRATEGY_REGISTRY.getStrategy(strategyId);
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
    (strategyId, positionShares, strategy) = _loadPositionState(positionId);
    (positionAssetBalance, calculatedData, totalShares, tokens, totalBalances) =
      _loadCurrentState(positionId, strategyId, strategy, positionShares);
  }

  function _loadCurrentState(
    uint256 positionId,
    StrategyId strategyId,
    IEarnStrategy strategy,
    uint256 positionShares
  )
    internal
    view
    returns (
      uint256 positionAssetBalance,
      CalculatedDataForToken[] memory calculatedData,
      uint256 totalShares,
      address[] memory tokens,
      uint256[] memory totalBalances
    )
  {
    totalShares = _totalSharesInStrategy[strategyId];
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
    uint256 positionAssetBalance,
    uint256 positionShares,
    address[] memory tokens,
    CalculatedDataForToken[] memory calculatedData,
    uint256[] memory totalBalances,
    address depositToken,
    uint256 depositAmount
  )
    internal
    returns (uint256 depositedAmount, uint256 assetsDeposited)
  {
    if (depositAmount == type(uint256).max) {
      depositToken.assertNonNative(); // This operation is only supported with ERC20s
      depositedAmount = depositToken.balanceOf(msg.sender);
    } else {
      depositedAmount = depositAmount;
    }
    if (depositedAmount == 0) {
      revert ZeroAmountDeposit();
    }

    depositToken.transferIfNativeOrTransferFromIfERC20({ recipient: address(strategy), amount: depositedAmount });
    assetsDeposited = strategy.deposited(depositToken, depositedAmount);

    uint256[] memory deposits = new uint256[](tokens.length);
    deposits[0] = assetsDeposited;

    _updateAccounting({
      positionId: positionId,
      strategyId: strategyId,
      totalShares: totalShares,
      positionShares: positionShares,
      positionAssetBalanceBeforeUpdate: positionAssetBalance,
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
    uint256 positionAssetBalanceBeforeUpdate,
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
      positionAssetBalanceBeforeUpdate: positionAssetBalanceBeforeUpdate,
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
    uint256 positionAssetBalanceBeforeUpdate,
    uint256 positionShares,
    uint256 totalAssetsBeforeUpdate,
    uint256 updateAmount,
    UpdateAction action
  )
    internal
    returns (uint256)
  {
    // Note: we do this to make sure that if a position withdraws all assets, then it ends up with 0 shares
    uint256 shares = action == UpdateAction.WITHDRAW && positionAssetBalanceBeforeUpdate == updateAmount
      ? positionShares
      : SharesMath.convertToShares({
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
    bool strategyHadLoss = calculatedData.newStrategyLossAccum != YieldMath.LOSS_ACCUM_INITIAL
      || calculatedData.newStrategyCompleteLossEvents != 0;
    if (strategyHadLoss) {
      _strategyYieldLossData.update({
        strategyId: strategyId,
        token: token,
        newLossAccum: calculatedData.newStrategyLossAccum,
        newCompleteLossEvents: calculatedData.newStrategyCompleteLossEvents
      });
      _positionYieldLossData.update({
        positionId: positionId,
        token: token,
        newLossAccum: calculatedData.newStrategyLossAccum,
        newCompleteLossEvents: calculatedData.newStrategyCompleteLossEvents
      });
    }
    _updateYieldData({
      positionId: positionId,
      strategyId: strategyId,
      positionShares: positionShares,
      token: token,
      calculatedData: calculatedData,
      withdrawn: withdrawn,
      newStrategyBalance: newStrategyBalance,
      strategyHadLoss: strategyHadLoss
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

  function _updateYieldData(
    uint256 positionId,
    StrategyId strategyId,
    uint256 positionShares,
    address token,
    CalculatedDataForToken memory calculatedData,
    uint256 withdrawn,
    uint256 newStrategyBalance,
    bool strategyHadLoss
  )
    internal
  {
    _strategyYieldData.update({
      strategyId: strategyId,
      token: token,
      newBalance: newStrategyBalance,
      newYieldAccum: calculatedData.newStrategyYieldAccum,
      newHadLoss: strategyHadLoss
    });
    uint256 newPositionBalance = calculatedData.positionBalance - withdrawn;
    if (positionShares == 0 && newPositionBalance == 0) {
      _positionYieldData.clear({ positionId: positionId, token: token });
    } else {
      _positionYieldData.update({
        positionId: positionId,
        token: token,
        newYieldAccum: calculatedData.newStrategyYieldAccum,
        newBalance: calculatedData.positionBalance - withdrawn,
        newHadLoss: strategyHadLoss
      });
    }
  }
}
