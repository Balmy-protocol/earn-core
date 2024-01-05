// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { EarnStrategyStateBalanceMock } from "../test/mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
/// @notice An implementation of IEarnStrategy, without token migration

contract EarnStrategyStateBalanceWithSignatureMock is EarnStrategyStateBalanceMock {
  event TermsAndConditions(string);

  error InvalidTermsAndConditions();

  bytes32 public immutable termsAndConditionsHash;

  constructor(
    address[] memory tokens_,
    WithdrawalType[] memory withdrawalTypes_,
    bytes memory _termsAndConditions
  )
    EarnStrategyStateBalanceMock(tokens_, withdrawalTypes_)
  {
    emit TermsAndConditions(string(_termsAndConditions));
    termsAndConditionsHash = MessageHashUtils.toEthSignedMessageHash(_termsAndConditions);
  }

  function validatePosition(address sender, bytes calldata signature) external view override returns (bool) {
    if (sender != ECDSA.recover(termsAndConditionsHash, signature)) revert InvalidTermsAndConditions();
    return true;
  }
}
