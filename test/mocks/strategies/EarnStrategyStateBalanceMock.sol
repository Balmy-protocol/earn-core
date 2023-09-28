// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable-next-line no-unused-import
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
// solhint-disable-next-line no-unused-import
import { EarnStrategyDead, IEarnStrategy } from "./EarnStrategyDead.sol";
import { Token } from "../../../src/libraries/Token.sol";

/// @notice An implementation of IEarnStrategy that returns balances by reading token's state
contract EarnStrategyStateBalanceMock is EarnStrategyDead {
  using Token for address;

  address[] internal tokens;
  WithdrawalType[] internal withdrawalTypes;

  constructor(address[] memory tokens_, WithdrawalType[] memory withdrawalTypes_) {
    require(tokens_.length == withdrawalTypes_.length, "Invalid");
    tokens = tokens_;
    withdrawalTypes = withdrawalTypes_;
  }

  function asset() external view override returns (address) {
    return tokens[0];
  }

  function supportedWithdrawals() external view override returns (WithdrawalType[] memory) {
    return withdrawalTypes;
  }

  function totalBalances() external view override returns (address[] memory tokens_, uint256[] memory balances) {
    tokens_ = tokens;
    balances = new uint256[](tokens.length);
    for (uint256 i; i < balances.length; i++) {
      balances[i] = tokens_[i].balanceOf(address(this));
    }
  }

  function deposited(address, uint256 depositAmount) external payable override returns (uint256 assetsDeposited) {
    return depositAmount;
  }

  function allTokens() external view override returns (address[] memory, WithdrawalType[] memory) {
    return (tokens, withdrawalTypes);
  }

  function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
    return interfaceId == type(IEarnStrategy).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}
