// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
// solhint-disable-next-line no-unused-import
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NFTPermissions, ERC721 } from "@mean-finance/nft-permissions/NFTPermissions.sol";

import { IEarnVault, IEarnStrategyRegistry, IEarnFeeManager } from "../interfaces/IEarnVault.sol";
import { IEarnStrategy } from "../interfaces/IEarnStrategy.sol";

import { StrategyId } from "../types/StrategyId.sol";
import { PositionId } from "../types/PositionId.sol";
import { SpecialWithdrawalCode } from "../types/SpecialWithdrawals.sol";

// TODO: remove once functions are implemented
// slither-disable-start locked-ether
// slither-disable-start unimplemented-functions
// solhint-disable no-empty-blocks
contract EarnVault is AccessControlDefaultAdminRules, NFTPermissions, Pausable, IEarnVault {
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
  // slither-disable-end naming-convention

  constructor(
    IEarnStrategyRegistry strategyRegistry,
    IEarnFeeManager feeManager,
    address superAdmin,
    address[] memory initialPauseAdmins,
    address[] memory initialWithdrawFeeAdmins
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
    NFTPermissions("Balmy Earn NFT Position", "EARN", "1")
  {
    STRATEGY_REGISTRY = strategyRegistry;
    FEE_MANAGER = feeManager;

    _assignRoles(PAUSE_ROLE, initialPauseAdmins);
    _assignRoles(WITHDRAW_FEES_ROLE, initialWithdrawFeeAdmins);
  }

  /// @dev Needed to receive native tokens
  receive() external payable { }

  /// @inheritdoc IEarnVault
  function positionsStrategy(PositionId positionId) external view returns (StrategyId) { }

  /// @inheritdoc IEarnVault
  function position(PositionId positionId)
    external
    view
    returns (address[] memory, IEarnStrategy.WithdrawalType[] memory, uint256[] memory)
  { }

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
    returns (PositionId positionId, uint256 assetsDeposited)
  { }

  /// @inheritdoc IEarnVault
  function increasePosition(
    PositionId positionId,
    address depositToken,
    uint256 depositAmount
  )
    external
    payable
    returns (uint256 assetsDeposited)
  { }

  /// @inheritdoc IEarnVault
  function withdraw(
    PositionId positionId,
    address[] calldata tokensToWithdraw,
    uint256[] calldata intendedWithdraw,
    address recipient
  )
    external
    payable
    returns (uint256[] memory, IEarnStrategy.WithdrawalType[] memory)
  { }

  /// @inheritdoc IEarnVault
  function specialWithdraw(
    PositionId positionId,
    SpecialWithdrawalCode withdrawalCode,
    bytes calldata withdrawalData,
    address recipient
  )
    external
    payable
    returns (address[] memory, uint256[] memory, IEarnStrategy.WithdrawalType[] memory, bytes memory)
  { }

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
  function pause() external payable { }

  /// @inheritdoc IEarnVault
  function unpause() external payable { }

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
