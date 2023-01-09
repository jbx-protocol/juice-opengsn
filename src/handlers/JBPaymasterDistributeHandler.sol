// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/IJBPaymasterHandler.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutRedemptionPaymentTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBSingleTokenPaymentTerminalStore.sol";

contract JBPaymasterDistributeHandler is IJBPaymasterHandler {
    
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error INVALID_PROJECT_ID();
    error INVALID_DISTRIBUTION_AMOUNT();
    error INVALID_CONFIGURATION();

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
        uint256 // maxPossibleGas
    ) external view returns (bytes memory, bool) {
        // We can assume the target is correct, since this contract was registered in the paymaster as the handler for this target
        // We check if the method signature is the one we expect, otherwise we might get unexpected behavior
        if (_methodSignature != IJBPayoutTerminal.distributePayoutsOf.selector) {
            revert INVALID_CONFIGURATION();
        }

        // Decode the calldata
        (
            uint256 _projectId,
            uint256 _amount,
            , // _currency,
            address _token,
            , // _minReturnedTokens
            // memo
        ) = abi.decode(_extractCalldata(_request.request.data), (uint256, uint256, uint256, address, uint256, string));

        // Make sure this is a call for the expected project
        if (_expectedProjectId != _projectId) {
            revert INVALID_PROJECT_ID();
        }

        // Get a reference to the project's current funding cycle.
        IJBPayoutRedemptionPaymentTerminal _terminal = IJBPayoutRedemptionPaymentTerminal(_targetAddress);
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
        if (_distributedAmount + _amount != _distributionLimitOf || _amount == 0) {
            revert INVALID_DISTRIBUTION_AMOUNT();
        }

        // We don't require a callback
        return (bytes(""), false);
    }

    function postRelayCall(bytes memory context) external {}

    // https://ethereum.stackexchange.com/questions/131283/how-do-i-decode-call-data-in-solidity
    function _extractCalldata(bytes memory calldataWithSelector) internal pure returns (bytes memory) {
        bytes memory calldataWithoutSelector;

        require(calldataWithSelector.length >= 4);

        assembly {
            let totalLength := mload(calldataWithSelector)
            let targetLength := sub(totalLength, 4)
            calldataWithoutSelector := mload(0x40)
            
            // Set the length of callDataWithoutSelector (initial length - 4)
            mstore(calldataWithoutSelector, targetLength)

            // Mark the memory space taken for callDataWithoutSelector as allocated
            mstore(0x40, add(0x20, targetLength))

            // Process first 32 bytes (we only take the last 28 bytes)
            mstore(add(calldataWithoutSelector, 0x20), shl(0x20, mload(add(calldataWithSelector, 0x20))))

            // Process all other data by chunks of 32 bytes
            for { let i := 0x1C } lt(i, targetLength) { i := add(i, 0x20) } {
                mstore(add(add(calldataWithoutSelector, 0x20), i), mload(add(add(calldataWithSelector, 0x20), add(i, 0x04))))
            }
        }

        return calldataWithoutSelector;
    }
}
