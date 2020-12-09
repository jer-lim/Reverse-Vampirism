// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

interface IMasterVampire {

    function drain(uint256 _pid) external;

    function poolInfo(uint256 _pid) external returns (
        address victim,
        uint victimPoolId,
        uint rewardPerBlock,
        uint lastRewardBlock,
        uint accDrcPerShare,
        uint rewardDrainModifier,
        uint wethDrainModifier
    );

    function poolLength() external returns (uint256);
}
