// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { HandlerOptions } from "./structs/HandlerOptions.sol";
import { IJBPaymasterHandler, GsnTypes } from "./interfaces/IJBPaymasterHandler.sol";

import { BasePaymaster, GsnEip712Library, Ownable, IRelayHub, IPaymaster } from "@opengsn/contracts/src/BasePaymaster.sol";

import { JBOwnableOverrides } from "@jbx-protocol/juice-ownable/src/JBOwnableOverrides.sol";

import { JBTokens } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol";
import { JBCurrencies } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBCurrencies.sol";

import { JBSplitAllocationData } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBSplitAllocationData.sol";

import { IJBOperatorStore } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatorStore.sol";
import { IJBPaymentTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
import { IJBSplitAllocator } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBSplitAllocator.sol";
import { IJBAllowanceTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBAllowanceTerminal.sol";
import { IJBProjects } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import { IJBDirectory } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";

/**
 * OpenGSN paymaster extended to allow for better integration with Juicebox projects
 */
contract JBPaymaster is JBOwnableOverrides, BasePaymaster, IJBSplitAllocator {
    //*********************************************************************//
    // --------------------------- events -------------------------------- //
    //*********************************************************************//
    event HandlerSet(address callable, bytes4 callableSignature, address handler, address setBy);
    event FallbackHandlerSet(address handler, address setBy);

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error NO_HANDLER_FOR_CALL(address _target, bytes4 _method);
    error NOT_READY_FOR_REFILL();

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    // The project this Paymaster is for
    uint256 immutable projectId;
    // The JBProjects instance to use to track ownership
    //IJBProjects public immutable projects;
    // The JBDirectory to use to find the terminals
    IJBDirectory public immutable directory;

    // Mapping keccak256(target address, method signature)
    mapping(bytes32 => HandlerOptions) handlers;
    // The handler that gets used if no specific handler is registered
    HandlerOptions fallbackHandler;
    // To what amount should the contract refill when doing so from the allowance (before JB fee)
    uint256 public refillToAmount = 1 ether;
    // Below what amount are users allowed to use the allowance to refill the contract
    uint256 public refillBelow = 0.5 ether;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /**
     *
     * @notice Used by OpenGSN to identify the paymaste type
     */
    function versionPaymaster() external view virtual override returns (string memory) {
        return "3.0.0-beta.2+juicebox.project-owned.ipaymaster";
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//
    constructor(
        uint256 _projectId,
        IJBProjects _projects,
        IJBDirectory _directory,
        IJBOperatorStore _operatorStore
    ) 
        JBOwnableOverrides(_projects, _operatorStore)
    {
        projectId = _projectId;
        directory = _directory;

        _transferOwnership(address(msg.sender), uint88(0));
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /**
     * @notice We override default paymaster behavior
     */
    receive() external payable virtual override {}

    /**
     * @notice fund the relayhub by using the projects allowance, anyone may call this,
     *  it will revert if the project has not given this contract access to the overflow
     */
    function fundFromAllowance() public {
        // Check if the paymaster wants to be refilled
        uint256 _currentBalance = relayHub.balanceOf(address(this));
        if (_currentBalance > refillBelow) revert NOT_READY_FOR_REFILL();

        // Calculate how much we should refill
        uint256 _refillAmount = refillToAmount - _currentBalance;

        IJBAllowanceTerminal _terminal =
            IJBAllowanceTerminal(address(directory.primaryTerminalOf(projectId, JBTokens.ETH)));

        // Use the allowance of the project
        _terminal.useAllowanceOf(
            projectId,
            _refillAmount,
            JBCurrencies.ETH,
            JBTokens.ETH,
            _refillAmount, // min returned
            payable(this),
            "OpenGSN refill"
        );

        relayHub.depositFor{value: payable(this).balance}(address(this));
    }

    /**
     * @notice fund the relayhub by adding it to the funding cycle distribution
     */
    function allocate(JBSplitAllocationData calldata) external payable {
        // Shorthand to make sure we are being paid in ETH and not a token
        require(msg.value > 0);
        // Fund the relayhub
        relayHub.depositFor{value: payable(this).balance}(address(this));
    }

    /**
     * @notice Removes any remaining Ether from the relayhub and this contract
     *  and adds it to the projects balance, may only be called by users that have permission.
     */
    function drain()
        external
        onlyOwner
    {
        // Withdraw the full balance
        relayHub.withdraw(payable(this), relayHub.balanceOf(address(this)));

        // Get the primary ETH terminal of the projecy
        IJBPaymentTerminal _terminal = directory.primaryTerminalOf(projectId, JBTokens.ETH);

        // Add the balance back to the project
        _terminal.addToBalanceOf{value: payable(this).balance}(
            projectId,
            payable(this).balance,
            address(0),
            "OpenGSN refund",
            bytes("")
        );
    }

    /**
     *
     * @notice Set a handler for a method call on a specific contract, can be used to extend/modify paymaster behavior
     */
    function setHandler(address _to, bytes4 _methodSignature, IJBPaymasterHandler _handler, bool _ignoreTrustedForwarder)
        external
        onlyOwner
    {
        bytes32 _hash = keccak256(abi.encode(_to, _methodSignature));
        handlers[_hash] = HandlerOptions({
            ignoreTrustedForwarder: _ignoreTrustedForwarder,
            handler: _handler
        });

        emit HandlerSet(_to, _methodSignature, address(_handler), _msgSender());
    }

    /**
     * @notice set a (optional) fallback for when the paymaster receives a call it doesn't have a specific handler for
     */
    function setFallbackHandler(IJBPaymasterHandler _handler, bool _ignoreTrustedForwarder)
        external
        onlyOwner
    {
        fallbackHandler = HandlerOptions({
            ignoreTrustedForwarder: _ignoreTrustedForwarder,
            handler: _handler
        });
        emit FallbackHandlerSet(address(_handler), _msgSender());
    }

    //*********************************************************************//
    // --------------------- internal overrides -------------------------- //
    //*********************************************************************//

    function _preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    ) internal virtual override returns (bytes memory, bool) {
        (signature);

        address _to = relayRequest.request.to;
        bytes4 _methodSignature = _methodSigFromCalldata(relayRequest.request.data);
        HandlerOptions memory _handlerOptions = handlers[keccak256(abi.encode(_to, _methodSignature))];

        // If no handler was found for this specific call
        if (address(_handlerOptions.handler) == address(0)) {
            // Attempt to use the fallback
            _handlerOptions = fallbackHandler;

            // If there is no fallback set, we revert
            if (address(_handlerOptions.handler) == address(0)) {
                revert NO_HANDLER_FOR_CALL(_to, _methodSignature);
            }
        }

        // If the target contract does not use/care about who the _msgSender is then we can
        // disable the trustedForwarder check, also allows for compatibility with non-ERC2771Recipient contracts.
        if(!_handlerOptions.ignoreTrustedForwarder)
            GsnEip712Library.verifyForwarderTrusted(relayRequest);

        // Check if we should allow the call, this will revert if its not allowed
        (bytes memory _context, bool _postRelayCallback) =
            _handlerOptions.handler.shouldAllowCall(projectId, _to, _methodSignature, relayRequest, approvalData, maxPossibleGas);

        // If the handler wants a callback we pass it the correct address, if its not needed we pass the 0 address
        return (abi.encode(_postRelayCallback ? _handlerOptions.handler : IJBPaymasterHandler(address(0)), _context), false);
    }

    function _postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    ) internal virtual override {
        (context, success, gasUseWithoutPost, relayData);

        (IJBPaymasterHandler _handler, bytes memory _subContext) = abi.decode(context, (IJBPaymasterHandler, bytes));
        if (address(_handler) == address(0)) return;

        _handler.postRelayCall(_subContext);
    }

    function _verifyForwarder(
        GsnTypes.RelayRequest calldata relayRequest
    ) internal view virtual override {
        // Make sure this paymaster trusts the provided forwarder
        require(getTrustedForwarder() == relayRequest.relayData.forwarder, "Forwarder is not trusted");

        // We override GNS default behavior as not every call we do requires the recipient contract to trust the forwarder
        // Some contracts are entirely permisionless and the contract does not care about who calls it.
        // This check is now optionally performed in `_preRelayedCall(..)`
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    // https://ethereum.stackexchange.com/questions/61826/how-to-extract-function-signature-from-msg-data
    function _methodSigFromCalldata(bytes calldata _data) public pure returns (bytes4) {
        return (bytes4(_data[0]) | (bytes4(_data[1]) >> 8) | (bytes4(_data[2]) >> 16) | (bytes4(_data[3]) >> 24));
    }

    //*********************************************************************//
    // -------------------------- overrides ------------------------------ //
    //*********************************************************************//

    /// @inheritdoc JBOwnableOverrides
    function renounceOwnership() public virtual override(JBOwnableOverrides, Ownable) {
        JBOwnableOverrides.renounceOwnership();
    }

    /// @inheritdoc JBOwnableOverrides
    function transferOwnership(address _newOwner) public virtual override(JBOwnableOverrides, Ownable) {
        JBOwnableOverrides.transferOwnership(_newOwner);
    }

    /// @inheritdoc JBOwnableOverrides
    function owner() public view virtual override(JBOwnableOverrides, Ownable) returns (address) {
        return JBOwnableOverrides.owner();
    }

    /// @inheritdoc JBOwnableOverrides
    function _checkOwner() internal view virtual override(JBOwnableOverrides, Ownable){
        JBOwnableOverrides._checkOwner();
    }

    /// @inheritdoc JBOwnableOverrides
    function _transferOwnership(address _newOwner) internal virtual override(JBOwnableOverrides, Ownable) {
        JBOwnableOverrides._transferOwnership(_newOwner);
    }

    function _emitTransferEvent(address previousOwner, address newOwner) internal virtual override {
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
