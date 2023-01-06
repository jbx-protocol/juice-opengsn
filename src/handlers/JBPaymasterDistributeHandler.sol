// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/IJBPaymasterHandler.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutRedemptionPaymentTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBSingleTokenPaymentTerminalStore.sol";

contract JBPaymasterDistributeHandler is IJBPaymasterHandler {
    error INVALID_PROJECT_ID();
    error INVALID_DISTRIBUTION_AMOUNT();

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
        // We can assume the target is correct, since this contract was registered in the handler as the handler for the target
        require(_methodSignature == IJBPayoutTerminal.distributePayoutsOf.selector);

        // Decode the calldata
        (
            uint256 _projectId,
            uint256 _amount,
            , // _currency,
            address _token,
            // _minReturnedTokens
            ,
        ) = abi.decode(_request.request.data, (uint256, uint256, uint256, address, uint256, string));

        // Make sure this is a call for the expected project
        if (_expectedProjectId != _projectId) revert INVALID_PROJECT_ID();

        // IJBSingleTokenPaymentTerminalStore
        IJBPayoutRedemptionPaymentTerminal _terminal = IJBPayoutRedemptionPaymentTerminal(_targetAddress);

        // Get a reference to the project's current funding cycle.
        uint256 fundingCycleConfiguration = _terminal.store().fundingCycleStore().currentOf(_projectId).configuration;

        // Get the FCs distribution limit
        (
            uint256 _distributionLimitOf,
            // uint256 _distributionLimitCurrencyOf
        ) = IJBController(_terminal.directory().controllerOf(_projectId)).distributionLimitOf(
            _projectId, fundingCycleConfiguration, _terminal, _token
        );

        // Get the amount that was already distributed
        uint256 _distributedAmount = _terminal.store().usedDistributionLimitOf(
            IJBSingleTokenPaymentTerminal(address(_terminal)), _projectId, fundingCycleConfiguration
        );

        // Only allow the call if we are distributing the full amount
        // (this stops users from distributing 1 wei over and over to waste gas)
        if (_distributedAmount != 0 || _distributedAmount + _amount != _distributionLimitOf || _amount == 0) {
            revert INVALID_DISTRIBUTION_AMOUNT();
        }

        // We don't require a callback
        return (bytes(""), false);
    }

    function postRelayCall(bytes memory context) external {}
}
