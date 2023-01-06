// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/JBPaymaster.sol";
import "../src/forge-test/mock/JBPaymasterCallableHandler.sol";
import "../src/forge-test/mock/Callable.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatorStore.sol";

contract ConfigureGoerli is Script {
    uint256 projectId;
    JBPaymaster paymaster;
    //address owner = address(0xaa71A9F7c128a3B608A32F31811a3977BfE94C39);

    IJBController controller = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
    IJBProjects projects = IJBProjects(0x21263a042aFE4bAE34F08Bb318056C181bD96D3b);
    IJBDirectory directory = IJBDirectory(0x8E05bcD2812E1449f0EC3aE24E2C395F533d9A99);
    IJBOperatorStore operatorStore = IJBOperatorStore(0x99dB6b517683237dE9C494bbd17861f3608F3585);
    IJBPayoutRedemptionPaymentTerminal ethTerminal =
        IJBPayoutRedemptionPaymentTerminal(0x55d4dfb578daA4d60380995ffF7a706471d7c719);


    IRelayHub relayhub = IRelayHub(0x40bE32219F0F106067ba95145e8F2b3e7930b201);
    IForwarder forwarder = IForwarder(0x7A95fA73250dc53556d264522150A940d4C50238);

    IJBPaymentTerminal[] internal _terminals;

    function setUp() public {
        //console.log(msg.sender);
    }

    function run() public {
        vm.etch(address(this), "");
        // Have the project use the ETH terminal
        _terminals.push(ethTerminal);
        // Create the fund access constraints to allow the paymaster to fund itself
        JBFundAccessConstraints[] memory _fundConstraints = new JBFundAccessConstraints[](1);
        _fundConstraints[0] = JBFundAccessConstraints({
            terminal: IJBPaymentTerminal(ethTerminal),
            token: JBTokens.ETH,
            distributionLimit: 0,
            distributionLimitCurrency: JBCurrencies.ETH,
            overflowAllowance: 2 ether,
            overflowAllowanceCurrency: JBCurrencies.ETH
        });

        vm.startBroadcast(msg.sender);
        // Launch the project
        projectId = controller.launchProjectFor(
            address(msg.sender),
            JBProjectMetadata({content: "QmRLHKtwdedZ7aVxi5JzKP8qx9F4xmb79qR7iiYpGkwvcH", domain: 0}),
            JBFundingCycleData({
                duration: 1 weeks,
                // Don't mint project tokens.
                weight: 0,
                discountRate: 0,
                ballot: IJBFundingCycleBallot(address(0))
            }),
            JBFundingCycleMetadata({
                global: JBGlobalFundingCycleMetadata({
                    allowSetTerminals: false,
                    allowSetController: false,
                    pauseTransfers: false
                }),
                reservedRate: 0,
                // Full refunds.
                redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
                ballotRedemptionRate: JBConstants.MAX_REDEMPTION_RATE,
                pausePay: false,
                pauseDistributions: false,
                pauseRedeem: false,
                pauseBurn: false,
                allowMinting: false,
                allowTerminalMigration: false,
                allowControllerMigration: false,
                holdFees: false,
                preferClaimedTokenOverride: false,
                useTotalOverflowForRedemptions: false,
                useDataSourceForPay: true,
                useDataSourceForRedeem: true,
                dataSource: address(0),
                metadata: 0
            }),
            0,
            new JBGroupedSplits[](0),
            _fundConstraints,
            _terminals,
            ""
        );

        // Deploy a paymaster for this project
        paymaster = new JBPaymaster(
            projectId,
            projects,
            directory,
            operatorStore
        );

        // Set the relayhub and forwarder
        paymaster.setRelayHub(relayhub);
        paymaster.setTrustedForwarder(address(forwarder));

        // Deploy the mock handler
        JBPaymasterCallableHandler _handler = new JBPaymasterCallableHandler();
        Callable _callable = new Callable(
            address(forwarder)
        );

        // Register the handler
        paymaster.setHandler(address(_callable), Callable.performCall.selector, _handler);

        // Fund the Paymaster
        relayhub.depositFor{value: 0.1 ether}(address(paymaster));

        // Grant the paymaster permission to use the allowance
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = JBOperations.USE_ALLOWANCE;
        operatorStore.setOperator(
            JBOperatorData({operator: address(paymaster), domain: 0, permissionIndexes: permissions})
        );

        vm.stopBroadcast();

        console.log("Project ID is: ", projectId);
        console.log("JBPaymaster address is: ", address(paymaster));
        console.log("Callable address is: ", address(_callable));
    }
}
