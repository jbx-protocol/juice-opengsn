// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";

import { JBPaymaster } from "../JBPaymaster.sol";
import { JBPaymasterCallableHandler } from "./mock/JBPaymasterCallableHandler.sol";
import { Callable } from "./mock/Callable.sol";
import { RefillOptions } from "../structs/RefillOptions.sol";

import { IPaymaster } from "@opengsn/contracts/src/interfaces/IPaymaster.sol";
import { IRelayHub } from "@opengsn/contracts/src/interfaces/IRelayHub.sol";
import { IForwarder } from "@opengsn/contracts/src/forwarder/IForwarder.sol";

import { JBProjectMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBProjectMetadata.sol";
import { JBFundingCycleData } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleData.sol";
import { JBFundingCycleMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleMetadata.sol";
import { JBGlobalFundingCycleMetadata } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBGlobalFundingCycleMetadata.sol";
import { JBGroupedSplits } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBGroupedSplits.sol";
import { JBFundingCycle } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycle.sol";
import { JBFundAccessConstraints } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundAccessConstraints.sol";
import { JBOperatorData } from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBOperatorData.sol";

import { JBConstants } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";
import { JBCurrencies } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBCurrencies.sol";
import { JBTokens } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol";
import { JBOperations } from "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol";

import { IJBProjects } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import { IJBPaymentTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
import { IJBOperatorStore } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatorStore.sol";
import { IJBController } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import { IJBDirectory } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import { IJBPayoutTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutTerminal.sol";
import { IJBFundingCycleStore } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleStore.sol";
import { IJBFundingCycleBallot } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleBallot.sol";
import { IJBPayoutRedemptionPaymentTerminal } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutRedemptionPaymentTerminal.sol";
import { IJBSingleTokenPaymentTerminalStore } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBSingleTokenPaymentTerminalStore.sol"; 

contract JBPaymasterTest is Test {
    uint256 projectId;
    JBPaymaster paymaster;
    address owner = address(0xaa71A9F7c128a3B608A32F31811a3977BfE94C39);

    IJBController controller = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
    IJBProjects projects = IJBProjects(0x21263a042aFE4bAE34F08Bb318056C181bD96D3b);
    IJBDirectory directory = IJBDirectory(0x8E05bcD2812E1449f0EC3aE24E2C395F533d9A99);
    IJBOperatorStore operatorStore = IJBOperatorStore(0x99dB6b517683237dE9C494bbd17861f3608F3585);
    IJBPayoutRedemptionPaymentTerminal ethTerminal =
        IJBPayoutRedemptionPaymentTerminal(0x55d4dfb578daA4d60380995ffF7a706471d7c719);

    IRelayHub relayhub = IRelayHub(0x40bE32219F0F106067ba95145e8F2b3e7930b201);
    IForwarder forwarder = IForwarder(0x7A95fA73250dc53556d264522150A940d4C50238);

    IJBPaymentTerminal[] internal _terminals;

    function setUp() public virtual {
        _terminals.push(ethTerminal);

        JBFundAccessConstraints[] memory _fundConstraints = new JBFundAccessConstraints[](1);
        _fundConstraints[0] = JBFundAccessConstraints({
            terminal: IJBPaymentTerminal(ethTerminal),
            token: JBTokens.ETH,
            distributionLimit: 0,
            distributionLimitCurrency: JBCurrencies.ETH,
            overflowAllowance: 2 ether,
            overflowAllowanceCurrency: JBCurrencies.ETH
        });

        // Launch the project
        projectId = controller.launchProjectFor(
            // Project is owned by this contract.
            address(owner),
            JBProjectMetadata({content: "myIPFSHash", domain: 1}),
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
    }

    function testFundPaymaster_depositFor() external {
        // Set the relayHub
        vm.prank(owner);
        paymaster.setRelayHub(relayhub);

        // Fund the paymaster/relayhub
        _fundPaymaster(paymaster, 1 ether);
    }

    function testFundPaymaster_usingAllowance() external {
        // Set the relayHub
        vm.prank(owner);
        paymaster.setRelayHub(relayhub);

        // Grant the paymaster permission to use the allowance
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = JBOperations.USE_ALLOWANCE;
        vm.prank(owner);
        operatorStore.setOperator(
            JBOperatorData({operator: address(paymaster), domain: 0, permissionIndexes: permissions})
        );

        // Fund the project
        vm.deal(address(this), 10 ether);
        ethTerminal.addToBalanceOf{value: 10 ether}(projectId, 10 ether, JBTokens.ETH, "", "");

        // Fund the paymaster using the allowance
        // Anyone may call this
        paymaster.fundFromAllowance();

        // We can't compare it exactly since JB will take a fee, so we just check if its atleast the minimum
        (uint200 refillToAmount, uint8 refillBelowPercentage,) = paymaster.refillOptions();
        assertGt(relayhub.balanceOf(address(paymaster)), refillToAmount / 100 * refillBelowPercentage);
    }

    function testPaymasterHandler() external {
        // Set the relayHub
        vm.prank(owner);
        paymaster.setRelayHub(relayhub);
        vm.prank(owner);
        paymaster.setTrustedForwarder(address(forwarder));

        // Fund the paymaster/relayhub
        _fundPaymaster(paymaster, 1 ether);

        // Deploy the mock handler
        JBPaymasterCallableHandler _handler = new JBPaymasterCallableHandler();
        Callable _callable = new Callable(
          address(forwarder)
        );

        // Register the handler
        vm.prank(owner);
        paymaster.setHandler(address(_callable), Callable.performCall.selector, _handler, false);
    }

    function _fundPaymaster(IPaymaster _paymaster, uint256 _amount) private {
        IRelayHub _relayHub = IRelayHub(_paymaster.getRelayHub());
        assertTrue(address(_relayHub) != address(0), "Can not fund the paymaster if no relayhub is set");

        uint256 _balanceBefore = _relayHub.balanceOf(address(paymaster));

        // Fund the paymaster/relayhub
        vm.deal(owner, address(owner).balance + _amount);
        vm.prank(owner);
        _relayHub.depositFor{value: _amount}(address(_paymaster));

        // Make sure the paymaster is now funded
        assertEq(relayhub.balanceOf(address(_paymaster)), _balanceBefore + _amount);
    }
}
