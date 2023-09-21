// SPDX-License-Identifier: TBD
pragma solidity >=0.8.0;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library Token {
  using SafeERC20 for IERC20;
  using Address for address payable;

  /// @notice Thrown when using the native token for an operation that does not support it
  error OperationNotSupportedForNativeToken();

  address internal constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /**
   * @notice Returns the amount of balance held by the account, for the given token
   * @param token The token to check the balance for
   * @return The amount of balance held by the account, for the given token
   */
  function balanceOf(address token, address account) internal view returns (uint256) {
    return token == NATIVE_TOKEN ? account.balance : IERC20(token).balanceOf(account);
  }

  /**
   * @notice If the specified token is an ERC20, this function will transfer tokens from the msg.sender to the
   *         recipient. If it's the native token, then it will simply send the tokens current on the contract
   * @param token The token to transfer
   * @param recipient The recipient of the tokens
   * @param amount The amount of tokens to transfer
   */
  function transferIfNativeOrTransferFromIfERC20(address token, address recipient, uint256 amount) internal {
    if (amount > 0) {
      if (token == NATIVE_TOKEN) {
        Address.sendValue(payable(recipient), amount);
      } else {
        IERC20(token).safeTransferFrom(msg.sender, recipient, amount);
      }
    }
  }

  /**
   * @notice Reverts if the given token is the native token
   * @param token The token to check
   */
  function assertNonNative(address token) internal pure {
    if (token == NATIVE_TOKEN) {
      revert OperationNotSupportedForNativeToken();
    }
  }
}
