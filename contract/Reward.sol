// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Reward {
    mapping(address => int256) public rewardByAddress;
    mapping(address => bool) public check;
    address[] rewardList;
    mapping(address => uint256) public canClaimReward;

    function cle(address user,uint256 amount) public {
        if(check[user] == false) {
            rewardList.push(user);
            check[user] = true;
        }
        rewardByAddress[user] += int(amount);
    }

    function distribute() public {
        uint _length = rewardList.length;
        for(uint i = 0; i < _length; i++) {
            canClaimReward[rewardList[_length]] += uint(rewardByAddress[rewardList[_length]]);
            delete rewardByAddress[rewardList[_length]];
            check[rewardList[_length]] = false;
        }

        delete rewardList;
    }
}