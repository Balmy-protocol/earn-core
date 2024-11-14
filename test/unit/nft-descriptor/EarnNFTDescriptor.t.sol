// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { IEarnVault } from "src/interfaces/IEarnVault.sol";
import { EarnNFTDescriptor, Ownable } from "src/nft-descriptor/EarnNFTDescriptor.sol";

contract EarnNFTDescriptorTest is PRBTest {
  EarnNFTDescriptor private nftDescriptor;
  address private owner = address(1);
  IEarnVault private vault = IEarnVault(address(15));

  function setUp() public virtual {
    nftDescriptor = new EarnNFTDescriptor("baseUrl/", owner);
  }

  function test_constructor() public {
    assertEq(nftDescriptor.owner(), owner);
    assertEq(nftDescriptor.baseURL(), "baseUrl/");
  }

  function test_tokenURI() public {
    vm.chainId(123_456);
    assertEq(nftDescriptor.tokenURI(vault, 999), "baseUrl/123456-0x000000000000000000000000000000000000000f-999");
  }

  function test_setBaseURL_revertWhen_CallerIsNotOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    nftDescriptor.setBaseURL("newBaseUrl/");
  }

  function test_setBaseURL() public {
    vm.prank(owner);
    nftDescriptor.setBaseURL("newBaseUrl/");
    assertEq(nftDescriptor.baseURL(), "newBaseUrl/");
  }
}
