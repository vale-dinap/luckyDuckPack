// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract duckRewarder{

    struct Dividend{
        uint256 timestamp; //
        uint256 amount; // Amount of dividend left to be distributed
        uint256 earningDucks; // amount of ducks currently eligible
    }

    address duckLord; // Creator

    //mapping(uint256 => Dividend);

    uint256 balance;

    uint nextPaymentId;

    mapping(uint256 => bool) eligible; // tokenId=>boolState Tracks whether a token ID should be allowed to accrue dividends; all tokens earn dividends by default, their eligibility is disabled when they are transferred withouth a payment of royalty fees.

    mapping(address => uint256) addressEnableTimestamp;

}