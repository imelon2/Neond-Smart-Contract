// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interface/IHouse.sol";

contract House is IHouse,Ownable  {
    using SafeERC20 for IERC20;

    struct Token {
        bool allowed;
        uint256 maxRiskRatio;
        uint256 lockedInBets;
        uint256 minBetAmount;
        int profit;
    }

    bool public houseIsLive = true;

    mapping(address => Token) public tokens;
    mapping(address => bool) private game;

    error HouseNotLive();
    error NotGame();
    error AmountExeceedsLimit();


    event SetAllowedToken(address indexed token,bool allowed);
    event SetTokenMinBetAmount(address indexed token,uint tokenMinBetAmount);
    event SetMaxRiskRatio(address indexed token, uint maxRiskRatio);
    event InitToken(address indexed token, uint maxRiskRatio,uint minBetAmount);
    event SendToken(address indexed recipient,address indexed token, uint amount);

    modifier IsHouseLive {
        if(!houseIsLive) {
            revert HouseNotLive();
        }
        _;
    }

    modifier IsGame {
        if(!game[msg.sender]) {
            revert NotGame();
        }
        _;
    }
    
    // init
    function initToken(address token,uint256 maxRiskRatio,uint256 minBetAmount)
        external 
        onlyOwner 
    {
        tokens[token].maxRiskRatio = maxRiskRatio;
        tokens[token].minBetAmount = minBetAmount;
        if(!tokens[token].allowed) {
            tokens[token].allowed = true;    
        }
        emit InitToken(token,maxRiskRatio,minBetAmount);
    }

    // Management
    function toggleHouseIsLive() external onlyOwner {
        houseIsLive = !houseIsLive;
    }

    function addGame(address _address) external onlyOwner {
        game[_address] = true;
    }

    function removeGame(address _address) external onlyOwner {
        game[_address] = false;
    }

    // Setter
    function setTokenMaxRiskRatio(address token, uint256 maxRiskRatio)
        external
        onlyOwner
    {
        tokens[token].maxRiskRatio = maxRiskRatio;
        emit SetMaxRiskRatio(token, maxRiskRatio);
    }

    function setTokenMinBetAmount(address token, uint256 tokenMinBetAmount)
        external
        onlyOwner
    {
        tokens[token].minBetAmount = tokenMinBetAmount;
        emit SetTokenMinBetAmount(token, tokenMinBetAmount);
    }

    function setAllowedToken(address token, bool allowed)
        external
        onlyOwner
    {
        tokens[token].allowed = allowed;
        emit SetAllowedToken(token, allowed);
    }

    // Getter
    function isAllowedToken(address token) public view returns(bool) {
        return tokens[token].allowed;
    }

    function getMinBetAmount(address token) external view returns(uint256 minBetAmount) {
        minBetAmount = tokens[token].minBetAmount;
    }

    function getMaxBetAmount(address token,uint256 multiplier) external view returns(uint256) {
        return (getBalance(token) * tokens[token].maxRiskRatio) / multiplier;
    }

    function getBalance(address token) public view returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getAvailableBalamce(address token) public view returns(uint256) {
        return getBalance(token) - tokens[token].lockedInBets;
    }

    // Method
    function palceBet(address token,address player,uint betAmount,uint winnableAmount) external IsHouseLive IsGame {

        // Need player approve
        IERC20(token).safeTransferFrom(player, address(this), betAmount);
        tokens[token].lockedInBets += winnableAmount;
    }

    function settleBet(address token,address player, uint betAmount,uint winnableAmount, bool win) external IsGame {
        if (win == true) {
            tokens[token].profit -= int(winnableAmount) - int(betAmount);
            _sendToken(player,token,winnableAmount);
        } else {
            tokens[token].profit += int(betAmount);
        }
        tokens[token].lockedInBets -= winnableAmount;
    }

    function refundBet(address token,address player, uint amount, uint winnableAmount) external IsHouseLive IsGame {
        tokens[token].lockedInBets -= winnableAmount;
        _sendToken(player, token, amount);
    }

    function _sendToken(address recipient,address token,uint amount) private {
        IERC20(token).safeTransfer(recipient, amount);
    } 
    
    function sendToken(address recipient,address token,uint amount) external onlyOwner {
        if(getAvailableBalamce(token) < amount) {
            revert AmountExeceedsLimit();
        }
        _sendToken(recipient,token,amount);

        emit SendToken(recipient, token, amount);
    }
}
