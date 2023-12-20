// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnStrategyRegistry, IEarnStrategyRegistry } from "../../../src/strategy-registry/EarnStrategyRegistry.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { StrategyUtils } from "../../utils/StrategyUtils.sol";
import { StrategyId, StrategyIdConstants } from "../../../src/types/StrategyId.sol";
import { Token } from "../../../src/libraries/Token.sol";

import { IEarnStrategy } from "../../../src/interfaces/IEarnStrategy.sol";
import { EarnStrategyBadMock } from "../../mocks/strategies/EarnStrategyBadMock.sol";
import { EarnStrategyStateBalanceMock } from "../../mocks/strategies/EarnStrategyStateBalanceMock.sol";

contract EarnStrategyRegistryTest is PRBTest {
  event StrategyRegistered(address owner, StrategyId strategyId, IEarnStrategy strategy);
  event StrategyUpdateProposed(StrategyId strategyId, IEarnStrategy strategy);
  event StrategyUpdateCanceled(StrategyId strategyId);
  event StrategyUpdated(StrategyId strategyId, IEarnStrategy strategy);
  event StrategyOwnershipTransferProposed(StrategyId strategyId, address newOwner);
  event StrategyOwnershipTransferCanceled(StrategyId strategyId, address receiver);
  event StrategyOwnershipTransferred(StrategyId strategyId, address newOwner);

  EarnStrategyRegistry private strategyRegistry;
  StrategyId private invalidStrategyId = StrategyId.wrap(1000);
  StrategyId private anotherInvalidStrategyId = StrategyId.wrap(1001);
  address private owner = address(1);

  function setUp() public virtual {
    strategyRegistry = new EarnStrategyRegistry();
  }

  function test_getStrategy_ShouldReturnZero_WhenNonExistentStrategyId() public {
    assertEq(address(strategyRegistry.getStrategy(invalidStrategyId)), address(0));
  }

  function test_registerStrategy() public {
    IEarnStrategy aStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectEmit();
    emit StrategyRegistered(owner, StrategyIdConstants.INITIAL_STRATEGY_ID, aStrategy);

    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    assertEq(address(strategyRegistry.getStrategy(aRegisteredStrategyId)), address(aStrategy));
    assertEq(owner, strategyRegistry.owner(aRegisteredStrategyId));
    assertTrue(strategyRegistry.assignedId(aStrategy) == aRegisteredStrategyId);
    assertGt(StrategyId.unwrap(aRegisteredStrategyId), StrategyId.unwrap(StrategyIdConstants.NO_STRATEGY));
  }

  function test_registerStrategy_RevertWhen_StrategyIsAlreadyRegistered() public {
    IEarnStrategy aStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    strategyRegistry.registerStrategy(owner, aStrategy);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.StrategyAlreadyRegistered.selector));
    strategyRegistry.registerStrategy(owner, aStrategy);
  }

  function test_registerStrategy_RevertWhen_AssetIsNotFirstToken() public {
    address[] memory tokens = new address[](2);
    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(1);
    IEarnStrategy badStrategy = new EarnStrategyBadMock(tokens);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AssetIsNotFirstToken.selector, badStrategy));
    strategyRegistry.registerStrategy(owner, badStrategy);
  }

  function test_registerStrategy_RevertWhen_AddressIsNotStrategy() public {
    IEarnStrategy badStrategy;
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AddressIsNotStrategy.selector, badStrategy));
    strategyRegistry.registerStrategy(owner, badStrategy);
  }

  function test_registerStrategy_MultipleStrategiesRegistered() public {
    IEarnStrategy aStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    IEarnStrategy anotherStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    StrategyId aRegisteredStrategyId = strategyRegistry.registerStrategy(owner, aStrategy);
    StrategyId anotherRegisteredStrategyId = strategyRegistry.registerStrategy(owner, anotherStrategy);

    assertNotEq(
      address(strategyRegistry.getStrategy(aRegisteredStrategyId)),
      address(strategyRegistry.getStrategy(anotherRegisteredStrategyId))
    );
    assertFalse(strategyRegistry.assignedId(aStrategy) == strategyRegistry.assignedId(anotherStrategy));
  }

  function test_proposeStrategyUpdate() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    IEarnStrategy anotherStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectEmit();
    emit StrategyUpdateProposed(aRegisteredStrategyId, anotherStrategy);
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
    (IEarnStrategy proposedStrategy, uint256 executableAt) = strategyRegistry.proposedUpdate(aRegisteredStrategyId);
    assertEq(address(proposedStrategy), address(anotherStrategy));
    assertEq(executableAt, block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY());
  }

  function test_proposeStrategyUpdate_UpdateWithMoreTokens() public {
    address[] memory strategyTokens = new address[](2);
    strategyTokens[0] = Token.NATIVE_TOKEN;
    strategyTokens[1] = address(1);

    (, StrategyId aRegisteredStrategyId) = StrategyUtils.deployStateStrategy(strategyRegistry, strategyTokens, owner);

    address[] memory newStrategyTokens = new address[](2);
    newStrategyTokens[0] = Token.NATIVE_TOKEN;
    newStrategyTokens[1] = address(2);
    newStrategyTokens[1] = address(1);
    EarnStrategyStateBalanceMock anotherStrategy = StrategyUtils.deployStateStrategy(newStrategyTokens);

    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_WrongOwner() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    EarnStrategyStateBalanceMock anotherStrategy =
      StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    address anotherOwner = address(2);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.UnauthorizedStrategyOwner.selector));
    vm.prank(anotherOwner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_StrategyAlreadyProposedUpdate() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    EarnStrategyStateBalanceMock newStrategy =
      StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, newStrategy);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.StrategyAlreadyProposedUpdate.selector));
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, newStrategy);
    vm.stopPrank();
  }

  function test_proposeStrategyUpdate_RevertWhen_StrategyAlreadyRegistered() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    (EarnStrategyStateBalanceMock anotherStrategy,) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.StrategyAlreadyRegistered.selector));
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_StrategyAlreadyRegistered_InAnotherProposedUpdate() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    (, StrategyId anotherRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    EarnStrategyStateBalanceMock newStrategy =
      StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, newStrategy);

    // The strategy 'newStrategy' was proposed to another strategyId
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.StrategyAlreadyRegistered.selector));
    strategyRegistry.proposeStrategyUpdate(anotherRegisteredStrategyId, newStrategy);
    vm.stopPrank();
  }

  function test_proposeStrategyUpdate_RevertWhen_TokensSupportedMismatch() public {
    address[] memory tokens = new address[](2);
    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(1);

    (, StrategyId aRegisteredStrategyId) = StrategyUtils.deployStateStrategy(strategyRegistry, tokens, owner);

    EarnStrategyStateBalanceMock anotherStrategy =
      StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.TokensSupportedMismatch.selector));
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_AssetMismatch() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(address(1)), owner);

    EarnStrategyStateBalanceMock anotherStrategy =
      StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AssetMismatch.selector));
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_AddressIsNotStrategy() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    IEarnStrategy badStrategy;

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AddressIsNotStrategy.selector, badStrategy));
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, badStrategy);
  }

  function test_proposeStrategyUpdate_RevertWhen_AssetIsNotFirstToken() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    address[] memory tokens = new address[](2);
    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(1);
    IEarnStrategy badStrategy = new EarnStrategyBadMock(tokens);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.AssetIsNotFirstToken.selector, badStrategy));
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, badStrategy);
  }

  function test_cancelStrategyUpdate() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    EarnStrategyStateBalanceMock anotherStrategy =
      StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
    vm.expectEmit();
    emit StrategyUpdateCanceled(aRegisteredStrategyId);
    strategyRegistry.cancelStrategyUpdate(aRegisteredStrategyId);

    // and can propose same strategy update again
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
    vm.stopPrank();
  }

  function test_cancelStrategyUpdate_RevertWhen_WrongOwner() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    EarnStrategyStateBalanceMock anotherStrategy =
      StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);

    address anotherOwner = address(2);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.UnauthorizedStrategyOwner.selector));
    vm.prank(anotherOwner);
    strategyRegistry.cancelStrategyUpdate(aRegisteredStrategyId);
  }

  function test_cancelStrategyUpdate_RevertWhen_MissingStrategyProposedUpdate() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    vm.prank(owner);
    vm.expectRevert(
      abi.encodeWithSelector(IEarnStrategyRegistry.MissingStrategyProposedUpdate.selector, aRegisteredStrategyId)
    );
    strategyRegistry.cancelStrategyUpdate(aRegisteredStrategyId);
  }

  function test_cancelStrategyUpdate_RevertWhen_MissingStrategyProposedUpdate_AlreadyCanceled() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    EarnStrategyStateBalanceMock anotherStrategy =
      StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);
    vm.expectEmit();
    emit StrategyUpdateCanceled(aRegisteredStrategyId);
    strategyRegistry.cancelStrategyUpdate(aRegisteredStrategyId);

    vm.expectRevert(
      abi.encodeWithSelector(IEarnStrategyRegistry.MissingStrategyProposedUpdate.selector, aRegisteredStrategyId)
    );
    strategyRegistry.cancelStrategyUpdate(aRegisteredStrategyId);
    vm.stopPrank();
  }

  function test_updateStrategy() public {
    (EarnStrategyStateBalanceMock oldStrategy, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    IEarnStrategy newStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, newStrategy);

    vm.warp(block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY()); //Waiting for the delay...

    vm.expectEmit();
    emit StrategyUpdated(aRegisteredStrategyId, newStrategy);
    strategyRegistry.updateStrategy(aRegisteredStrategyId);
    vm.stopPrank();

    //The strategy was updated
    assertEq(address(newStrategy), address(strategyRegistry.getStrategy(aRegisteredStrategyId)));
    assertTrue(strategyRegistry.assignedId(newStrategy) == aRegisteredStrategyId);

    //Old strategy was removed
    assertTrue(strategyRegistry.assignedId(oldStrategy) == StrategyIdConstants.NO_STRATEGY);

    // The Strategy ID doesn't have any proposed update
    (, uint256 executableAt) = strategyRegistry.proposedUpdate(aRegisteredStrategyId);
    assertEq(executableAt, 0);
  }

  function test_updateStrategy_RevertWhen_WrongOwner() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    IEarnStrategy anotherStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    vm.prank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);

    vm.warp(block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY()); //Waiting for the delay...

    address anotherOwner = address(2);
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.UnauthorizedStrategyOwner.selector));
    vm.prank(anotherOwner);
    strategyRegistry.updateStrategy(aRegisteredStrategyId);
  }

  function test_updateStrategy_RevertWhen_StrategyUpdateBeforeDelay() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    IEarnStrategy anotherStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, anotherStrategy);

    vm.expectRevert(
      abi.encodeWithSelector(IEarnStrategyRegistry.StrategyUpdateBeforeDelay.selector, aRegisteredStrategyId)
    );
    strategyRegistry.updateStrategy(aRegisteredStrategyId);

    vm.warp(block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY() - 1);

    vm.expectRevert(
      abi.encodeWithSelector(IEarnStrategyRegistry.StrategyUpdateBeforeDelay.selector, aRegisteredStrategyId)
    );
    strategyRegistry.updateStrategy(aRegisteredStrategyId);

    vm.stopPrank();
  }

  function test_updateStrategy_RevertWhen_MissingStrategyProposedUpdate() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    vm.expectRevert(
      abi.encodeWithSelector(IEarnStrategyRegistry.MissingStrategyProposedUpdate.selector, aRegisteredStrategyId)
    );
    vm.prank(owner);
    strategyRegistry.updateStrategy(aRegisteredStrategyId);
  }

  function test_updateStrategy_RevertWhen_MissingStrategyProposedUpdate_AfterStrategyUpdate() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    IEarnStrategy newStrategy = StrategyUtils.deployStateStrategy(CommonUtils.arrayOf(Token.NATIVE_TOKEN));
    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(aRegisteredStrategyId, newStrategy);

    vm.warp(block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY()); //Waiting for the delay...

    strategyRegistry.updateStrategy(aRegisteredStrategyId);

    vm.expectRevert(
      abi.encodeWithSelector(IEarnStrategyRegistry.MissingStrategyProposedUpdate.selector, aRegisteredStrategyId)
    );
    strategyRegistry.updateStrategy(aRegisteredStrategyId);
    vm.stopPrank();
  }

  function test_proposeOwnershipTransfer() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    address newOwner = address(2);

    vm.prank(owner);
    vm.expectEmit();
    emit StrategyOwnershipTransferProposed(aRegisteredStrategyId, newOwner);
    strategyRegistry.proposeOwnershipTransfer(aRegisteredStrategyId, newOwner);

    assertEq(strategyRegistry.proposedOwnershipTransfer(aRegisteredStrategyId), newOwner);
    assertEq(strategyRegistry.owner(aRegisteredStrategyId), owner);
  }

  function test_proposeOwnershipTransfer_RevertWhen_UnauthorizedStrategyOwner() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    address newOwner = address(2);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.UnauthorizedStrategyOwner.selector));
    strategyRegistry.proposeOwnershipTransfer(aRegisteredStrategyId, newOwner);
  }

  function test_proposeOwnershipTransfer_RevertWhen_StrategyOwnershipTransferAlreadyProposed() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    address newOwner = address(2);
    vm.startPrank(owner);

    strategyRegistry.proposeOwnershipTransfer(aRegisteredStrategyId, newOwner);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.StrategyOwnershipTransferAlreadyProposed.selector));
    strategyRegistry.proposeOwnershipTransfer(aRegisteredStrategyId, newOwner);
    vm.stopPrank();
  }

  function test_cancelOwnershipTransfer() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    address newOwner = address(2);

    vm.startPrank(owner);
    strategyRegistry.proposeOwnershipTransfer(aRegisteredStrategyId, newOwner);

    vm.expectEmit();
    emit StrategyOwnershipTransferCanceled(aRegisteredStrategyId, newOwner);
    strategyRegistry.cancelOwnershipTransfer(aRegisteredStrategyId);
    vm.stopPrank();

    assertEq(strategyRegistry.proposedOwnershipTransfer(aRegisteredStrategyId), address(0));
    assertEq(strategyRegistry.owner(aRegisteredStrategyId), owner);
  }

  function test_cancelOwnershipTransfer_RevertWhen_StrategyOwnershipTransferWithoutPendingProposal() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    vm.prank(owner);
    vm.expectRevert(
      abi.encodeWithSelector(IEarnStrategyRegistry.StrategyOwnershipTransferWithoutPendingProposal.selector)
    );
    strategyRegistry.cancelOwnershipTransfer(aRegisteredStrategyId);
  }

  function test_cancelOwnershipTransfer_RevertWhen_UnauthorizedStrategyOwner() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.UnauthorizedStrategyOwner.selector));
    strategyRegistry.cancelOwnershipTransfer(aRegisteredStrategyId);
  }

  function test_acceptOwnershipTransfer() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    address newOwner = address(2);

    vm.prank(owner);
    strategyRegistry.proposeOwnershipTransfer(aRegisteredStrategyId, newOwner);

    vm.prank(newOwner);
    vm.expectEmit();
    emit StrategyOwnershipTransferred(aRegisteredStrategyId, newOwner);
    strategyRegistry.acceptOwnershipTransfer(aRegisteredStrategyId);

    assertEq(strategyRegistry.owner(aRegisteredStrategyId), newOwner);
    assertEq(strategyRegistry.proposedOwnershipTransfer(aRegisteredStrategyId), address(0));
  }

  function test_acceptOwnershipTransfer_RevertWhen_UnauthorizedOwnershipReceiver_WithoutProposal() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);

    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.UnauthorizedOwnershipReceiver.selector));
    strategyRegistry.acceptOwnershipTransfer(aRegisteredStrategyId);
  }

  function test_acceptOwnershipTransfer_RevertWhen_UnauthorizedOwnershipReceiver_WithoutPermission() public {
    (, StrategyId aRegisteredStrategyId) =
      StrategyUtils.deployStateStrategy(strategyRegistry, CommonUtils.arrayOf(Token.NATIVE_TOKEN), owner);
    address newOwner = address(2);
    address anotherOwner = address(3);

    vm.prank(owner);
    strategyRegistry.proposeOwnershipTransfer(aRegisteredStrategyId, newOwner);

    vm.prank(anotherOwner);
    vm.expectRevert(abi.encodeWithSelector(IEarnStrategyRegistry.UnauthorizedOwnershipReceiver.selector));
    strategyRegistry.acceptOwnershipTransfer(aRegisteredStrategyId);
  }
}
