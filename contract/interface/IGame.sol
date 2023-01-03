// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IGame {
    function placeBet(address token, address player, uint256 betAmount, uint betChoice) external;
}