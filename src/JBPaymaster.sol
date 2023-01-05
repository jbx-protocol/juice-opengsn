// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IJBPaymasterHandler.sol";

import "@opengsn/contracts/src/BasePaymaster.sol";

import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBCurrencies.sol';

import "@jbx-protocol/juice-contracts-v3/contracts/abstract/JBOperatable.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBSplitAllocator.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBAllowanceTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";

/**
 * OpenGSN paymaster extended to allow for better integration with Juicebox projects
 */
contract JBPaymaster is BasePaymaster, JBOperatable, IJBSplitAllocator {
    error NO_HANDLER_FOR_CALL(address _target, bytes4 _method);
    error NOT_READY_FOR_REFILL();

    uint256 immutable projectId;

    /**
     @notice
     Mints ERC-721's that represent project ownership.
    */
    IJBProjects public immutable projects;

    IJBDirectory public immutable directory;

    // Mapping keccak256(target address, method signature)
    mapping(bytes32 => IJBPaymasterHandler) handlers;
    //
    IJBPaymasterHandler _fallbackHandler;

    uint256 refillToAmount = 1 ether;
    uint256 refillBelow = 0.5 ether;

    constructor(
        uint256 _projectId,
        IJBProjects _projects,
        IJBDirectory _directory,
        IJBOperatorStore _operatorStore
    ) JBOperatable(_operatorStore) {
        projects = _projects;
        projectId = _projectId;
        directory = _directory;
    }

    /**
     * @notice We override default paymaster behavior
     */
    receive() external virtual override payable {}

    /**
     * @notice fund the relayhub by using the projects allowance, anyone may call this,
     *  it will revert if the project has not given this contract access to the overflow
     */
    function fundFromAllowance() public {
        // Check if the paymaster wants to be refilled
        uint256 _currentBalance = relayHub.balanceOf(address(this));
        if(_currentBalance > refillBelow) revert NOT_READY_FOR_REFILL();

        // Calculate how much we should refill
        uint256 _refillAmount = refillToAmount - _currentBalance;

        IJBAllowanceTerminal _terminal = IJBAllowanceTerminal(
            address(directory.primaryTerminalOf(projectId, JBTokens.ETH))
        );

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
        // Shorthand to make sure we are being paid ETH and not a token
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
        requirePermission(
            projects.ownerOf(projectId),
            projectId,
            1 // TODO: replace with a correct id
        )
    {
        // Withdraw the full balance
        relayHub.withdraw(
            payable(this),
            relayHub.balanceOf(address(this))
        );

        // Get the primary ETH terminal of the projecy
        IJBPaymentTerminal _terminal = directory.primaryTerminalOf(projectId, JBTokens.ETH);

        // Add the balance back to the project
        _terminal.addToBalanceOf{value: payable(this).balance}(
            projectId,
            payable(this).balance,
            address(0),
            "OpenGSN refund",
            bytes('')
        );
    }

    /**
     * @dev Returns the address of the current owner. We override default ownable behavior in favor of a more Juicebox aproach.
     */
    function owner() public view virtual override returns (address) {
        return projects.ownerOf(projectId);
    }

    function versionPaymaster()
        external
        view
        virtual
        override
        returns (string memory)
    {
        return "3.0.0-beta.2+opengsn.whitelist.ipaymaster";
    }

    function setHandler(address _to, bytes4 _methodSignature, IJBPaymasterHandler _handler)
        external
        // requirePermission(
        //     projects.ownerOf(projectId),
        //     projectId,
        //     1 // TODO: replace with a correct id
        // )
    {

        bytes32 _hash = keccak256(abi.encode(_to, _methodSignature));
        handlers[_hash] = _handler;
        // TODO: emit event
    }

    function setFallbackHandler(IJBPaymasterHandler _handler)
        external
        requirePermission(
            projects.ownerOf(projectId),
            projectId,
            1 // TODO: replace with a correct id
        )
    {
        _fallbackHandler = _handler;
        // TODO: emit event
    }

    function _preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    ) internal virtual override returns (bytes memory, bool) {
        (signature);

        address _to = relayRequest.request.to;
        bytes4 _methodSignature = _methodSigFromCalldata(
            relayRequest.request.data
        );
        IJBPaymasterHandler _handler = handlers[
            keccak256(abi.encode(_to, _methodSignature))
        ];

        // If no handler was found for this specific call
        if (address(_handler) == address(0)) {
            // Attempt to use the fallback
            _handler = _fallbackHandler;

            // If there is no fallback set, we revert
            if (address(_handler) == address(0))
                revert NO_HANDLER_FOR_CALL(_to, _methodSignature);
        }

        // Check if we should allow the call
        (bytes memory _context, bool _postRelayCallback) = _handler
            .shouldAllowCall(projectId, _to, _methodSignature, relayRequest, approvalData, maxPossibleGas);

        // If the handler wants a callback we pass it the correct address, if its not needed we pass the 0 address
        return (
            abi.encode(
                _postRelayCallback ? _handler : IJBPaymasterHandler(address(0)),
                _context
            ),
            false
        );
    }

    function _postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    ) internal virtual override {
        (context, success, gasUseWithoutPost, relayData);

        (IJBPaymasterHandler _handler, bytes memory _subContext) = abi.decode(
            context,
            (IJBPaymasterHandler, bytes)
        );
        if (address(_handler) == address(0)) return;

        _handler.postRelayCall(_subContext);
    }

    // https://ethereum.stackexchange.com/questions/61826/how-to-extract-function-signature-from-msg-data
    function _methodSigFromCalldata(bytes calldata _data)
        public
        pure
        returns (bytes4)
    {
        return (bytes4(_data[0]) |
            (bytes4(_data[1]) >> 8) |
            (bytes4(_data[2]) >> 16) |
            (bytes4(_data[3]) >> 24));
    }
}
