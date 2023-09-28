// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// solhint-disable-next-line no-unused-import
import { IEarnStrategy } from "../../../src/interfaces/IEarnStrategy.sol";
// solhint-disable-next-line no-unused-import
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { EarnStrategyDead } from "./EarnStrategyDead.sol";

/// @notice This strategy is invalid because the asset must be the first token
contract EarnStrategyBadMock is EarnStrategyDead {
  address[] internal tokens;

  constructor(address[] memory tokens_) {
    tokens = tokens_;
  }

  function asset() external view override returns (address) {
    return tokens[1];
  }

  function allTokens() external view override returns (address[] memory, WithdrawalType[] memory) {
    return (tokens, new WithdrawalType[](tokens.length));
  }

  function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
    return interfaceId == type(IEarnStrategy).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}
