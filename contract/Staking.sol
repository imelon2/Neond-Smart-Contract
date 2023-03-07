// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Staking is Ownable {
    IERC20 public immutable neon;

    // 보상 지급 기간(블록 단위)
    uint public duration;
    // 보상 완료 시점(Block Number)
    uint public finishAt;
    // 최근 totalSupply 업데이트 블록 number 및 보상 완료 블록 number
    uint public updatedAt;
    // 블록당 지급되는 보상
    uint public rewardRate;
    // 가장 최근 업데이트된 r
    uint public rewardPerTokenStored;
    // 유저가 스테이킹한 순간의 r
    mapping(address => uint) public userRewardPerTokenPaid;
    // 유저에게 지급된 보상
    mapping(address => uint) public rewards;
    // Contract에 예치된 전체 토큰
    uint public totalSupply;
    // 유저가 예치한 토큰
    mapping(address => uint) public balanceOf;

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if(_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored; 
        }
        _;
    }



    constructor(IERC20 _neon) {
        neon = _neon;
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.number,"reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmnount(uint _amount) external onlyOwner updateReward(address(0)) {
        if(block.number > finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = rewardRate * (finishAt - block.number);
            rewardRate = (remainingRewards + _amount) / duration;
        }

        require(rewardRate > 0,"reward rate is Zero");
        require(rewardRate * duration <= neon.balanceOf(address(this)),"reward amount not enough");

        finishAt = block.number + duration;
        updatedAt = block.number;
    }

    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0,"amount is Zero");
        neon.transferFrom((msg.sender), address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply +=_amount;
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0,"amount is Zero");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        neon.transfer(msg.sender,_amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if(reward > 0) {
            rewards[msg.sender] = 0;
            neon.transfer(msg.sender,reward);
        }
    }

    function earned(address _account) public view returns(uint) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18 + rewards[_account];
    }

    function lastTimeRewardApplicable() public view returns(uint) {
        return min(block.number,finishAt);
    }

    function rewardPerToken() public view returns(uint) {
        if(totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * 
            (lastTimeRewardApplicable() - updatedAt) * 1e18
        ) / totalSupply;
    }

    function min(uint x, uint y) private pure returns(uint) {
        return x <= y ? x : y;
    }

    function addBlockNum() public pure {}

    function getCurrentBlockNum() public view returns(uint) {
        return block.number;
    }
}
