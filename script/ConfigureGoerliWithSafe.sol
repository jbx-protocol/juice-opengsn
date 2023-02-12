// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";

import { JBPaymaster } from "../src/JBPaymaster.sol";
import { JBPaymasterCallableHandler } from "../src/forge-test/mock/JBPaymasterCallableHandler.sol";
import { JBPaymasterAllowAllHandler } from "../src/handlers/JBPaymasterAllowAllHandler.sol";
import { Callable } from "../src/forge-test/mock/Callable.sol";

import { SafeProxyFactory } from "@safe-global/contracts/proxies/SafeProxyFactory.sol";
import { Safe } from "@safe-global/contracts/Safe.sol";

import { IForwarder } from "@opengsn/contracts/src/forwarder/IForwarder.sol";
import { IRelayHub } from "@opengsn/contracts/src/interfaces/IRelayHub.sol";

import { JBProjectMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBProjectMetadata.sol";
import { JBFundingCycleData } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleData.sol";
import { JBFundingCycleMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleMetadata.sol";
import { JBGlobalFundingCycleMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBGlobalFundingCycleMetadata.sol";
import { JBGroupedSplits } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBGroupedSplits.sol";
import { JBFundingCycle } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycle.sol";
import { JBFundAccessConstraints } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundAccessConstraints.sol";

import { JBConstants } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";

import { IJBProjects } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import { IJBPaymentTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
import { IJBOperatorStore } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatorStore.sol";
import { IJBController } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import { IJBDirectory } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import { IJBFundingCycleBallot } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleBallot.sol";
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

    // Safe specific addresses
    SafeProxyFactory safeProxyFactory = SafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
    Safe safeSingleton = Safe(payable(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552));

    IRelayHub relayhub = IRelayHub(0x40bE32219F0F106067ba95145e8F2b3e7930b201);
    IForwarder forwarder = IForwarder(0x7A95fA73250dc53556d264522150A940d4C50238);

    IJBPaymentTerminal[] internal _terminals;

    function setUp() public {
        //console.log(msg.sender);
    }

    function run() public {
        vm.etch(address(this), "");
        vm.startBroadcast(msg.sender);

        address _safe = _createNewSafe(
            safeProxyFactory,
            safeSingleton,
            msg.sender
        );

        // Have the project use the ETH terminal
        _terminals.push(ethTerminal);

        // Launch the project
        projectId = controller.launchProjectFor(
            _safe,
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
            new JBFundAccessConstraints[](0),
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

        // Register the allow all handler for the safe
        JBPaymasterAllowAllHandler _allowAllHandler = new JBPaymasterAllowAllHandler();
        paymaster.setHandler(
            _safe,
            Safe.execTransaction.selector,
            _allowAllHandler,
            true
        );

        // Fund the Paymaster
        relayhub.depositFor{value: 0.2 ether}(address(paymaster));

        // Transfer ownership of the Paymaster to the project
        paymaster.transferOwnershipToProject(projectId);

        vm.stopBroadcast();

        console.log("Project ID is: ", projectId);
        console.log("Safe is at address: ", _safe);
        console.log("JBPaymaster address is: ", address(paymaster));
        console.log("AllowAllHandler address is: ", address(_allowAllHandler));
        console.log("Registered terminal for distributions is: ", address(ethTerminal));
    }


    function _createNewSafe(
        SafeProxyFactory _factory,
        Safe _singleton,
        address _owner
    ) internal returns (address) {

        address[] memory _owners = new address[](1);
        _owners[0] = _owner;

        bytes memory _calldata = abi.encodeWithSelector(
            Safe.setup.selector,
            _owners,   // owners
            1,          // threshold
            address(0), // to
            bytes(''),    // data
            address(0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4), // fallback handler (default handler)
            address(0), // paymentToken
            0,          // payment
            address(0)  // paymentReceiver
        );
        
        return address(_factory.createProxyWithNonce(address(_singleton), _calldata, 890127987));
    }
}
