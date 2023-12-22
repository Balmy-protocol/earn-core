// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable-next-line no-unused-import
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
// solhint-disable-next-line no-unused-import
import { StrategyId, EarnStrategyDead, IEarnStrategy } from "./EarnStrategyDead.sol";
// solhint-disable-next-line no-unused-import
import { IDelayedWithdrawalAdapter } from "../../../src/interfaces/IDelayedWithdrawalAdapter.sol";
import { Token, IERC20, Address } from "../../../src/libraries/Token.sol";
import { DelayedWithdrawalAdapterMock } from "../delayed-withdrawal-adapter/DelayedWithdrawalAdapterMock.sol";
import { SpecialWithdrawalCode } from "../../../src/types/SpecialWithdrawals.sol";

/// @notice An implementation of IEarnStrategy that returns balances by reading token's state
contract EarnStrategyStateBalanceMock is EarnStrategyDead {
  using Token for address;

  address[] internal tokens;
  WithdrawalType[] internal withdrawalTypes;
  mapping(address token => IDelayedWithdrawalAdapter adapter) public override delayedWithdrawalAdapter;

  constructor(address[] memory tokens_, WithdrawalType[] memory withdrawalTypes_) {
    require(tokens_.length == withdrawalTypes_.length, "Invalid");
    tokens = tokens_;
    withdrawalTypes = withdrawalTypes_;
    for (uint256 i; i < tokens_.length; ++i) {
      delayedWithdrawalAdapter[tokens_[i]] = new DelayedWithdrawalAdapterMock();
    }
  }

  function asset() external view override returns (address) {
    return tokens[0];
  }

  function supportedWithdrawals() external view override returns (WithdrawalType[] memory) {
    return withdrawalTypes;
  }

  function totalBalances() external view virtual override returns (address[] memory tokens_, uint256[] memory balances) {
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

  function withdraw(
    uint256,
    address[] memory tokens_,
    uint256[] memory toWithdraw,
    address recipient
  )
    external
    override
    returns (WithdrawalType[] memory)
  {
    for (uint256 i; i < tokens_.length; i++) {
      if (tokens_[i] == Token.NATIVE_TOKEN) {
        Address.sendValue(payable(recipient), toWithdraw[i]);
      } else {
        IERC20(tokens_[i]).transfer(recipient, toWithdraw[i]);
      }
    }
    return withdrawalTypes;
  }

  function specialWithdraw(
    uint256,
    SpecialWithdrawalCode,
    bytes calldata withdrawData,
    address recipient
  )
    external
    override
    returns (uint256[] memory withdrawn, WithdrawalType[] memory, bytes memory)
  {
    // Withdraw specific token
    (uint256 tokenIndex, uint256 toWithdraw) = abi.decode(withdrawData, (uint256, uint256));
    if (tokens[tokenIndex] == Token.NATIVE_TOKEN) {
      Address.sendValue(payable(recipient), toWithdraw);
    } else {
      IERC20(tokens[tokenIndex]).transfer(recipient, toWithdraw);
    }
    withdrawn = new uint256[](tokens.length);
    withdrawn[tokenIndex] = toWithdraw;
  }

  function migrateToNewStrategy(IEarnStrategy newStrategy) external virtual override returns (bytes memory) {
    (, uint256[] memory balances) = this.totalBalances();
    for (uint256 i; i < tokens.length; ++i) {
      if (tokens[i] == Token.NATIVE_TOKEN) {
        Address.sendValue(payable(address(newStrategy)), balances[i]);
      } else {
        IERC20(tokens[i]).transfer(address(newStrategy), balances[i]);
      }
    }
  }

  function strategyRegistered(StrategyId, IEarnStrategy, bytes calldata) external override { }
}
