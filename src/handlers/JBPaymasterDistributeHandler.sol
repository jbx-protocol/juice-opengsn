// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/IJBPaymasterHandler.sol";

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutTerminal.sol';


contract JBPaymaster is IJBPaymasterHandler {

    /**
     * @notice 
     * @dev this should revert if its not allowed
     * @param _expectedProjectId the projectID that is paying for the call, the call should be regarding this projectId
    */
    function shouldAllowCall(
        uint256 _expectedProjectId,
        address _targetAddress,
        bytes4 _methodSignature,
        GsnTypes.RelayRequest calldata _request
    ) external view returns (bytes memory context, bool _postRelayCallback) {
        // We can assume the target is correct, since this contract was registered in the handler as the handler for the target
        require(_methodSignature == IJBPayoutTerminal.distributePayoutsOf.selector);

        (
            uint256 _projectId,
            uint256 _amount,
            uint256 _currency,
            address _token,
            uint256 _minReturnedTokens
            ,
        ) = abi.decode(_request.request.data, (
            uint256,
            uint256,
            uint256,
            address,
            uint256,
            string
        ));
    }

    function postRelayCall(
        bytes memory context
    ) external {}

}