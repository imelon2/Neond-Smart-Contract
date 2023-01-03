// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interface/INEOND.sol";


contract Airdrop is Ownable,Pausable {
    using SafeERC20 for IERC20;
    bytes32 public constant AIRDROP_TYPE = keccak256("AIRDROP_TYPE");

    uint256 public rewardAmount;

    IERC20 NEON;
    INEOND NEOND;

    mapping (uint256 => bool) public isNftReceivedReward;

    // Error
    error Rewarded();
    error NotNftHolder();
    error NotEnoughReward();
    error NotAirDropNft();

    // Event
    event Claim(address indexed holder,uint256 tokenId);

    constructor(address _NEON,address _NEOND,uint256 _rewardAmount) {
        NEON = IERC20(_NEON);
        NEOND = INEOND(_NEOND);
        rewardAmount = _rewardAmount;
    }

    // Setter Func
    function setRewardAmount(uint256 _amount) external onlyOwner {
        rewardAmount = _amount;
    }

    // Getter Func
    function totalRewardAmount() public view returns(uint256) {
        return NEON.balanceOf(address(this));
    }

    function isAridropNFT(uint256 tokenId) public view returns(bool) {
        return NEOND.typeOf(tokenId) == AIRDROP_TYPE;
    }

    function claim(uint256 tokenId) external whenNotPaused {
        if(totalRewardAmount() < rewardAmount) {
            revert NotEnoughReward();
        }
        if(isNftReceivedReward[tokenId] == true) {
            revert Rewarded();
        }
        address holder = msg.sender;
        if(holder != nftBalanceOf(tokenId)) {
            revert NotNftHolder();
        }
        if(isAridropNFT(tokenId) == false) {
            revert NotAirDropNft();
        }


        isNftReceivedReward[tokenId] = true;
        NEON.safeTransfer(holder,rewardAmount);

        emit Claim(holder, tokenId);
    }


    function emergencyClaim() external onlyOwner {
        NEON.safeTransfer(msg.sender,totalRewardAmount());
    }

    function emergencyTransfer(address to,uint256 amount) external onlyOwner {
        NEON.safeTransfer(to,amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Check Func
    function nftBalanceOf(uint256 tokenId) private view returns(address) {
        return NEOND.ownerOf(tokenId);
    }
}