// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IJBPaymasterHandler } from "../interfaces/IJBPaymasterHandler.sol";

struct HandlerOptions {
    bool ignoreTrustedForwarder;
    IJBPaymasterHandler handler;
}