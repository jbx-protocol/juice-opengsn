// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";

import { JBPaymaster } from "../src/JBPaymaster.sol";
import { JBPaymasterCallableHandler } from "../src/forge-test/mock/JBPaymasterCallableHandler.sol";
import { JBPaymasterDistributeHandler } from "../src/handlers/JBPaymasterDistributeHandler.sol";
import { Callable } from "../src/forge-test/mock/Callable.sol";

import { IForwarder } from "@opengsn/contracts/src/forwarder/IForwarder.sol";
import { IRelayHub } from "@opengsn/contracts/src/interfaces/IRelayHub.sol";

import { JBProjectMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBProjectMetadata.sol";
import { JBFundingCycleData } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleData.sol";
import { JBFundingCycleMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleMetadata.sol";
import { JBGlobalFundingCycleMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBGlobalFundingCycleMetadata.sol";
import { JBGroupedSplits } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBGroupedSplits.sol";
import { JBSplit } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBSplit.sol";
import { JBFundAccessConstraints } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundAccessConstraints.sol";
import { JBOperatorData } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBOperatorData.sol";

import { JBConstants } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";
import { JBCurrencies } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBCurrencies.sol";
import { JBTokens } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol";
import { JBSplitsGroups } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBSplitsGroups.sol";
import { JBOperations } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol";

import { IJBProjects } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import { IJBPaymentTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
import { IJBSplitAllocator } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBSplitAllocator.sol";
import { IJBOperatorStore } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatorStore.sol";
import { IJBController } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import { IJBDirectory } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import { IJBFundingCycleBallot } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleBallot.sol";
import { IJBPayoutTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutTerminal.sol";
import { IJBPayoutRedemptionPaymentTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutRedemptionPaymentTerminal.sol";

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
        vm.startBroadcast(msg.sender);

        // Optimistically get the ProjectID (NOTE: THIS IS NOT SAFE TO DO IN PRODUCTION! AND MAY LEAD TO LOSS OF FUNDS)
        uint256 _optimisticProjectID = directory.projects().count() + 1;

        // Deploy a paymaster for this project
        paymaster = new JBPaymaster(
            _optimisticProjectID,
            projects,
            directory,
            operatorStore
        );

        // Have the project use the ETH terminal
        _terminals.push(ethTerminal);
        // Create the fund access constraints to allow the paymaster to fund itself
        JBFundAccessConstraints[] memory _fundConstraints = new JBFundAccessConstraints[](1);
        _fundConstraints[0] = JBFundAccessConstraints({
            terminal: IJBPaymentTerminal(ethTerminal),
            token: JBTokens.ETH,
            distributionLimit: 0.1 ether,
            distributionLimitCurrency: JBCurrencies.ETH,
            overflowAllowance: 2 ether,
            overflowAllowanceCurrency: JBCurrencies.ETH
        });

        // Distribution split
        JBSplit[] memory _split = new JBSplit[](2);

        // Fund the paymaster
        _split[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 100 * 10,
            projectId: 0,
            beneficiary: payable(0),
            lockedUntil: 0,
            allocator: IJBSplitAllocator(paymaster)
        });

        // Fund the project owner
        _split[1] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 100 * 90,
            projectId: 0,
            beneficiary: payable(msg.sender),
            lockedUntil: 0,
            allocator: IJBSplitAllocator(address(0))
        });

        JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1);
        _groupedSplits[0] = JBGroupedSplits({
            group: JBSplitsGroups.ETH_PAYOUT,
            splits: _split
        });

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
            _groupedSplits,
            _fundConstraints,
            _terminals,
            ""
        );

        // Set the relayhub and forwarder
        paymaster.setRelayHub(relayhub);
        paymaster.setTrustedForwarder(address(forwarder));

        // Deploy the test handler and register it
        JBPaymasterCallableHandler _callableHandler = new JBPaymasterCallableHandler();
        Callable _callable = new Callable(
            address(forwarder)
        );
        paymaster.setHandler(address(_callable), Callable.performCall.selector, _callableHandler, false);

        // Deploy the distribute handler and register the terminal call
        JBPaymasterDistributeHandler _distributeHandler = new JBPaymasterDistributeHandler();
        paymaster.setHandler(
            address(ethTerminal),
            IJBPayoutTerminal.distributePayoutsOf.selector,
            _distributeHandler,
            false
        );

        // Fund the Paymaster
        relayhub.depositFor{value: 0.2 ether}(address(paymaster));

        // Fund the project
        ethTerminal.addToBalanceOf{value: 0.1 ether}(
            projectId,
            0.1 ether,
            JBTokens.ETH,
            '',
            ''
        );

        // Grant the paymaster permission to use the allowance
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = JBOperations.USE_ALLOWANCE;
        operatorStore.setOperator(
            JBOperatorData({operator: address(paymaster), domain: 0, permissionIndexes: permissions})
        );

        // ethTerminal.distributePayoutsOf(
        //     projectId,
        //     0.1 ether,
        //     JBCurrencies.ETH,
        //     JBTokens.ETH,
        //     0,
        //     ''
        // );

        vm.stopBroadcast();

        console.log("Project ID is: ", projectId);
        console.log("Optimistic ID was: ", _optimisticProjectID);
        console.log("JBPaymaster address is: ", address(paymaster));
        console.log("Callable address is: ", address(_callable));
        console.log("Registered terminal for distributions is: ", address(ethTerminal));
    }
}
