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
import { EarnStrategyStateBalanceMock } from "../../mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { EarnStrategyRegistryMock } from "../../mocks/strategies/EarnStrategyRegistryMock.sol";
import { ERC20MintableBurnableMock } from "../../mocks/ERC20/ERC20MintableBurnableMock.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";

contract EarnVaultTest is PRBTest, StdUtils {
  event PositionCreated(
    uint256 positionId,
    StrategyId strategyId,
    uint256 assetsDeposited,
    address owner,
    INFTPermissions.PermissionSet[] permissions,
    bytes misc
  );

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
    vault = new EarnVault(
      strategyRegistry,
      superAdmin,
      CommonUtils.arrayOf(pauseAdmin)
    );

    erc20.approve(address(vault), type(uint256).max);
    anotherErc20.approve(address(vault), type(uint256).max);

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

    uint256 yielded = (strategyBalances[1] - previousBalance) / totalShares;
    _previousBalance = strategyBalances[1];

    for (uint256 i; i < positionsLength; i++) {
      rewards[i] += shares[i] * (yielded);
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
