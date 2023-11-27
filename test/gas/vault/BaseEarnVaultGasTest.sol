// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { EarnVault, IEarnStrategy, StrategyId, YieldMath } from "../../../src/vault/EarnVault.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { ERC20MintableBurnableMock } from "../../mocks/ERC20/ERC20MintableBurnableMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";

contract BaseEarnVaultGasTest is PRBTest, StdUtils {
  uint8 public constant MAX_LOSSES = YieldMath.MAX_LOSS_EVENTS;

  ERC20MintableBurnableMock public immutable erc20 = new ERC20MintableBurnableMock();
  ERC20MintableBurnableMock public immutable anotherErc20 = new ERC20MintableBurnableMock();
  ERC20MintableBurnableMock public immutable thirdErc20 = new ERC20MintableBurnableMock();
  EarnVault public immutable vault =
    new EarnVault(new EarnStrategyRegistryMock(), address(this), CommonUtils.arrayOf(address(this)));
  StrategyId public strategyId;
  IEarnStrategy public strategy;

  function setUp() public virtual {
    vm.deal(address(this), type(uint256).max);
    erc20.mint(address(this), type(uint256).max);
    erc20.approve(address(vault), type(uint256).max);
  }
}
