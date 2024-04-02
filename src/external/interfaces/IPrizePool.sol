/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

interface IPrizePool {
    function contributePrizeTokens(address _prizeVault, uint256 _amount) external returns (uint256);
    function prizeToken() external view returns (IERC20);
}
