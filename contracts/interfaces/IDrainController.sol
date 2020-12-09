// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

interface IDrainController {
    function priceIsUnderRejectionTreshold() view external returns(bool);
    function price() external returns (uint224);
    function drainRejectionTreshold() external returns (uint256);
    function updatePrice() external;
}
