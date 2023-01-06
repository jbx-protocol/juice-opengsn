// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@opengsn/contracts/src/utils/GsnTypes.sol";

interface IJBPaymasterHandler {
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
        bytes calldata approvalData,
        uint256 maxPossibleGas
    ) external view returns (bytes memory context, bool _postRelayCallback);

    function postRelayCall(bytes memory context) external;
}
