// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./VRF.sol";
import "../interface/IHouse.sol";


contract Dice is VRF  {
    using SafeERC20 for IERC20;

    struct Bet {
        address player;
        address token;
        uint40 rollUnder;
        uint40 outcome;
        bool isSettled;
        uint betChoice;
        uint256 winAmount;
        uint256 betAmount;
        uint256 placeBlockNumber;
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

    // Modulo is the number of equiprobable outcomes in a game:
    // 6 for dice roll
    uint constant MODULO = 6;

    // These are constants that make O(1) population count in placeBet possible.
    uint constant POPCNT_MULT = 0x0000000000002000000000100000000008000000000400000000020000000001;
    uint constant POPCNT_MASK = 0x0001041041041041041041041041041041041041041041041041041041041041;
    uint constant POPCNT_MODULO = 0x3F;


    // Error
    error GameIsNotLive();
    error TokenIsPaused();
    error BetIsPending();
    error BetMaskNotInRange();
    error InvalidAddress();
    error ZeroBet();
    error SettledBet();
    error NotPassedRefundPeriod();
    error UnderMinBetAmount(uint256);
    error OverMaxBetAmount(uint256);
    error HouseUnapprovedToken();


    constructor(
        address _vrfCoordinator,
        address _House
        ) VRF(_vrfCoordinator){
        House = IHouse(_House);
        refundDelay = 10800; // 1 Block = 2 sec | 10800 BLocks = 21600 sec = 6 hours (Based by Polygon)
    }

    // Events
    event BetPlaced(uint indexed betId, address indexed player,address token, uint betAmount, uint betChoice);
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

    function getMaxBetAmount(address token,uint betChoice) public view returns(uint) {
        uint40 rollUnder = _getRollUnder(betChoice);
        return House.getMaxBetAmount(token,_getMultiplier(rollUnder));
    }

    /*
     * @notice Calculate the player's winning amount.
     * @return After calculating the houseEdge, The reward amount is calculated according to the multiplier chosen by the player.
     * @dev 10000 = 100%
    */
    function _getWinAmount(address _token, uint256 _amount, uint40 _rollUnder) private view returns(uint256) {
            uint256 _winAmount = _amount * (10000 - tokens[_token].houseEdge) / 10000;
            return _winAmount * MODULO / _rollUnder;
    }

    function _getRollUnder(uint _betChoice) private pure returns(uint40) {
        return uint40(((_betChoice * POPCNT_MULT) & POPCNT_MASK) % POPCNT_MODULO);
    }

    function _getMultiplier(uint40 rollUnder) private pure returns(uint256) {
        return 10000 * MODULO / rollUnder;
    }


    /*
     * @notice A new bet is created when a request comes from GameManager.
     * @param _betChoice : Player's Choice (Mask Value)
     * ⎿ If Player choice 1,3,6 of the dice, Mask Value is 2^0 + 2^2 + 2^5 = 37
    */
    function placeBet(address token, uint256 betAmount, uint betChoice) external IsGameLive {
        if(tokens[token].isPuased) {
            revert TokenIsPaused();
        }
        if( 0 >= betChoice || betChoice > 2**MODULO-1) {
            revert BetMaskNotInRange();
        }
    
        // House Status
        {
            if(!House.isAllowedToken(token)) {
                revert HouseUnapprovedToken();
            }
            uint256 minBetAmount = getMinBetAmount(token);
            if(betAmount < minBetAmount) {
                revert UnderMinBetAmount(minBetAmount);
            }

            uint256 maxBetAmount = getMaxBetAmount(token,betChoice);
            if(betAmount > maxBetAmount) {
                revert OverMaxBetAmount(maxBetAmount);
            }
        }

        address player = msg.sender;
        uint40 rollUnder = _getRollUnder(betChoice);
        uint256 winnableAmount = _getWinAmount(token,betAmount,rollUnder);

        // Transfer player's bet amount and Pending a winnings amount in a House
        House.palceBet(token,player,betAmount,winnableAmount);


        uint256 betId = sendRequestRandomness(); // request randomness to Chainlink VRF
        bets[betId] = Bet({
            player : player,
            token : token,
            betAmount : betAmount,
            winAmount : 0,
            rollUnder : rollUnder,
            betChoice : betChoice,
            outcome : 0,
            placeBlockNumber : block.number,
            isSettled : false
        });

        tokens[token].pendingCount ++;
        
        emit BetPlaced(betId, player, token, betAmount, betChoice);
    }

    // Chain Link VRF call this with result
    function fulfillRandomWords(uint256 id, uint256[] memory randomWords)
        internal
        override {
            settleBet(id,randomWords[0]);
    }

    function settleBet(uint betId,uint256 randomNumber) private {
        Bet storage bet = bets[betId];

        uint256 betAmount = bet.betAmount;
        address token = bet.token;

        // Check that bet exists
        // Check that bet is not settled yet
        if (betAmount == 0 || bet.isSettled == true) {
            return;
        }

        address player = bet.player;
        uint betChoice = bet.betChoice;
        uint40 rollUnder = bet.rollUnder;

        // VRF final result
        uint40 outcome = uint40(randomNumber % MODULO);
        uint winnableAmount = _getWinAmount(token, betAmount, rollUnder);
        uint winAmount = (2 ** outcome) & betChoice != 0 ? winnableAmount : 0;

        bet.outcome = outcome;
        bet.isSettled = true;
        bet.winAmount = winAmount;

        tokens[token].pendingCount --;

        House.settleBet(token,player,betAmount,winnableAmount,winAmount > 0);

        emit BetSettled(betId, player, betAmount, betChoice, outcome, winAmount);
    }

    function refundBet(uint betId) external {
        Bet storage bet = bets[betId];

        uint256 betAmount = bet.betAmount;
        address token = bet.token;

        if(betAmount <= 0) {
            revert ZeroBet();
        }
        if(bet.isSettled) {
            revert SettledBet();
        }
        if(!isPassedRefundPeriod(betId)) {
            revert NotPassedRefundPeriod();
        }

        address player = bet.player;
        uint40 rollUnder = bet.rollUnder;
        uint winnableAmount = _getWinAmount(token,betAmount,rollUnder);

        House.refundBet(token, player, betAmount, winnableAmount);

        // Update bet records
        bet.isSettled = true;
        bet.winAmount = betAmount; // if winAmount == betAmount is refend

        tokens[token].pendingCount --;
        // Record refund in event logs
        emit BetRefunded(betId,player,betAmount);
    }

    // Checked
    function isPassedRefundPeriod(uint betId) public view returns(bool) {
        return block.number > bets[betId].placeBlockNumber + refundDelay;
    }
}
