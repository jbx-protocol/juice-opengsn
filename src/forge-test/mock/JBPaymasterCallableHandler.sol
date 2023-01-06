// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../interfaces/IJBPaymasterHandler.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutRedemptionPaymentTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBSingleTokenPaymentTerminalStore.sol";

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
        return (bytes(""), false);
    }

    function postRelayCall(bytes memory context) external {}
}
