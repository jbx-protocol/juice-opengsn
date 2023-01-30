// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC2771Recipient } from "@opengsn/contracts/src/ERC2771Recipient.sol";

contract Callable is ERC2771Recipient {
    event SUCCESS(address _user);

    constructor(address _forwarder) {
        // Set the trusted forwarder
        _setTrustedForwarder(_forwarder);
    }

    function performCall() external {
        emit SUCCESS(_msgSender());
    }
}
