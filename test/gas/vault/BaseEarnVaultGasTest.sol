// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { EarnVault, IEarnStrategy, StrategyId, IEarnNFTDescriptor } from "../../../src/vault/EarnVault.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { ERC20MintableBurnableMock } from "../../mocks/ERC20/ERC20MintableBurnableMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";

contract BaseEarnVaultGasTest is PRBTest, StdUtils {
  ERC20MintableBurnableMock public immutable erc20 = new ERC20MintableBurnableMock();
  ERC20MintableBurnableMock public immutable anotherErc20 = new ERC20MintableBurnableMock();
  ERC20MintableBurnableMock public immutable thirdErc20 = new ERC20MintableBurnableMock();
  IEarnNFTDescriptor public immutable nftDescriptor;
  EarnVault public immutable vault =
    new EarnVault(new EarnStrategyRegistryMock(), address(this), CommonUtils.arrayOf(address(this)), nftDescriptor);
  StrategyId public strategyId;
  IEarnStrategy public strategy;

  function setUp() public virtual {
    vm.deal(address(this), type(uint256).max);
    erc20.mint(address(this), type(uint256).max);
    erc20.approve(address(vault), type(uint256).max);
  }
}
