// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

type SpecialWithdrawalCode is uint256;

/**
 * @title Special withdrawals
 * @notice There are some cases where we might want to perform a special withdrawal. For example, if a
 *         token only supports a delayed withdrawal, we might want to withdraw the farm token directly and
 *         sell it on the market, instead of waiting for the normal process.
 *         Since each strategy could support different types of withdrawals, we need to define a "protocol"
 *         on how to execute and interpret each of them. Input and output are encoded as bytes, in here we'll
 *         specify how to encode/decode them.
 */
library SpecialWithdrawal {
  /*
   * Withdraws the asset's farm token directly, by specifying the amount of farm tokens to withdraw
   * Input: 
   * - uint256: amount of farm tokens to withdraw
   * Output: 
   * - uint256: amount of assets withdrawn
   */
  SpecialWithdrawalCode internal constant WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT = SpecialWithdrawalCode.wrap(0);

  /*
   * Withdraws the asset's farm token directly, by specifying the equivalent in terms of the asset
   * Input: 
   * - uint256: amount of assets to withdraw
   * Output: 
   * - uint256: amount of farm tokens withdrawn
   */
  SpecialWithdrawalCode internal constant WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT = SpecialWithdrawalCode.wrap(1);
}
