// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {
  IEarnStrategy,
  StrategyId,
  IEarnVault,
  IEarnStrategyRegistry,
  SpecialWithdrawalCode,
  IDelayedWithdrawalAdapter
} from "../../src/interfaces/IEarnStrategy.sol";
import { Token } from "../../src/libraries/Token.sol";
// solhint-disable-next-line no-unused-import
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract EarnStrategyBadMock is IEarnStrategy {
  using Token for address;

  error NotImplemented();

  address[] internal tokens;
  WithdrawalType[] internal withdrawalTypes;

  constructor(address[] memory tokens_) {
    tokens = tokens_;
    withdrawalTypes = new WithdrawalType[](0);
  }

  // solhint-disable-next-line no-empty-blocks
  receive() external payable { }

  function asset() external view returns (address) {
    return tokens[1];
  }

  function supportedWithdrawals() external view returns (WithdrawalType[] memory) {
    return withdrawalTypes;
  }

  function totalBalances() external view returns (address[] memory, uint256[] memory) {
    revert NotImplemented();
  }

  function deposited(address, uint256 depositAmount) external payable returns (uint256 assetsDeposited) {
    return depositAmount;
  }

  function isDepositTokenSupported(address) external pure returns (bool) {
    return true;
  }

  function isSpecialWithdrawalSupported(SpecialWithdrawalCode) external pure returns (bool) {
    return true;
  }

  function paused() external pure returns (bool) {
    return false;
  }

  function vault() external pure returns (IEarnVault) {
    revert NotImplemented();
  }

  function registry() external pure returns (IEarnStrategyRegistry) {
    revert NotImplemented();
  }

  function description() external pure returns (string memory) {
    revert NotImplemented();
  }

  function allTokens() external view returns (address[] memory, WithdrawalType[] memory) {
    return (tokens, withdrawalTypes);
  }

  function supportedDepositTokens() external pure returns (address[] memory) {
    revert NotImplemented();
  }

  function maxDeposit(address) external pure returns (uint256) {
    revert NotImplemented();
  }

  function balancesInStrategy() external pure returns (address[] memory, uint256[] memory) {
    revert NotImplemented();
  }

  function balancesInFarms() external pure returns (address[] memory, uint256[] memory) {
    revert NotImplemented();
  }

  function supportedSpecialWithdrawals() external pure returns (SpecialWithdrawalCode[] memory) {
    revert NotImplemented();
  }

  function maxWithdraw() external pure returns (address[] memory, uint256[] memory) {
    revert NotImplemented();
  }

  function delayedWithdrawalAdapter(address) external pure returns (IDelayedWithdrawalAdapter) {
    revert NotImplemented();
  }

  function fees() external pure returns (address[] memory, FeeType[] memory, uint16[] memory) {
    revert NotImplemented();
  }

  function withdraw(
    uint256,
    address[] memory,
    uint256[] memory,
    address
  )
    external
    pure
    returns (WithdrawalType[] memory)
  {
    revert NotImplemented();
  }

  function specialWithdraw(
    uint256,
    SpecialWithdrawalCode,
    bytes calldata,
    address
  )
    external
    pure
    returns (uint256[] memory, WithdrawalType[] memory, bytes memory)
  {
    revert NotImplemented();
  }

  function migrateToNewStrategy(IEarnStrategy) external pure returns (bytes memory) {
    revert NotImplemented();
  }

  function strategyRegistered(StrategyId, IEarnStrategy, bytes calldata) external pure {
    revert NotImplemented();
  }

  function withdrawAllFromFarms() external pure {
    revert NotImplemented();
  }

  function pause() external pure {
    revert NotImplemented();
  }

  function unpause() external pure {
    revert NotImplemented();
  }

  function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
    return interfaceId == type(IEarnStrategy).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}
