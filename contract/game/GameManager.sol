// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import "../interface/IGame.sol";
// import "../interface/IHouse.sol";

// contract GameManager is Ownable {
//     using SafeERC20 for IERC20;

//     mapping(address => bool) public approvedGame;

//     IHouse public House;

//     // initial deploy contract state
//     bool public gameManagerIsPause = true;


//     constructor(IHouse _House) {
//         House = _House;
//     }

//     error UnapprovedGame();
//     error GameMagerIsPaused();
//     error InvalidAddress();

//     modifier IsGameManagerPause() {
//         if(gameManagerIsPause) {
//             revert GameMagerIsPaused();
//         }
//         _;
//     }

//     function pauseGameManager() external onlyOwner {
//         gameManagerIsPause = !gameManagerIsPause;
//     }

//     function approveGame(address game) external onlyOwner {
//         approvedGame[game] = true;
//     }

//     function unApproveGame(address game) external onlyOwner {
//         approvedGame[game] = false;
//     }

//     function initHouse(IHouse _House) external onlyOwner {
//         if (address(_House) == address(0)) {
//             revert InvalidAddress();
//         }
//         House = _House;
//     }
    
//     function palceBet(address game,address token,uint256 betAmount,uint256 betChoice) external IsGameManagerPause {
//         if(!approvedGame[game]) {
//             revert UnapprovedGame();
//         }

//         // if success placeBet, transfer bet amount to house
//         // need player approve ERC20 token
//         IERC20(token).safeTransferFrom(msg.sender,address(House),betAmount);

//         IGame(game).placeBet(token,msg.sender,betAmount,betChoice);
//     }

// }