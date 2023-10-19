// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnVault, IEarnVault, StrategyId } from "../../../src/vault/EarnVault.sol";
import { EarnStrategyRegistry, IEarnStrategyRegistry } from "../../../src/strategy-registry/EarnStrategyRegistry.sol";
import { IEarnStrategy } from "../../../src/interfaces/IEarnStrategy.sol";
import {
  DelayedWithdrawalManager,
  IDelayedWithdrawalManager,
  IDelayedWithdrawalAdapter
} from "../../../src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { INFTPermissions, IERC721 } from "@mean-finance/nft-permissions/interfaces/INFTPermissions.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { EarnStrategyStateBalanceMock } from "../../mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { Token } from "../../../src/libraries/Token.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { ERC20MintableBurnableMock } from "../../mocks/ERC20/ERC20MintableBurnableMock.sol";

import { BaseDelayedWithdrawalGasTest } from "./BaseDelayedWithdrawalGasTest.sol";

contract GasWithdraw is BaseDelayedWithdrawalGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  function setUp() public virtual override {
    super.setUp();

    // setUp
    IDelayedWithdrawalAdapter adapter1 = strategy.delayedWithdrawalAdapter(tokens[0]);
    vm.startPrank(address(adapter1));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[0], tokenByPosition[positions[0]]);
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);
    vm.stopPrank();

    IDelayedWithdrawalAdapter adapter2 = strategy.delayedWithdrawalAdapter(tokens[1]);
    vm.prank(address(adapter2));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[2], tokenByPosition[positions[2]]);
    vm.prank(address(owner));
  }

  function test_Gas_withdraw() public {
    delayedWithdrawalManager.withdraw(positions[0], tokenByPosition[positions[0]], address(10));
  }
}
