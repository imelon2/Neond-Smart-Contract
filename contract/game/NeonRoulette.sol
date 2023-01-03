// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./VRF.sol";
import "../interface/IHouse.sol";

contract NeonRoulette is VRF {
    using SafeERC20 for IERC20;

    struct Bet {
        address player;
        address token;
        uint40 outcome;
        bool isSettled;
        uint256 winAmount;
        uint256 placeBlockNumber;
        uint256[] betAmount;
    }

    struct Token {
        uint64 pendingCount;
        uint16 houseEdge;
        bool isPuased;
    }

    mapping(uint => Bet) public bets;
    mapping(address => Token) public tokens;

    IHouse private House;

    bool public gameIsLive;
    uint16 public refundDelay;

    uint constant MULTIPLIER = 27;

    constructor(
        address _vrfCoordinator,
        address _House
        ) VRF(_vrfCoordinator){
        House = IHouse(_House);
        refundDelay = 10800; // 1 Block = 2 sec | 10800 BLocks = 21600 sec = 6 hours (Based by Polygon)
    }

    // Error
    error GameIsNotLive();
    error InvalidAddress();
    error BetIsPending();
    error TokenIsPaused();
    error BetLengthNotInRange();
    error HouseUnapprovedToken();
    error ZeroBet();

    // Events
    event BetPlaced(uint indexed betId, address indexed player,address token, uint256[] betAmount);
    event BetSettled(uint indexed betId, address indexed player, uint betAmount, uint betChoice, uint outcome, uint winAmount);
    event BetRefunded(uint indexed betId, address indexed player, uint amount);
    event SetHouseEdge(address indexed token, uint16 houseEdge);
    event SetRefundPeriod(uint16 refundDelay);

    // Modifier
    modifier IsGameLive() {
        if(!gameIsLive) {
            revert GameIsNotLive();
        }
        _;
    }

    // Management
    function toggleGameLive() external onlyOwner {
        gameIsLive = !gameIsLive;
    }

    function toggleTokenPuase(address token) external onlyOwner {
        tokens[token].isPuased = !tokens[token].isPuased;
    }

    // Setter(init) 
    function initHouse(IHouse _House) external onlyOwner {
        if (address(_House) == address(0)) {
            revert InvalidAddress();
        }
        House = _House;
    }

    function initRefundDelay(uint16 _refundDelay) external onlyOwner {
        refundDelay = _refundDelay;
        emit SetRefundPeriod(_refundDelay);
    }

    function initToken(address token,uint16 houseEdge) external onlyOwner {
        if(tokens[token].pendingCount != 0) {
            revert BetIsPending();
        }
        tokens[token].houseEdge = houseEdge;
        if(!tokens[token].isPuased) {
            tokens[token].isPuased = true;    
        }
        emit SetHouseEdge(token,houseEdge);
    }

    // Getter
    function getMinBetAmount(address token) public view returns(uint) {
        return House.getMinBetAmount(token);
    }

    function getMaxBetAmount(address token) public view returns(uint) {
        return House.getMaxBetAmount(token,MULTIPLIER);
    }

    function placeBet(address token, uint256[] calldata betAmount) external IsGameLive {
        if(tokens[token].isPuased) {
            revert TokenIsPaused();
        }
        uint8 betLength = uint8(betAmount.length);
        if(betLength != 37) {
            revert BetLengthNotInRange();
        }

        // House Status
        if(!House.isAllowedToken(token)) {
            revert HouseUnapprovedToken();
        }
        uint256 totalBetAmount;
        uint256 minBetAmount = getMinBetAmount(token);
        uint256 maxBetAmount = getMaxBetAmount(token);
        for(uint i = 0; i < betLength;i++) {
            uint _betAmount = betAmount[i];
            if(_betAmount <= maxBetAmount && _betAmount >= minBetAmount) {
                totalBetAmount += betAmount[i];
            }
        }
        if(totalBetAmount == 0) {
            revert ZeroBet();
        }

        address player = msg.sender;

        // Transfer player's bet amount and Pending a winnings amount in a House
        House.palceBet(token,player,totalBetAmount,0);

        uint256 betId = sendRequestRandomness(); // request randomness to Chainlink VRF

        bets[betId] = Bet({
            player : player,
            token : token,
            betAmount : betAmount,
            winAmount : 0,
            outcome : 0,
            placeBlockNumber : block.number,
            isSettled : false
        });

        tokens[token].pendingCount ++;

        emit BetPlaced(betId, player, token, betAmount);
    }

    // Chain Link VRF call this with result
    function fulfillRandomWords(uint256 id, uint256[] memory randomWords)
        internal
        override {
            // Bet storage bet = bets[betId];
            // settleBet(id,randomWords[0]);
    }

    function settleBet(uint betId,uint256 randomNumber) private {}
}