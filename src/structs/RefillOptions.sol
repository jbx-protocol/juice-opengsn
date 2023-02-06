// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/*
    @member refillToAmount To what amount should the paymaster be refilled
    @member refillBelowPercentage Below what percentage of the `refillToAmount` should a refill call be allowed
    @member anyoneMayCall should the paymaster allow anyone to perform a refill from allowance
*/

struct RefillOptions {
    uint200 refillToAmount;
    uint16 refillBelowPercentage;
    bool anyoneMayCall;
}