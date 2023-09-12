// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { IAccessControlDefaultAdminRules, IAccessControl } from
  "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { INFTPermissions, IERC721 } from "@mean-finance/nft-permissions/interfaces/INFTPermissions.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IEarnVault, EarnVault, IEarnStrategyRegistry, IEarnFeeManager, Pausable } from "../../../src/vault/EarnVault.sol";
import { Utils } from "../../Utils.sol";

contract EarnVaultTest is PRBTest, StdUtils {
  address private superAdmin = address(1);
  address private pauseAdmin = address(2);
  address private withdrawFeeAdmin = address(3);
  IEarnStrategyRegistry private strategyRegistry;
  IEarnFeeManager private feeManager;
  EarnVault private vault;

  function setUp() public virtual {
    vault = new EarnVault(
      strategyRegistry,
      feeManager,
      superAdmin,
      Utils.arrayOf(pauseAdmin),
      Utils.arrayOf(withdrawFeeAdmin)
    );
  }

  function test_constants() public {
    assertEq(vault.PAUSE_ROLE(), keccak256("PAUSE_ROLE"));
    assertEq(vault.WITHDRAW_FEES_ROLE(), keccak256("WITHDRAW_FEES_ROLE"));
    assertEq(INFTPermissions.Permission.unwrap(vault.INCREASE_PERMISSION()), 0);
    assertEq(INFTPermissions.Permission.unwrap(vault.WITHDRAW_PERMISSION()), 1);
  }

  function test_constructor() public {
    // ERC721
    assertEq(vault.name(), "Balmy Earn NFT Position");
    assertEq(vault.symbol(), "EARN");

    // EIP712
    bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(typeHash, keccak256("Balmy Earn NFT Position"), keccak256("1.0"), block.chainid, address(vault))
    );
    assertEq(vault.DOMAIN_SEPARATOR(), expectedDomainSeparator);

    // Access control
    assertEq(vault.defaultAdminDelay(), 3 days);
    assertEq(vault.owner(), superAdmin);
    assertEq(vault.defaultAdmin(), superAdmin);
    assertTrue(vault.hasRole(vault.PAUSE_ROLE(), pauseAdmin));
    assertTrue(vault.hasRole(vault.WITHDRAW_FEES_ROLE(), withdrawFeeAdmin));

    // Immutables
    assertEq(address(vault.STRATEGY_REGISTRY()), address(strategyRegistry));
    assertEq(address(vault.FEE_MANAGER()), address(feeManager));
  }

  function test_supportsInterface() public {
    assertTrue(vault.supportsInterface(type(IAccessControlDefaultAdminRules).interfaceId));
    assertTrue(vault.supportsInterface(type(IERC721).interfaceId));
    assertTrue(vault.supportsInterface(type(IEarnVault).interfaceId));
    assertFalse(vault.supportsInterface(bytes4(0)));
  }

  function test_pause_RevertWhen_CalledByAccountWithoutRole() public {
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.PAUSE_ROLE()));
    vault.pause();
  }  

  function test_pause() public {
    assertFalse(vault.paused());

    vm.prank(pauseAdmin);
    vault.pause();

    assertTrue(vault.paused());
  }

  function test_pause_RevertWhen_ContractAlreadyPaused() public {
    vm.startPrank(pauseAdmin);

    vault.pause();

    vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
    vault.pause();

    vm.stopPrank();
  }

  function test_unpause_RevertWhen_CalledByAccountWithoutRole() public {
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.PAUSE_ROLE()));
    vault.unpause();
  }  

  function test_unpause() public {
    vm.startPrank(pauseAdmin);

    vault.pause();
    assertTrue(vault.paused());

    vault.unpause();
    assertFalse(vault.paused());

    vm.stopPrank();
  }

  function test_unpause_RevertWhen_ContractAlreadyUnpaused() public {
    vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
    vm.prank(pauseAdmin);
    vault.unpause();
  }
}
