// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../JBPaymaster.sol";
import "./mock/JBPaymasterCallableHandler.sol";
import "./mock/Callable.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBCurrencies.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatorStore.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayoutRedemptionPaymentTerminal.sol";

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
        assertGt(relayhub.balanceOf(address(paymaster)), paymaster.refillBelow());
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
        paymaster.setHandler(address(_callable), Callable.performCall.selector, _handler);
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
