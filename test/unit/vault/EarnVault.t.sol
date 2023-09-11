// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { INFTPermissions } from "@mean-finance/nft-permissions/interfaces/INFTPermissions.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { EarnVault, IEarnStrategyRegistry, IEarnFeeManager } from "../../../src/vault/EarnVault.sol";
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
      abi.encode(typeHash, keccak256("Balmy Earn NFT Position"), keccak256("1"), block.chainid, address(vault))
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
}
