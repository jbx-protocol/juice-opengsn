// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IJBPaymasterHandler, GsnTypes } from "../interfaces/IJBPaymasterHandler.sol";

contract JBPaymasterAllowAllHandler is IJBPaymasterHandler {
    
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error INVALID_CONFIGURATION();

    /**
     * @notice
     * @dev this should revert if its not allowed
     */
    function shouldAllowCall(
        uint256,
        address,
        bytes4,
        GsnTypes.RelayRequest calldata,
        bytes calldata,
        uint256 // maxPossibleGas
    ) external view returns (bytes memory, bool) {
        // We don't require a callback
        return (bytes(""), true);
    }

    function postRelayCall(bytes memory context) external {}
}
