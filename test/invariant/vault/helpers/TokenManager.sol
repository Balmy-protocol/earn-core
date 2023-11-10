// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20NoopMock } from "../../../mocks/ERC20/ERC20NoopMock.sol";

contract TokenManager {
  error ListAlreadyContainsAllTokens();

  address[] private _tokens;

  constructor(uint256 tokensToDeploy) {
    for (uint256 i; i < tokensToDeploy; i++) {
      _tokens.push(address(new ERC20NoopMock()));
    }
  }

  function allTokens() external view returns (address[] memory) {
    return _tokens;
  }

  function getRandomToken() external view returns (address) {
    return _tokens[(block.timestamp + gasleft()) % _tokens.length];
  }

  function getTokenNotInList(address[] memory list) external view returns (address) {
    // slither-disable-next-line cache-array-length
    for (uint256 i; i < _tokens.length; i++) {
      bool found = false;
      for (uint256 j; j < list.length && !found; j++) {
        found = _tokens[i] == list[j];
      }
      if (!found) {
        return _tokens[i];
      }
    }
    revert ListAlreadyContainsAllTokens();
  }
}
