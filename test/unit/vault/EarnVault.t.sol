// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable no-unused-import
import {
  IAccessControlDefaultAdminRules,
  IAccessControl
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { INFTPermissions, IERC721 } from "@mean-finance/nft-permissions/interfaces/INFTPermissions.sol";
import { PermissionUtils } from "@mean-finance/nft-permissions-test/PermissionUtils.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { stdMath } from "forge-std/StdMath.sol";

import {
  IEarnVault,
  EarnVault,
  IEarnStrategyRegistry,
  Pausable,
  IEarnStrategy,
  StrategyId
} from "../../../src/vault/EarnVault.sol";
import { Token } from "../../../src/libraries/Token.sol";
import { YieldMath } from "../../../src/vault/libraries/YieldMath.sol";
import { EarnStrategyStateBalanceMock } from "../../mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { ERC20MintableBurnableMock } from "../../mocks/ERC20/ERC20MintableBurnableMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SpecialWithdrawalCode } from "../../../src/types/SpecialWithdrawals.sol";

contract EarnVaultTest is PRBTest, StdUtils {
  using Math for uint256;
  using Math for uint104;

  event PositionCreated(
    uint256 positionId,
    StrategyId strategyId,
    uint256 assetsDeposited,
    address owner,
    INFTPermissions.PermissionSet[] permissions,
    bytes misc
  );

  event PositionIncreased(uint256 positionId, uint256 assetsDeposited);

  event PositionWithdrawn(uint256 positionId, address[] tokens, uint256[] withdrawn, address recipient);

  using StrategyUtils for EarnStrategyRegistryMock;
  using InternalUtils for INFTPermissions.Permission[];

  address private superAdmin = address(1);
  address private pauseAdmin = address(2);
  address private positionOwner = address(3);
  address private operator = address(4);
  EarnStrategyRegistryMock private strategyRegistry;
  ERC20MintableBurnableMock private erc20;
  ERC20MintableBurnableMock private anotherErc20;
  EarnVault private vault;

  function setUp() public virtual {
    strategyRegistry = new EarnStrategyRegistryMock();
    erc20 = new ERC20MintableBurnableMock();
    anotherErc20 = new ERC20MintableBurnableMock();
    vault = new EarnVault(strategyRegistry, superAdmin, CommonUtils.arrayOf(pauseAdmin));

    erc20.approve(address(vault), type(uint256).max);

    vm.label(address(strategyRegistry), "Strategy Registry");
    vm.label(address(erc20), "ERC20");
    vm.label(address(vault), "Vault");
  }

  function test_constants() public {
    assertEq(vault.PAUSE_ROLE(), keccak256("PAUSE_ROLE"));
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

    // Immutables
    assertEq(address(vault.STRATEGY_REGISTRY()), address(strategyRegistry));
  }

  function test_supportsInterface() public {
    assertTrue(vault.supportsInterface(type(IAccessControlDefaultAdminRules).interfaceId));
    assertTrue(vault.supportsInterface(type(IERC721).interfaceId));
    assertTrue(vault.supportsInterface(type(IEarnVault).interfaceId));
    assertFalse(vault.supportsInterface(bytes4(0)));
  }

  function test_createPosition_RevertWhen_Paused() public {
    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    // Pause deposits
    vm.prank(pauseAdmin);
    vault.pause();

    vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
    vault.createPosition(
      strategyId, Token.NATIVE_TOKEN, 1 ether, positionOwner, PermissionUtils.buildEmptyPermissionSet(), ""
    );
  }

  function test_createPosition_RevertWhen_EmptyDeposit() public {
    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectRevert(abi.encodeWithSelector(IEarnVault.ZeroAmountDeposit.selector));
    vault.createPosition(
      strategyId, Token.NATIVE_TOKEN, 0 ether, positionOwner, PermissionUtils.buildEmptyPermissionSet(), ""
    );
  }

  function test_createPosition_RevertWhen_UsingFullDepositWithNative() public {
    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectRevert(abi.encodeWithSelector(Token.OperationNotSupportedForNativeToken.selector));
    vault.createPosition(
      strategyId, Token.NATIVE_TOKEN, type(uint256).max, positionOwner, PermissionUtils.buildEmptyPermissionSet(), ""
    );
  }

  function testFuzz_createPosition_WithNative(uint104 amountToDeposit) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max));
    vm.deal(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectCall(
      address(strategy),
      abi.encodeWithSelector(IEarnStrategy.deposited.selector, Token.NATIVE_TOKEN, amountToDeposit),
      1
    );
    vm.expectEmit();
    emit PositionCreated(1, strategyId, amountToDeposit, positionOwner, permissions, misc);
    (uint256 positionId, uint256 assetsDeposited) = vault.createPosition{ value: amountToDeposit }(
      strategyId, Token.NATIVE_TOKEN, amountToDeposit, positionOwner, permissions, misc
    );

    // Return values
    assertEq(positionId, 1);
    assertEq(assetsDeposited, amountToDeposit);
    // ERC721
    assertEq(vault.totalSupply(), 1);
    assertEq(vault.ownerOf(1), positionOwner);
    // NFTPermissions
    checkPermissions(positionId, permissions);
    // Earn
    (address[] memory tokens, IEarnStrategy.WithdrawalType[] memory withdrawalTypes, uint256[] memory balances) =
      vault.position(positionId);
    assertEq(tokens.length, 1);
    assertEq(tokens[0], Token.NATIVE_TOKEN);
    assertEq(withdrawalTypes.length, 1);
    assertEq(uint8(withdrawalTypes[0]), uint8(IEarnStrategy.WithdrawalType.IMMEDIATE));
    assertEq(balances.length, 1);
    assertEq(balances[0], amountToDeposit);
    assertEq(StrategyId.unwrap(vault.positionsStrategy(positionId)), StrategyId.unwrap(strategyId));
    // Funds
    assertEq(address(this).balance, 0);
    assertEq(address(strategy).balance, amountToDeposit);
  }

  function testFuzz_createPosition_WithERC20(uint104 amountToDeposit) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max));
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    vm.expectCall(
      address(strategy), abi.encodeWithSelector(IEarnStrategy.deposited.selector, address(erc20), amountToDeposit), 1
    );
    vm.expectEmit();
    emit PositionCreated(1, strategyId, amountToDeposit, positionOwner, permissions, misc);
    (uint256 positionId, uint256 assetsDeposited) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    // Return values
    assertEq(positionId, 1);
    assertEq(assetsDeposited, amountToDeposit);
    // ERC721
    assertEq(vault.totalSupply(), 1);
    assertEq(vault.ownerOf(1), positionOwner);
    // NFTPermissions
    checkPermissions(positionId, permissions);
    // Earn
    (address[] memory tokens, IEarnStrategy.WithdrawalType[] memory withdrawalTypes, uint256[] memory balances) =
      vault.position(positionId);
    assertEq(tokens.length, 1);
    assertEq(tokens[0], address(erc20));
    assertEq(withdrawalTypes.length, 1);
    assertEq(uint8(withdrawalTypes[0]), uint8(IEarnStrategy.WithdrawalType.IMMEDIATE));
    assertEq(balances.length, 1);
    assertEq(balances[0], amountToDeposit);
    assertEq(StrategyId.unwrap(vault.positionsStrategy(positionId)), StrategyId.unwrap(strategyId));
    // Funds
    assertEq(erc20.balanceOf(address(this)), 0);
    assertEq(erc20.balanceOf(address(strategy)), amountToDeposit);
  }

  function testFuzz_createPosition_WithERC20Max(uint104 amountToDeposit) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max));
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    vm.expectCall(
      address(strategy), abi.encodeWithSelector(IEarnStrategy.deposited.selector, address(erc20), amountToDeposit), 1
    );
    vm.expectEmit();
    emit PositionCreated(1, strategyId, amountToDeposit, positionOwner, permissions, misc);
    (uint256 positionId, uint256 assetsDeposited) =
      vault.createPosition(strategyId, address(erc20), type(uint256).max, positionOwner, permissions, misc);

    // Return values
    assertEq(positionId, 1);
    assertEq(assetsDeposited, amountToDeposit);
    // ERC721
    assertEq(vault.totalSupply(), 1);
    assertEq(vault.ownerOf(1), positionOwner);
    // NFTPermissions
    checkPermissions(positionId, permissions);
    // Earn
    (address[] memory tokens, IEarnStrategy.WithdrawalType[] memory withdrawalTypes, uint256[] memory balances) =
      vault.position(positionId);
    assertEq(tokens.length, 1);
    assertEq(tokens[0], address(erc20));
    assertEq(withdrawalTypes.length, 1);
    assertEq(uint8(withdrawalTypes[0]), uint8(IEarnStrategy.WithdrawalType.IMMEDIATE));
    assertEq(balances.length, 1);
    assertEq(balances[0], amountToDeposit);
    assertEq(StrategyId.unwrap(vault.positionsStrategy(positionId)), StrategyId.unwrap(strategyId));
    // Funds
    assertEq(erc20.balanceOf(address(this)), 0);
    assertEq(erc20.balanceOf(address(strategy)), amountToDeposit);
  }

  function testFuzz_createPosition_MultiplePositions(uint104 amountToDeposit1, uint104 amountToDeposit2) public {
    amountToDeposit1 = uint104(bound(amountToDeposit1, 1, type(uint104).max));
    amountToDeposit2 = uint104(bound(amountToDeposit2, 1, type(uint104).max));
    vm.deal(address(this), uint256(amountToDeposit1) + amountToDeposit2);

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    (uint256 positionId1, uint256 assetsDeposited1) = vault.createPosition{ value: amountToDeposit1 }(
      strategyId, Token.NATIVE_TOKEN, amountToDeposit1, positionOwner, PermissionUtils.buildEmptyPermissionSet(), ""
    );
    (uint256 positionId2, uint256 assetsDeposited2) = vault.createPosition{ value: amountToDeposit2 }(
      strategyId, Token.NATIVE_TOKEN, amountToDeposit2, positionOwner, PermissionUtils.buildEmptyPermissionSet(), ""
    );

    // Return values
    assertEq(positionId1, 1);
    assertEq(assetsDeposited1, amountToDeposit1);
    assertEq(positionId2, 2);
    assertEq(assetsDeposited2, amountToDeposit2);
    // ERC721
    assertEq(vault.totalSupply(), 2);
    // Earn
    (,, uint256[] memory balances1) = vault.position(positionId1);
    assertEq(balances1.length, 1);
    assertEq(balances1[0], amountToDeposit1);
    (,, uint256[] memory balances2) = vault.position(positionId2);
    assertEq(balances2.length, 1);
    assertEq(balances2[0], amountToDeposit2);
    // Funds
    assertEq(address(this).balance, 0);
    assertEq(address(strategy).balance, uint256(amountToDeposit1) + amountToDeposit2);
  }

  function test_pause_RevertWhen_CalledByAccountWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.PAUSE_ROLE()
      )
    );
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
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.PAUSE_ROLE()
      )
    );
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

  function test_createPosition_CheckRewards() public {
    uint256 amountToDeposit1 = 120_000;
    uint256 amountToDeposit2 = 120_000;
    uint256 amountToDeposit3 = 240_000;
    uint256 amountToDeposit4 = 240_000;
    uint256 amountToReward = 120_000;
    erc20.mint(address(this), amountToDeposit1 + amountToDeposit2 + amountToDeposit3 + amountToDeposit4);
    uint256[] memory rewards = new uint256[](4);
    uint256[] memory shares = new uint256[](4);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = new address[](2);
    strategyTokens[0] = address(erc20);
    strategyTokens[1] = address(anotherErc20);
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    (uint256 positionId1,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    // Shares: 10
    //Total shares: 10
    shares[0] = 10;
    totalShares = 10;

    (,, uint256[] memory balances1) = vault.position(positionId1);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances1[1], 1);

    (uint256 positionId2,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit2, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    //Shares: 10
    //Total shares: 20
    shares[1] = 10;
    totalShares += shares[1];

    // Earn
    (,, balances1) = vault.position(positionId1);
    assertEq(balances1.length, 2);
    assertEq(balances1[0], amountToDeposit1);

    (,, uint256[] memory balances2) = vault.position(positionId2);
    assertEq(balances2.length, 2);
    assertEq(balances2[0], amountToDeposit2);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);

    (uint256 positionId3,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);
    //Shares: 20
    // Total shares: 40
    shares[2] = 20;
    totalShares += shares[2];

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, uint256[] memory balances3) = vault.position(positionId3);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);

    (uint256 positionId4,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit4, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);
    // Shares: 20
    // Total shares: 60
    shares[3] = 20;
    totalShares += shares[3];

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, balances3) = vault.position(positionId3);
    (,, uint256[] memory balances4) = vault.position(positionId4);

    //LAST SNAPSHOT

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);
    assertApproxEqAbs(rewards[3], balances4[1], 1);
  }

  function test_createPosition_CheckRewardsWithLoss() public {
    uint256 amountToDeposit1 = 100_000;
    uint256 amountToDeposit2 = 200_000;
    uint256 amountToDeposit3 = 50_000;
    uint256 amountToReward = 100_000;
    erc20.mint(address(this), amountToDeposit1 + amountToDeposit2 + amountToDeposit3 * 2);
    uint256[] memory rewards = new uint256[](4);
    uint256[] memory shares = new uint256[](4);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = new address[](2);
    strategyTokens[0] = address(erc20);
    strategyTokens[1] = address(anotherErc20);
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    (uint256 positionId1,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    // Shares: 100
    //Total shares: 100
    shares[0] = 100;
    totalShares += shares[0];

    (,, uint256[] memory balances1) = vault.position(positionId1);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances1[1], 1);

    (uint256 positionId2,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit2, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward * 3);

    //Shares: 200
    //Total shares: 300
    shares[1] = 200;
    totalShares += shares[1];

    // Earn
    (,, balances1) = vault.position(positionId1);
    assertEq(balances1.length, 2);
    assertEq(balances1[0], amountToDeposit1);

    (,, uint256[] memory balances2) = vault.position(positionId2);
    assertEq(balances2.length, 2);
    assertEq(balances2[0], amountToDeposit2);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);

    (uint256 positionId3,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.burn(address(strategy), 350_000);
    //Shares: 50
    // Total shares: 350
    shares[2] = 50;
    totalShares += shares[2];

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, uint256[] memory balances3) = vault.position(positionId3);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);

    // FINAL SNAPSHOT

    (uint256 positionId4,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    shares[3] = 50;
    totalShares += shares[3];
    anotherErc20.mint(address(strategy), 350_000);

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, balances3) = vault.position(positionId3);
    (,, uint256[] memory balances4) = vault.position(positionId4);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);
    assertApproxEqAbs(rewards[3], balances4[1], 1);
  }

  function test_createPosition_CheckRewardsWithTotalLoss() public {
    uint256 amountToDeposit1 = 100_000;
    uint256 amountToDeposit2 = 200_000;
    uint256 amountToDeposit3 = 50_000;
    uint256 amountToReward = 100_000;
    erc20.mint(address(this), amountToDeposit1 + amountToDeposit2 + amountToDeposit3 * 2);
    uint256[] memory rewards = new uint256[](4);
    uint256[] memory shares = new uint256[](4);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = new address[](2);
    strategyTokens[0] = address(erc20);
    strategyTokens[1] = address(anotherErc20);
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    (uint256 positionId1,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    // Shares: 100
    //Total shares: 100
    shares[0] = 100;
    totalShares += shares[0];

    (,, uint256[] memory balances1) = vault.position(positionId1);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances1[1], 1);

    (uint256 positionId2,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit2, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward * 3);

    //Shares: 200
    //Total shares: 300
    shares[1] = 200;
    totalShares += shares[1];

    // Earn
    (,, balances1) = vault.position(positionId1);
    assertEq(balances1.length, 2);
    assertEq(balances1[0], amountToDeposit1);

    (,, uint256[] memory balances2) = vault.position(positionId2);
    assertEq(balances2.length, 2);
    assertEq(balances2[0], amountToDeposit2);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);

    (uint256 positionId3,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.burn(address(strategy), amountToReward);
    //Shares: 50
    // Total shares: 350
    shares[2] = 50;
    totalShares += shares[2];

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, uint256[] memory balances3) = vault.position(positionId3);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);

    // FINAL SNAPSHOT

    (uint256 positionId4,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    shares[3] = 50;
    totalShares += shares[3];
    anotherErc20.mint(address(strategy), 350_000);

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, balances3) = vault.position(positionId3);
    (,, uint256[] memory balances4) = vault.position(positionId4);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);
    assertApproxEqAbs(rewards[3], balances4[1], 1);
  }

  function testFuzz_createPosition_CheckRewardsWithLosses(
    uint104 amountToDeposit1,
    uint104 amountToDeposit2,
    uint104 amountToDeposit3,
    uint104 amountToDeposit4,
    uint104 amountToDeposit5,
    uint104 amountToReward1,
    uint104 amountToReward2,
    uint104 amountToLose
  )
    public
  {
    amountToDeposit1 = uint104(bound(amountToDeposit1, 6, type(uint96).max / 5));
    amountToDeposit2 = uint104(bound(amountToDeposit2, 12, type(uint96).max / 5));
    amountToDeposit3 = uint104(bound(amountToDeposit3, 6, type(uint96).max / 5));
    amountToDeposit4 = uint104(bound(amountToDeposit4, 6, type(uint96).max / 5));
    amountToDeposit5 = uint104(bound(amountToDeposit5, 6, type(uint96).max / 5));
    amountToReward1 = uint104(bound(amountToReward1, 5, amountToDeposit1 - 1));
    amountToReward2 = uint104(bound(amountToReward2, 4, amountToReward1 - 1));
    amountToLose = uint104(bound(amountToLose, 1, amountToReward2 / 2 - 1));

    erc20.mint(
      address(this), amountToDeposit1 + amountToDeposit2 + amountToDeposit3 + amountToDeposit4 + amountToDeposit5
    );
    uint256[] memory rewards = new uint256[](5);
    uint256[] memory shares = new uint256[](5);
    uint256[] memory positionIds = new uint256[](5);
    uint256[][] memory balances = new uint256[][](5);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = new address[](2);
    strategyTokens[0] = address(erc20);
    strategyTokens[1] = address(anotherErc20);
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    // SNAPSHOT

    (positionIds[0],) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward1);
    shares[0] = amountToDeposit1;
    totalShares += shares[0];

    (,, balances[0]) = vault.position(positionIds[0]);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances[0][1], 1);

    // SNAPSHOT

    (positionIds[1],) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit2, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward1);

    shares[1] = amountToDeposit2;
    totalShares += shares[1];

    previousBalance = takeSnapshotAndAssertBalances(
      balances, positionIds, strategy, previousBalance, totalShares, rewards, shares, positionsCreated
    );

    // SNAPSHOT

    (positionIds[2],) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.burn(address(strategy), amountToLose);
    shares[2] = amountToDeposit3;
    totalShares += shares[2];

    previousBalance = takeSnapshotAndAssertBalances(
      balances, positionIds, strategy, previousBalance, totalShares, rewards, shares, positionsCreated
    );

    // SNAPSHOT

    (positionIds[3],) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit4, positionOwner, permissions, misc);
    positionsCreated++;
    shares[3] = amountToDeposit4;
    totalShares += shares[3];
    anotherErc20.mint(address(strategy), amountToReward2);

    previousBalance = takeSnapshotAndAssertBalances(
      balances, positionIds, strategy, previousBalance, totalShares, rewards, shares, positionsCreated
    );

    // FINAL SNAPSHOT

    (positionIds[4],) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit5, positionOwner, permissions, misc);
    positionsCreated++;
    shares[4] = amountToDeposit5;
    totalShares += shares[4];
    anotherErc20.burn(address(strategy), amountToLose);
    previousBalance = takeSnapshotAndAssertBalances(
      balances, positionIds, strategy, previousBalance, totalShares, rewards, shares, positionsCreated
    );
  }

  function testFuzz_createPosition_CheckRewardsWithLoss_FilledMaxLosses(uint8 losses) public {
    losses = uint8(bound(losses, 1, 30));
    uint256 amountToDeposit1 = 100_000;
    uint256 amountToBurn = 1000;
    uint256 amountToReward = amountToBurn * (losses + 1);
    erc20.mint(address(this), amountToDeposit1 * losses);
    uint256[] memory rewards = new uint256[](losses);
    uint256[] memory shares = new uint256[](losses);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = new address[](2);
    strategyTokens[0] = address(erc20);
    strategyTokens[1] = address(anotherErc20);
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    (uint256 positionId1,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);
    shares[0] = 10;
    totalShares += shares[0];

    uint256[] memory balances1;
    for (uint8 i = 1; i < losses; i++) {
      (,, balances1) = vault.position(positionId1);
      previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
      assertApproxEqAbs(rewards[0], balances1[1], 1);
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
      positionsCreated++;
      anotherErc20.burn(address(strategy), amountToBurn);
      shares[i] = 10;
      totalShares += shares[i];
    }

    (,, balances1) = vault.position(positionId1);
    assertApproxEqAbs(amountToReward - amountToBurn * (losses - 1), balances1[1], 1);
  }

  function test_createPosition_CheckRewardsWithLoss_FilledMaxTotalLosses() public {
    uint8 positions = (YieldMath.MAX_TOTAL_LOSS_EVENTS + 2) * 2;
    uint256 amountToDeposit1 = 100_000;
    uint256 amountToBurn = 1000;
    uint256 amountToReward = amountToBurn;
    erc20.mint(address(this), amountToDeposit1 * positions);
    uint256[] memory rewards = new uint256[](positions);
    uint256[] memory shares = new uint256[](positions);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = new address[](2);
    strategyTokens[0] = address(erc20);
    strategyTokens[1] = address(anotherErc20);
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    (uint256 positionId1,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    shares[0] = 10;
    totalShares += shares[0];

    uint256[] memory balances1;
    for (uint8 i = 1; i < positions; i++) {
      (,, balances1) = vault.position(positionId1);
      previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);

      positionsCreated++;
      if (i % 2 == 0) {
        anotherErc20.burn(address(strategy), anotherErc20.balanceOf(address(strategy)));
      } else {
        assertApproxEqAbs(0, balances1[1], 1);

        anotherErc20.mint(address(strategy), amountToReward);
      }
      shares[i] = 10;
      totalShares += shares[i];
    }

    (,, balances1) = vault.position(positionId1);
    assertApproxEqAbs(0, balances1[1], 1);
  }

  function testFuzz_withdraw_WithERC20(uint104 amountToDeposit, uint8 percentageToWithdraw) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max));
    percentageToWithdraw = uint8(bound(percentageToWithdraw, 1, 100));
    uint256 amountToWithdraw = percentageToWithdraw == 100
      ? type(uint256).max
      : amountToDeposit.mulDiv(percentageToWithdraw, 100, Math.Rounding.Ceil);
    address recipient = address(18);
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    // Funds before withdraw
    (address[] memory tokens,, uint256[] memory balances) = vault.position(positionId);
    assertEq(erc20.balanceOf(address(strategy)), amountToDeposit);
    assertEq(balances[0], amountToDeposit);

    vm.prank(operator);
    vm.expectEmit();
    emit PositionWithdrawn(
      positionId,
      tokens,
      CommonUtils.arrayOf(amountToWithdraw != type(uint256).max ? amountToWithdraw : amountToDeposit),
      recipient
    );
    vault.withdraw(positionId, tokens, CommonUtils.arrayOf(amountToWithdraw), recipient);

    // Funds after withdraw
    (,, balances) = vault.position(positionId);
    assertEq(erc20.balanceOf(recipient), amountToWithdraw != type(uint256).max ? amountToWithdraw : amountToDeposit);
    assertEq(
      erc20.balanceOf(address(strategy)), amountToWithdraw != type(uint256).max ? amountToDeposit - amountToWithdraw : 0
    );
    assertEq(balances[0], amountToWithdraw != type(uint256).max ? amountToDeposit - amountToWithdraw : 0);
  }

  function testFuzz_withdraw_WithNative(uint104 amountToDeposit, uint8 percentageToWithdraw) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max));
    percentageToWithdraw = uint8(bound(percentageToWithdraw, 1, 100));
    uint256 amountToWithdraw = percentageToWithdraw == 100
      ? type(uint256).max
      : amountToDeposit.mulDiv(percentageToWithdraw, 100, Math.Rounding.Ceil);
    vm.deal(address(this), amountToDeposit);
    address recipient = address(18);

    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    (uint256 positionId,) = vault.createPosition{ value: amountToDeposit }(
      strategyId, Token.NATIVE_TOKEN, amountToDeposit, positionOwner, permissions, misc
    );

    // Funds before withdraw
    (address[] memory tokens,, uint256[] memory balances) = vault.position(positionId);
    assertEq(address(strategy).balance, amountToDeposit);
    assertEq(balances[0], amountToDeposit);

    vm.prank(operator);
    vm.expectEmit();
    emit PositionWithdrawn(
      positionId,
      tokens,
      CommonUtils.arrayOf(amountToWithdraw != type(uint256).max ? amountToWithdraw : amountToDeposit),
      recipient
    );
    vault.withdraw(positionId, tokens, CommonUtils.arrayOf(amountToWithdraw), recipient);

    // Funds after withdraw
    (,, balances) = vault.position(positionId);
    assertEq(recipient.balance, amountToWithdraw != type(uint256).max ? amountToWithdraw : amountToDeposit);
    assertEq(address(strategy).balance, amountToWithdraw != type(uint256).max ? amountToDeposit - amountToWithdraw : 0);
    assertEq(balances[0], amountToWithdraw != type(uint256).max ? amountToDeposit - amountToWithdraw : 0);
  }

  function test_withdraw_RevertWhen_IntendendWithdrawMoreThanBalance() public {
    uint104 amountToDeposit = 10_000;
    uint104 amountToWithdraw = amountToDeposit + 1;

    address recipient = address(18);
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    (address[] memory tokens,,) = vault.position(positionId);

    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IEarnVault.InsufficientFunds.selector));
    vault.withdraw(positionId, tokens, CommonUtils.arrayOf(amountToWithdraw), recipient);
  }

  function test_withdraw_RevertWhen_AccountWithoutPermission() public {
    uint104 amountToDeposit = 10_000;
    uint104 amountToWithdraw = 5000;

    address recipient = address(18);
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions;
    bytes memory misc = "1234";

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    (address[] memory tokens,,) = vault.position(positionId);

    vm.expectRevert(
      abi.encodeWithSelector(
        INFTPermissions.AccountWithoutPermission.selector, positionId, operator, vault.WITHDRAW_PERMISSION()
      )
    );
    vm.prank(operator);
    vault.withdraw(positionId, tokens, CommonUtils.arrayOf(amountToWithdraw), recipient);
  }

  function test_withdraw_RevertWhen_InvalidWithdrawInput_DifferentToken() public {
    uint104 amountToDeposit = 10_000;
    uint104 amountToWithdraw = 5000;

    address recipient = address(18);
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IEarnVault.InvalidWithdrawInput.selector));
    vault.withdraw(
      positionId, CommonUtils.arrayOf(address(anotherErc20)), CommonUtils.arrayOf(amountToWithdraw), recipient
    );
  }

  function test_withdraw_RevertWhen_InvalidWithdrawInput_ArraySizeMismatch() public {
    uint104 amountToDeposit = 10_000;
    uint104 amountToWithdraw = 5000;

    address recipient = address(18);
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);
    (address[] memory tokens,,) = vault.position(positionId);

    uint256[] memory intendendWithdraw = CommonUtils.arrayOf(amountToWithdraw, amountToWithdraw);

    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IEarnVault.InvalidWithdrawInput.selector));
    vault.withdraw(positionId, tokens, intendendWithdraw, recipient);
  }

  function test_withdraw_CheckRewards() public {
    uint256 amountToDeposit1 = 120_000;
    uint256 amountToDeposit2 = 120_000;
    uint256 amountToDeposit3 = 240_000;
    uint256 amountToReward = 120_000;
    erc20.mint(address(this), amountToDeposit1 + amountToDeposit2 + amountToDeposit3);
    uint256[] memory rewards = new uint256[](3);
    uint256[] memory shares = new uint256[](3);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = CommonUtils.arrayOf(address(erc20), address(anotherErc20));
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    (uint256 positionId1,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    // Shares: 10
    //Total shares: 10
    shares[0] = 10;
    totalShares = 10;

    (,, uint256[] memory balances1) = vault.position(positionId1);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances1[1], 1);

    (uint256 positionId2,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit2, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    //Shares: 10
    //Total shares: 20
    shares[1] = 10;
    totalShares += shares[1];

    // Earn
    (,, balances1) = vault.position(positionId1);
    assertEq(balances1.length, 2);
    assertEq(balances1[0], amountToDeposit1);

    (,, uint256[] memory balances2) = vault.position(positionId2);
    assertEq(balances2.length, 2);
    assertEq(balances2[0], amountToDeposit2);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);

    (uint256 positionId3,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);
    //Shares: 20
    // Total shares: 40
    shares[2] = 20;
    totalShares += shares[2];

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, uint256[] memory balances3) = vault.position(positionId3);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);

    // WITHDRAW ONLY ASSET

    uint256 amountToWithdraw1 = 21_000;
    address recipient = address(18);
    uint256[] memory intendendWithdraw = CommonUtils.arrayOf(amountToWithdraw1, 0);

    vm.prank(operator);
    vault.withdraw(positionId1, strategyTokens, intendendWithdraw, recipient);

    // UPDATE SHARES
    //Shares: 5
    // Total shares: 35
    shares[0] -= 5;
    totalShares -= 5;

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, balances3) = vault.position(positionId3);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(amountToDeposit1 - amountToWithdraw1, balances1[0], 1);
    assertApproxEqAbs(rewards[0], balances1[1], 1);

    // WITHDRAW ONLY REWARDS

    intendendWithdraw[0] = 0;
    intendendWithdraw[1] = amountToWithdraw1;

    vm.prank(operator);
    vault.withdraw(positionId1, strategyTokens, intendendWithdraw, recipient);

    (,, balances1) = vault.position(positionId1);
    assertApproxEqAbs(amountToDeposit1 - amountToWithdraw1, balances1[0], 1);

    //Rewards have to be calculated with previous shares and balance
    assertApproxEqAbs(rewards[0] - intendendWithdraw[1], balances1[1], 1);
  }

  function testFuzz_increasePosition_WithERC20(uint104 amountToDeposit, uint256 amountToIncrease) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max - 1));
    amountToIncrease = amountToIncrease > type(uint104).max
      ? type(uint256).max
      : uint104(bound(amountToIncrease, 1, type(uint104).max - amountToDeposit));
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.INCREASE_PERMISSION()));
    bytes memory misc = "1234";

    vm.prank(address(operator));
    erc20.approve(
      address(vault), amountToIncrease != type(uint256).max ? amountToDeposit + amountToIncrease : type(uint256).max
    );

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    erc20.mint(address(this), amountToDeposit);
    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    // Funds before increase
    (,, uint256[] memory balances) = vault.position(positionId);
    assertEq(erc20.balanceOf(address(strategy)), amountToDeposit);
    assertEq(balances[0], amountToDeposit);

    erc20.mint(address(operator), amountToIncrease != type(uint256).max ? amountToIncrease : 50_000);
    uint256 previousOperatorBalance = erc20.balanceOf(operator);
    uint256 previousStrategyBalance = erc20.balanceOf(address(strategy));
    vm.expectEmit();
    emit PositionIncreased(
      positionId, amountToIncrease != type(uint256).max ? amountToIncrease : previousOperatorBalance
    );
    vm.prank(operator);
    vault.increasePosition(positionId, address(erc20), amountToIncrease);

    // Funds after increase
    (,, balances) = vault.position(positionId);
    assertEq(
      erc20.balanceOf(operator), amountToIncrease != type(uint256).max ? previousOperatorBalance - amountToIncrease : 0
    );
    assertEq(
      erc20.balanceOf(address(strategy)),
      amountToIncrease != type(uint256).max
        ? previousStrategyBalance + amountToIncrease
        : previousStrategyBalance + previousOperatorBalance
    );
    assertEq(
      balances[0],
      amountToIncrease != type(uint256).max
        ? amountToDeposit + amountToIncrease
        : amountToDeposit + previousOperatorBalance
    );
  }

  function testFuzz_increasePosition_WithNative(uint104 amountToDeposit, uint104 amountToIncrease) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max - 1));
    amountToIncrease = uint104(bound(amountToIncrease, 1, type(uint104).max - amountToDeposit));
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.INCREASE_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.deal(address(this), amountToDeposit);
    (uint256 positionId,) = vault.createPosition{ value: amountToDeposit }(
      strategyId, Token.NATIVE_TOKEN, amountToDeposit, positionOwner, permissions, misc
    );

    // Funds before increase
    (,, uint256[] memory balances) = vault.position(positionId);
    assertEq(address(strategy).balance, amountToDeposit);
    assertEq(balances[0], amountToDeposit);

    vm.deal(operator, amountToIncrease);
    uint256 previousOperatorBalance = operator.balance;
    uint256 previousStrategyBalance = address(strategy).balance;

    vm.expectEmit();
    emit PositionIncreased(positionId, amountToIncrease);
    vm.prank(operator);
    vault.increasePosition{ value: amountToIncrease }(positionId, Token.NATIVE_TOKEN, amountToIncrease);

    // Funds after increase
    (,, balances) = vault.position(positionId);
    assertEq(operator.balance, previousOperatorBalance - amountToIncrease);
    assertEq(address(strategy).balance, previousStrategyBalance + amountToIncrease);
    assertEq(balances[0], amountToDeposit + amountToIncrease);
  }

  function test_increasePosition_WithNative_RevertWhen_UsingFullDepositWithNative() public {
    uint104 amountToDeposit = 120_000;
    uint256 amountToIncrease = type(uint256).max;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.INCREASE_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.deal(address(this), amountToDeposit);
    (uint256 positionId,) = vault.createPosition{ value: amountToDeposit }(
      strategyId, Token.NATIVE_TOKEN, amountToDeposit, positionOwner, permissions, misc
    );

    vm.deal(operator, amountToIncrease);

    vm.expectRevert(Token.OperationNotSupportedForNativeToken.selector);
    vm.prank(operator);
    vault.increasePosition{ value: amountToIncrease }(positionId, Token.NATIVE_TOKEN, amountToIncrease);
  }

  function test_increasePosition_RevertWhen_AccountWithoutPermission() public {
    uint104 amountToDeposit = 10_000;
    uint104 amountToIncrease = 15_000;
    INFTPermissions.PermissionSet[] memory permissions;
    bytes memory misc = "1234";

    vm.prank(address(operator));
    erc20.approve(address(vault), amountToDeposit + amountToIncrease);

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    erc20.mint(address(this), amountToDeposit);
    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    vm.expectRevert(
      abi.encodeWithSelector(
        INFTPermissions.AccountWithoutPermission.selector, positionId, operator, vault.INCREASE_PERMISSION()
      )
    );
    vm.prank(operator);
    vault.increasePosition(positionId, address(erc20), amountToIncrease);
  }

  function test_increasePosition_RevertWhen_Paused() public {
    uint104 amountToDeposit = 10_000;
    uint104 amountToIncrease = 15_000;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.INCREASE_PERMISSION()));
    bytes memory misc = "1234";

    vm.prank(address(operator));
    erc20.approve(address(vault), amountToDeposit + amountToIncrease);

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    erc20.mint(address(this), amountToDeposit);
    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    // Pause deposits
    vm.prank(pauseAdmin);
    vault.pause();

    vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
    vm.prank(operator);
    vault.increasePosition(positionId, address(erc20), amountToIncrease);
  }

  function test_increasePosition_RevertWhen_EmptyDeposit() public {
    uint104 amountToDeposit = 10_000;
    uint104 amountToIncrease = 0;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.INCREASE_PERMISSION()));
    bytes memory misc = "1234";

    vm.prank(address(operator));
    erc20.approve(address(vault), amountToDeposit + amountToIncrease);

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    erc20.mint(address(this), amountToDeposit);
    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    vm.expectRevert(abi.encodeWithSelector(IEarnVault.ZeroAmountDeposit.selector));
    vm.prank(operator);
    vault.increasePosition(positionId, address(erc20), amountToIncrease);
  }

  function test_increasePosition_CheckRewards() public {
    uint256 amountToDeposit1 = 120_000;
    uint256 amountToDeposit2 = 120_000;
    uint256 amountToDeposit3 = 240_000;
    uint256 amountToReward = 120_000;
    uint256 amountToIncrease1 = 120_000;
    erc20.mint(address(this), amountToDeposit1 + amountToDeposit2 + amountToDeposit3 + amountToIncrease1);
    uint256[] memory rewards = new uint256[](3);
    uint256[] memory shares = new uint256[](3);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(address(this), PermissionUtils.permissions(vault.INCREASE_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = CommonUtils.arrayOf(address(erc20), address(anotherErc20));
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    (uint256 positionId1,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    // Shares: 10
    //Total shares: 10
    shares[0] = 10;
    totalShares = 10;

    (,, uint256[] memory balances1) = vault.position(positionId1);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    (uint256 positionId2,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit2, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    //Shares: 10
    //Total shares: 20
    shares[1] = 10;
    totalShares += shares[1];

    // Earn
    (,, balances1) = vault.position(positionId1);
    (,, uint256[] memory balances2) = vault.position(positionId2);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    (uint256 positionId3,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);
    //Shares: 20
    // Total shares: 40
    shares[2] = 20;
    totalShares += shares[2];

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, uint256[] memory balances3) = vault.position(positionId3);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    // INCREASE POSITION

    vault.increasePosition(positionId1, address(erc20), amountToIncrease1);
    anotherErc20.mint(address(strategy), amountToReward);

    // UPDATE SHARES
    //Shares: 20 (+10)
    // Total shares: 50
    shares[0] += 10;
    totalShares += 10;

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, balances3) = vault.position(positionId3);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(amountToDeposit1 + amountToIncrease1, balances1[0], 1);
    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);
  }

  function testFuzz_specialWithdraw_WithERC20(uint104 amountToDeposit, uint8 percentageToWithdraw) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max));
    percentageToWithdraw = uint8(bound(percentageToWithdraw, 1, 100));
    uint256 amountToWithdraw = amountToDeposit.mulDiv(percentageToWithdraw, 100, Math.Rounding.Ceil);
    address recipient = address(18);
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    // Funds before withdraw
    (address[] memory tokens,, uint256[] memory balances) = vault.position(positionId);
    assertEq(erc20.balanceOf(address(strategy)), amountToDeposit);
    assertEq(balances[0], amountToDeposit);

    vm.prank(operator);
    vm.expectEmit();
    emit PositionWithdrawn(positionId, tokens, CommonUtils.arrayOf(amountToWithdraw), recipient);
    vault.specialWithdraw(positionId, SpecialWithdrawalCode.wrap(0), abi.encode(0, amountToWithdraw), recipient);
    // Funds after withdraw
    (,, balances) = vault.position(positionId);
    assertEq(erc20.balanceOf(recipient), amountToWithdraw);
    assertEq(erc20.balanceOf(address(strategy)), amountToDeposit - amountToWithdraw);
    assertEq(balances[0], amountToDeposit - amountToWithdraw);
  }

  function testFuzz_specialWithdraw_WithNative(uint104 amountToDeposit, uint8 percentageToWithdraw) public {
    amountToDeposit = uint104(bound(amountToDeposit, 1, type(uint104).max));
    percentageToWithdraw = uint8(bound(percentageToWithdraw, 1, 100));
    uint256 amountToWithdraw = amountToDeposit.mulDiv(percentageToWithdraw, 100, Math.Rounding.Ceil);
    vm.deal(address(this), amountToDeposit);
    address recipient = address(18);

    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    (uint256 positionId,) = vault.createPosition{ value: amountToDeposit }(
      strategyId, Token.NATIVE_TOKEN, amountToDeposit, positionOwner, permissions, misc
    );

    // Funds before withdraw
    (address[] memory tokens,, uint256[] memory balances) = vault.position(positionId);
    assertEq(address(strategy).balance, amountToDeposit);
    assertEq(balances[0], amountToDeposit);

    vm.prank(operator);
    vm.expectEmit();
    emit PositionWithdrawn(positionId, tokens, CommonUtils.arrayOf(amountToWithdraw), recipient);
    vault.specialWithdraw(positionId, SpecialWithdrawalCode.wrap(0), abi.encode(0, amountToWithdraw), recipient);

    // Funds after withdraw
    (,, balances) = vault.position(positionId);
    assertEq(recipient.balance, amountToWithdraw);
    assertEq(address(strategy).balance, amountToDeposit - amountToWithdraw);
    assertEq(balances[0], amountToDeposit - amountToWithdraw);
  }

  function test_specialWithdraw_RevertWhen_AccountWithoutPermission() public {
    uint104 amountToDeposit = 10_000;
    uint104 amountToWithdraw = 5000;

    address recipient = address(18);
    erc20.mint(address(this), amountToDeposit);
    INFTPermissions.PermissionSet[] memory permissions;
    bytes memory misc = "1234";

    (StrategyId strategyId,) = strategyRegistry.deployStateStrategy(CommonUtils.arrayOf(address(erc20)));

    (uint256 positionId,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit, positionOwner, permissions, misc);

    vault.position(positionId);

    vm.expectRevert(
      abi.encodeWithSelector(
        INFTPermissions.AccountWithoutPermission.selector, positionId, operator, vault.WITHDRAW_PERMISSION()
      )
    );
    vm.prank(operator);
    vault.specialWithdraw(positionId, SpecialWithdrawalCode.wrap(0), abi.encode(0, amountToWithdraw), recipient);
  }

  function test_specialWithdraw_CheckRewards() public {
    uint256 amountToDeposit1 = 120_000;
    uint256 amountToDeposit2 = 120_000;
    uint256 amountToDeposit3 = 240_000;
    uint256 amountToReward = 120_000;
    erc20.mint(address(this), amountToDeposit1 + amountToDeposit2 + amountToDeposit3);
    uint256[] memory rewards = new uint256[](3);
    uint256[] memory shares = new uint256[](3);
    uint256 totalShares;
    uint256 positionsCreated;
    INFTPermissions.PermissionSet[] memory permissions =
      PermissionUtils.buildPermissionSet(operator, PermissionUtils.permissions(vault.WITHDRAW_PERMISSION()));
    bytes memory misc = "1234";

    address[] memory strategyTokens = CommonUtils.arrayOf(address(erc20), address(anotherErc20));
    (StrategyId strategyId, EarnStrategyStateBalanceMock strategy) =
      strategyRegistry.deployStateStrategy(strategyTokens);

    uint256 previousBalance;

    (uint256 positionId1,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit1, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    // Shares: 10
    //Total shares: 10
    shares[0] = 10;
    totalShares = 10;

    (,, uint256[] memory balances1) = vault.position(positionId1);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);
    assertApproxEqAbs(rewards[0], balances1[1], 1);

    (uint256 positionId2,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit2, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);

    //Shares: 10
    //Total shares: 20
    shares[1] = 10;
    totalShares += shares[1];

    // Earn
    (,, balances1) = vault.position(positionId1);
    assertEq(balances1.length, 2);
    assertEq(balances1[0], amountToDeposit1);

    (,, uint256[] memory balances2) = vault.position(positionId2);
    assertEq(balances2.length, 2);
    assertEq(balances2[0], amountToDeposit2);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);

    (uint256 positionId3,) =
      vault.createPosition(strategyId, address(erc20), amountToDeposit3, positionOwner, permissions, misc);
    positionsCreated++;
    anotherErc20.mint(address(strategy), amountToReward);
    //Shares: 20
    // Total shares: 40
    shares[2] = 20;
    totalShares += shares[2];

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, uint256[] memory balances3) = vault.position(positionId3);

    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(rewards[0], balances1[1], 1);
    assertApproxEqAbs(rewards[1], balances2[1], 1);
    assertApproxEqAbs(rewards[2], balances3[1], 1);

    // WITHDRAW ONLY ASSET

    uint256 amountToWithdraw1 = 21_000;
    address recipient = address(18);
    uint256[] memory intendendWithdraw = CommonUtils.arrayOf(amountToWithdraw1, 0);

    vm.prank(operator);
    vault.specialWithdraw(positionId1, SpecialWithdrawalCode.wrap(0), abi.encode(0, amountToWithdraw1), recipient);

    // UPDATE SHARES
    //Shares: 5
    // Total shares: 35
    shares[0] -= 5;
    totalShares -= 5;

    (,, balances1) = vault.position(positionId1);
    (,, balances2) = vault.position(positionId2);
    (,, balances3) = vault.position(positionId3);
    previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsCreated);

    assertApproxEqAbs(amountToDeposit1 - amountToWithdraw1, balances1[0], 1);
    assertApproxEqAbs(rewards[0], balances1[1], 1);

    // WITHDRAW ONLY REWARDS

    intendendWithdraw[0] = 0;
    intendendWithdraw[1] = amountToWithdraw1;

    vm.prank(operator);
    vault.specialWithdraw(positionId1, SpecialWithdrawalCode.wrap(0), abi.encode(1, amountToWithdraw1), recipient);

    (,, balances1) = vault.position(positionId1);
    assertApproxEqAbs(amountToDeposit1 - amountToWithdraw1, balances1[0], 1);

    //Rewards have to be calculated with previous shares and balance
    assertApproxEqAbs(rewards[0] - intendendWithdraw[1], balances1[1], 1);
  }

  function takeSnapshotAndAssertBalances(
    uint256[][] memory balances,
    uint256[] memory positionIds,
    IEarnStrategy strategy,
    uint256 previousBalance,
    uint256 totalShares,
    uint256[] memory rewards,
    uint256[] memory shares,
    uint256 positionsLength
  )
    internal
    returns (uint256 _previousBalance)
  {
    for (uint8 i; i < positionsLength; i++) {
      (,, balances[i]) = vault.position(positionIds[i]);
    }

    _previousBalance = takeSnapshot(strategy, previousBalance, totalShares, rewards, shares, positionsLength);

    for (uint8 i; i < positionsLength; i++) {
      assertApproxEqAbs(rewards[i], balances[i][1], 2);
    }
  }

  function takeSnapshot(
    IEarnStrategy strategy,
    uint256 previousBalance,
    uint256 totalShares,
    uint256[] memory rewards,
    uint256[] memory shares,
    uint256 positionsLength
  )
    internal
    view
    returns (uint256 _previousBalance)
  {
    (, uint256[] memory strategyBalances) = strategy.totalBalances();
    _previousBalance = strategyBalances[1];
    if (strategyBalances[1] >= previousBalance) {
      for (uint256 i; i < positionsLength; i++) {
        rewards[i] += shares[i].mulDiv(strategyBalances[1] - previousBalance, totalShares, Math.Rounding.Floor);
      }
    } else {
      for (uint256 i; i < positionsLength; i++) {
        rewards[i] = strategyBalances[1].mulDiv(rewards[i], previousBalance, Math.Rounding.Ceil);
      }
    }
  }

  function checkPermissions(uint256 positionId, INFTPermissions.PermissionSet[] memory expected) internal {
    INFTPermissions.Permission increasePermission = vault.INCREASE_PERMISSION();
    INFTPermissions.Permission withdrawPermission = vault.WITHDRAW_PERMISSION();
    for (uint256 i; i < expected.length; i++) {
      bool shouldHaveIncreasePermission = expected[i].permissions.contains(increasePermission);
      bool shouldHaveWithdrawPermission = expected[i].permissions.contains(withdrawPermission);
      assertEq(vault.hasPermission(positionId, expected[i].operator, increasePermission), shouldHaveIncreasePermission);
      assertEq(vault.hasPermission(positionId, expected[i].operator, withdrawPermission), shouldHaveWithdrawPermission);
    }
  }

  function assertApproxEqAbs(uint256 a, uint256 b, uint256 maxDelta) internal virtual {
    uint256 delta = stdMath.delta(a, b);

    if (delta > maxDelta) {
      fail();
    }
  }
}

library InternalUtils {
  function contains(
    INFTPermissions.Permission[] memory permissions,
    INFTPermissions.Permission permissionToCheck
  )
    internal
    pure
    returns (bool)
  {
    for (uint256 i; i < permissions.length; i++) {
      if (INFTPermissions.Permission.unwrap(permissions[i]) == INFTPermissions.Permission.unwrap(permissionToCheck)) {
        return true;
      }
    }
    return false;
  }
}
