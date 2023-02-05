// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IJBPaymasterHandler, GsnTypes } from "../../interfaces/IJBPaymasterHandler.sol";

contract JBPaymasterCallableHandler is IJBPaymasterHandler {
    /**
     * @notice
     * @dev this allows any call
     */
    function shouldAllowCall(
        uint256 ,
        address ,
        bytes4 ,
        GsnTypes.RelayRequest calldata,
        bytes calldata,
        uint256
    ) external view returns (bytes memory, bool) {
        // We don't require a callback
        return (bytes(""), true);
    }

    function postRelayCall(bytes memory context) external {}
}
