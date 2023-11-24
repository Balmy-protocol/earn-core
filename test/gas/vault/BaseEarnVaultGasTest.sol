// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { INFTPermissions } from "@mean-finance/nft-permissions/interfaces/INFTPermissions.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { EarnVault, IEarnStrategy, StrategyId } from "../../../src/vault/EarnVault.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { ERC20MintableBurnableMock } from "../../mocks/ERC20/ERC20MintableBurnableMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { InternalUtils } from "../../unit/vault/EarnVault.t.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract BaseEarnVaultGasTest is PRBTest, StdUtils {
  using Math for uint256;
  using Math for uint104;

  using InternalUtils for INFTPermissions.Permission[];

  address public superAdmin = address(1);
  address public pauseAdmin = address(2);
  address public positionOwner = address(3);
  address public operator = address(4);
  EarnStrategyRegistryMock public strategyRegistry;
  ERC20MintableBurnableMock public erc20;
  ERC20MintableBurnableMock public anotherErc20;
  ERC20MintableBurnableMock public thirdErc20;
  EarnVault public vault;
  INFTPermissions.PermissionSet[] public permissions;
  StrategyId public strategyId;
  IEarnStrategy public strategy;

  function setUp() public virtual {
    strategyRegistry = new EarnStrategyRegistryMock();
    erc20 = new ERC20MintableBurnableMock();
    anotherErc20 = new ERC20MintableBurnableMock();
    thirdErc20 = new ERC20MintableBurnableMock();
    vault = new EarnVault(
      strategyRegistry,
      superAdmin,
      CommonUtils.arrayOf(pauseAdmin)
    );

    erc20.approve(address(vault), type(uint256).max);
  }
}
