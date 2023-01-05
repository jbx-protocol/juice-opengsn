// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@opengsn/contracts/src/ERC2771Recipient.sol";

contract Callable is ERC2771Recipient {
    event SUCCESS(address _user);

    function performCall() external {
        emit SUCCESS(_msgSender());
    }
}