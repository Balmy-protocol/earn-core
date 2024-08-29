// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IEarnStrategyRegistry, IEarnStrategy, StrategyId } from "../../../src/interfaces/IEarnStrategyRegistry.sol";

contract EarnStrategyRegistryMock is IEarnStrategyRegistry {
  error NotImplemented();

  uint256 public constant STRATEGY_UPDATE_DELAY = 0;

  mapping(StrategyId strategyId => IEarnStrategy strategy) public getStrategy;
  mapping(IEarnStrategy strategy => StrategyId strategyId) public assignedId;
  uint96 internal _nextStrategyId = 1;

  function registerStrategy(address, IEarnStrategy strategy) external returns (StrategyId strategyId) {
    strategyId = StrategyId.wrap(_nextStrategyId++);
    assignedId[strategy] = strategyId;
    getStrategy[strategyId] = strategy;
  }

  function totalRegistered() external pure returns (uint256) {
    revert NotImplemented();
  }

  function proposedUpdate(StrategyId) external pure returns (IEarnStrategy, uint96, bytes32) {
    revert NotImplemented();
  }

  function proposedOwnershipTransfer(StrategyId) external pure returns (address) {
    revert NotImplemented();
  }

  function proposeOwnershipTransfer(StrategyId, address) external pure {
    revert NotImplemented();
  }

  function cancelOwnershipTransfer(StrategyId) external pure {
    revert NotImplemented();
  }

  function acceptOwnershipTransfer(StrategyId) external pure {
    revert NotImplemented();
  }

  function proposeStrategyUpdate(StrategyId, IEarnStrategy, bytes calldata) external pure {
    revert NotImplemented();
  }

  function cancelStrategyUpdate(StrategyId) external pure {
    revert NotImplemented();
  }

  function updateStrategy(StrategyId, bytes calldata) external pure {
    revert NotImplemented();
  }

  function owner(StrategyId) external pure returns (address) {
    revert NotImplemented();
  }
}
