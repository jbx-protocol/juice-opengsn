// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { JBPaymaster } from "../JBPaymaster.sol";
import { IJBPaymasterHandler, GsnTypes } from "../interfaces/IJBPaymasterHandler.sol";

contract JBPaymasterRefillHandler is IJBPaymasterHandler {
    
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
        bytes4 _methodSignature,
        GsnTypes.RelayRequest calldata,
        bytes calldata,
        uint256 // maxPossibleGas
    ) external view returns (bytes memory, bool) {
        // We can assume the target is correct, since this contract was registered in the paymaster as the handler for this target
        // We check if the method signature is the one we expect, otherwise we might get unexpected behavior
        if (_methodSignature != JBPaymaster.fundFromAllowance.selector) {
            revert INVALID_CONFIGURATION();
        }

        // We don't require a callback
        return (bytes(""), false);
    }

    function postRelayCall(bytes memory context) external {}
}
