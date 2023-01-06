// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../JBPaymaster.sol";
import "../../handlers/JBPaymasterDistributeHandler.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBCurrencies.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatorStore.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutRedemptionPaymentTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBSingleTokenPaymentTerminalStore.sol"; 

contract JBPaymasterDistributeHandlerTest is Test {

    JBPaymasterDistributeHandler handler;

    // Mock addresses
    address terminal = address(5000);
    address store = address(5100);
    address fundingCycleStore = address(5200);
    address directory = address(5300);
    address controller = address(5400);

    //uint256 projectId;

    function setUp() public virtual {
        handler = new JBPaymasterDistributeHandler();
    }


    function testDistribute(
        address _sender,
        uint256 _projectId,
        uint256 _distributedAmount,
        uint256 _distributedLimit,
        uint256 _fcConfiguration
    ) external {
        // If amount is already at limit the call will revert
        vm.assume(_distributedAmount < _distributedLimit);
        uint256 _amount = _distributedLimit - _distributedAmount;

        _configureMock(
            _projectId,
            _distributedAmount,
            _distributedLimit,
            _fcConfiguration
        );

        string memory _memo = "";
        bytes memory _calldata = abi.encodeWithSelector(
            IJBPayoutTerminal.distributePayoutsOf.selector,
            _projectId,
            _amount, // amount
            0, // currency
            address(0), // token
            0, // minReturnedTokens
            _memo // memo
        );

        handler.shouldAllowCall(
            _projectId,
            terminal,
            IJBPayoutTerminal.distributePayoutsOf.selector,
            _basicRelayRequest(
                _sender,
                terminal,
                _calldata
            ),
            "",
            0 // maxPossibleGas
        );
    }

    function testDistribute_revert_shouldDistributeExactFullAmount(
        address _sender,
        uint256 _projectId,
        uint256 _distributedAmount,
        uint256 _distributedLimit,
        uint256 _amountToDistribute,
        uint256 _fcConfiguration
    ) external {
        // Quick check to make sure adding the two doesn't overflow
        unchecked{
            vm.assume(_distributedAmount < _distributedAmount + _amountToDistribute);
            vm.assume(_amountToDistribute < _distributedAmount + _amountToDistribute);
        }

        // The call will revert if this addition does not exactly equal the limit
        vm.assume(_distributedAmount + _amountToDistribute != _distributedLimit);

        _configureMock(
            _projectId,
            _distributedAmount,
            _distributedLimit,
            _fcConfiguration
        );

        string memory _memo = "";
        bytes memory _calldata = abi.encodeWithSelector(
            IJBPayoutTerminal.distributePayoutsOf.selector,
            _projectId,
            _amountToDistribute, // amount
            0, // currency
            address(0), // token
            0, // minReturnedTokens
            _memo // memo
        );

        // It should revert with the following error
        vm.expectRevert(
            abi.encodeWithSignature('INVALID_DISTRIBUTION_AMOUNT()')
        );

        handler.shouldAllowCall(
            _projectId,
            terminal,
            IJBPayoutTerminal.distributePayoutsOf.selector,
            _basicRelayRequest(
                _sender,
                terminal,
                _calldata
            ),
            "",
            0 // maxPossibleGas
        );
    }

    function testDistribute_revert_shouldDistributeSomeAmount(
        address _sender,
        uint256 _projectId,
        uint256 _distributedAmount,
        uint256 _distributedLimit,
        uint256 _fcConfiguration
    ) external {
         // If amount is already at limit the call will revert
        vm.assume(_distributedAmount < _distributedLimit);
        // Distributing 0 should revert, since its wasting gas
        uint256 _amount = 0;

        _configureMock(
            _projectId,
            _distributedAmount,
            _distributedLimit,
            _fcConfiguration
        );

        string memory _memo = "";
        bytes memory _calldata = abi.encodeWithSelector(
            IJBPayoutTerminal.distributePayoutsOf.selector,
            _projectId,
            _amount, // amount
            0, // currency
            address(0), // token
            0, // minReturnedTokens
            _memo // memo
        );

        // It should revert with the following error
        vm.expectRevert(
            abi.encodeWithSignature('INVALID_DISTRIBUTION_AMOUNT()')
        );

        handler.shouldAllowCall(
            _projectId,
            terminal,
            IJBPayoutTerminal.distributePayoutsOf.selector,
            _basicRelayRequest(
                _sender,
                terminal,
                _calldata
            ),
            "",
            0 // maxPossibleGas
        );
    }

    function _basicRelayRequest(address _from, address _target, bytes memory _calldata) internal view returns (GsnTypes.RelayRequest memory){
        return GsnTypes.RelayRequest({
            request: IForwarder.ForwardRequest({
                from: _from,
                to: _target,
                value: 0,
                gas: 0,
                nonce: 0,
                data: _calldata,
                validUntilTime: block.timestamp + 1
            }),
            relayData: GsnTypes.RelayData({
                maxFeePerGas: 0,
                maxPriorityFeePerGas: 0,
                transactionCalldataGasUsed: 0,
                relayWorker: address(0),
                paymaster: address(0),
                forwarder: address(0),
                paymasterData: "",
                clientId: 0
            })
        });
    }

    function _configureMock(
        uint256 _projectId,
        uint256 _distributedAmount,
        uint256 _distributedLimit,
        uint256 _fcConfiguration
    ) internal {
        vm.mockCall(
            terminal,
            abi.encodeWithSelector(
                IJBPayoutRedemptionPaymentTerminal.store.selector
            ),
            abi.encode(
                store
            )
        );

        vm.mockCall(
            store,
            abi.encodeWithSelector(
                IJBSingleTokenPaymentTerminalStore.fundingCycleStore.selector
            ),
            abi.encode(
                fundingCycleStore
            )
        );

        vm.mockCall(
            fundingCycleStore,
            abi.encodeWithSelector(
                IJBFundingCycleStore.currentOf.selector,
                _projectId
            ),
            abi.encode(
                JBFundingCycle({
                    number: 0,
                    configuration: _fcConfiguration,
                    basedOn: 0,
                    start: block.timestamp - 1,
                    duration: 1 weeks,
                    weight: 1000,
                    discountRate: 1000,
                    ballot: IJBFundingCycleBallot(address(0)),
                    metadata: 0
                })
            )
        );

        vm.mockCall(
            terminal,
            abi.encodeWithSelector(
                IJBPayoutRedemptionPaymentTerminal.directory.selector
            ),
            abi.encode(
                directory
            )
        );

        vm.mockCall(
            directory,
            abi.encodeWithSelector(
                IJBDirectory.controllerOf.selector,
                _projectId
            ),
            abi.encode(
                controller
            )
        );

        vm.mockCall(
            controller,
            abi.encodeWithSelector(
                IJBController.distributionLimitOf.selector,
                _projectId,
                _fcConfiguration, // FC configuration
                terminal,
                address(0) // token
            ),
            abi.encode(
                _distributedLimit,
                0 // _distributionLimitCurrencyOf
            )
        );

        vm.mockCall(
            store,
            abi.encodeWithSelector(
                IJBSingleTokenPaymentTerminalStore.usedDistributionLimitOf.selector,
                terminal,
                _projectId,
                _fcConfiguration // FC configuration
            ),
            abi.encode(
               _distributedAmount // distributed amount
            )
        );
    }
}