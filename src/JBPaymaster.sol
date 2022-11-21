// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IJBPaymasterHandler.sol";

import "@opengsn/contracts/src/BasePaymaster.sol";

contract JBPaymaster is BasePaymaster {
    error NO_HANDLER_FOR_CALL(address _target, bytes4 _method);

    uint256 immutable projectId;

    // Mapping keccak256(target address, method signature)
    mapping(bytes32 => IJBPaymasterHandler) _preRelayHandler;

    constructor(uint256 _projectId) {
        projectId = _projectId;
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

    function _preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
        internal
        virtual
        override
        returns (bytes memory, bool)
    {
        (signature, approvalData);

        address _to = relayRequest.request.to;
        bytes4 _methodSignature = _methodSigFromCalldata(
            relayRequest.request.data
        );
        IJBPaymasterHandler _handler = _preRelayHandler[
            keccak256(abi.encode(_to, _methodSignature))
        ];
        if (address(_handler) == address(0))
            revert NO_HANDLER_FOR_CALL(_to, _methodSignature);

        (bytes memory _context, bool _postRelayCallback) = _handler.shouldAllowCall(
            projectId,
            _to,
            _methodSignature,
            relayRequest
        );

        // If the handler wants a callback we pass it the correct address, if its not needed we pass the 0 address
        return (abi.encode(_postRelayCallback ? _handler : IJBPaymasterHandler(address(0)), _context), false);
    }

    function _postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    ) internal virtual override {
        (context, success, gasUseWithoutPost, relayData);

        (IJBPaymasterHandler _handler, bytes memory _subContext) = abi.decode(context, (IJBPaymasterHandler, bytes));
        if(address(_handler) == address(0)) return;

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
