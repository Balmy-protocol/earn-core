// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20NoopMock is IERC20 {
  function totalSupply() external pure returns (uint256) {
    return 0;
  }

  function balanceOf(address) external pure returns (uint256) {
    return 0;
  }

  function transfer(address, uint256) external pure returns (bool) {
    return true;
  }

  function allowance(address, address) external pure returns (uint256) {
    return type(uint256).max;
  }

  function approve(address, uint256) external pure returns (bool) {
    return true;
  }

  function transferFrom(address, address, uint256) external pure returns (bool) {
    return true;
  }
}
