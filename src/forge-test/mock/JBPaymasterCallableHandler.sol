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
     * @dev this should revert if its not allowed
     * @param _expectedProjectId the projectID that is paying for the call, the call should be regarding this projectId
     */
    function shouldAllowCall(
        uint256 _expectedProjectId,
        address _targetAddress,
        bytes4 _methodSignature,
        GsnTypes.RelayRequest calldata _request,
        bytes calldata,
        uint256 maxPossibleGas
    ) external view returns (bytes memory, bool) {
        // We don't require a callback
        return (bytes(""), false);
    }

    function postRelayCall(bytes memory context) external {}
}
