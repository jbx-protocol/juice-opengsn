// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "forge-std/Script.sol";

import "../src/JBPaymaster.sol";
import "../src/forge-test/mock/JBPaymasterCallableHandler.sol";
import "../src/forge-test/mock/Callable.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/JBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBDirectory.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBETHPaymentTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBERC20PaymentTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBSingleTokenPaymentTerminalStore.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBFundingCycleStore.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBOperatorStore.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBPrices.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBProjects.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBSplitsStore.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBToken.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/JBTokenStore.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidPayData.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidRedeemData.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFee.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundAccessConstraints.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycle.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleData.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleMetadata.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBGroupedSplits.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBOperatorData.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayParamsData.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBProjectMetadata.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedeemParamsData.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBSplit.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBToken.sol";

import "../src/forge-test/mock/AccessJBLib.sol";

//import '@paulrberg/contracts/math/PRBMath.sol';

// Base contract for Juicebox system tests.
//
// Provides common functionality, such as deploying contracts on test setup.
contract TestBaseWorkflow is Script {
    //*********************************************************************//
    // --------------------- private stored properties ------------------- //
    //*********************************************************************//

    // Multisig address used for testing.
    address private _multisig = address(123);
    address private _beneficiary = address(69420);

    IRelayHub relayhub;
    IForwarder forwarder;

    // EVM Cheat codes - test addresses via prank and startPrank in hevm
    //Hevm public evm = Hevm(HEVM_ADDRESS);

    // JBOperatorStore
    JBOperatorStore private _jbOperatorStore;
    // JBProjects
    JBProjects private _jbProjects;
    // JBPrices
    JBPrices private _jbPrices;
    // JBDirectory
    JBDirectory private _jbDirectory;
    // JBFundingCycleStore
    JBFundingCycleStore private _jbFundingCycleStore;
    // JBToken
    JBToken private _jbToken;
    // JBTokenStore
    JBTokenStore private _jbTokenStore;
    // JBSplitsStore
    JBSplitsStore private _jbSplitsStore;
    // JBController
    JBController private _jbController;
    // JBETHPaymentTerminalStore
    JBSingleTokenPaymentTerminalStore private _jbPaymentTerminalStore;
    // JBETHPaymentTerminal
    JBETHPaymentTerminal private _jbETHPaymentTerminal;
    // JBERC20PaymentTerminal
    JBERC20PaymentTerminal private _jbERC20PaymentTerminal;
    // AccessJBLib
    AccessJBLib private _accessJBLib;

    //*********************************************************************//
    // ------------------------- internal views -------------------------- //
    //*********************************************************************//

    function multisig() internal view returns (address) {
        return _multisig;
    }

    function beneficiary() internal view returns (address) {
        return _beneficiary;
    }

    function jbOperatorStore() internal view returns (JBOperatorStore) {
        return _jbOperatorStore;
    }

    function jbProjects() internal view returns (JBProjects) {
        return _jbProjects;
    }

    function jbPrices() internal view returns (JBPrices) {
        return _jbPrices;
    }

    function jbDirectory() internal view returns (JBDirectory) {
        return _jbDirectory;
    }

    function jbFundingCycleStore() internal view returns (JBFundingCycleStore) {
        return _jbFundingCycleStore;
    }

    function jbTokenStore() internal view returns (JBTokenStore) {
        return _jbTokenStore;
    }

    function jbSplitsStore() internal view returns (JBSplitsStore) {
        return _jbSplitsStore;
    }

    function jbController() internal view returns (JBController) {
        return _jbController;
    }

    function jbPaymentTerminalStore() internal view returns (JBSingleTokenPaymentTerminalStore) {
        return _jbPaymentTerminalStore;
    }

    function jbETHPaymentTerminal() internal view returns (JBETHPaymentTerminal) {
        return _jbETHPaymentTerminal;
    }

    function jbERC20PaymentTerminal() internal view returns (JBERC20PaymentTerminal) {
        return _jbERC20PaymentTerminal;
    }

    function jbToken() internal view returns (JBToken) {
        return _jbToken;
    }

    function jbLibraries() internal view returns (AccessJBLib) {
        return _accessJBLib;
    }

    function setUp() public {
        // Parse hardhat ABIs to get the deployed addresses of the contracts we need
        (relayhub) = abi.decode(vm.parseJson(vm.readFile("build/gsn/RelayHub.json"), "address"), (IRelayHub));

        (forwarder) = abi.decode(vm.parseJson(vm.readFile("build/gsn/Forwarder.json"), "address"), (IForwarder));

        console.log("RelayHub address is ", address(relayhub));
        console.log("Forwarder address is ", address(forwarder));
    }

    //*********************************************************************//
    // --------------------------- test setup ---------------------------- //
    //*********************************************************************//

    // Deploys and initializes contracts for testing.
    function run() public {
        _multisig = msg.sender;
        vm.startBroadcast(_multisig);

        // JBOperatorStore
        _jbOperatorStore = new JBOperatorStore();
        // JBProjects
        _jbProjects = new JBProjects(_jbOperatorStore);
        // JBPrices
        _jbPrices = new JBPrices(_multisig);
        address contractAtNoncePlusOne = addressFrom(address(_multisig), vm.getNonce(_multisig) + 1);
        // JBFundingCycleStore
        _jbFundingCycleStore = new JBFundingCycleStore(IJBDirectory(contractAtNoncePlusOne));
        // JBDirectory
        _jbDirectory = new JBDirectory(_jbOperatorStore, _jbProjects, _jbFundingCycleStore, _multisig);
        // JBTokenStore
        _jbTokenStore = new JBTokenStore(
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbFundingCycleStore
    );
        // JBSplitsStore
        _jbSplitsStore = new JBSplitsStore(_jbOperatorStore, _jbProjects, _jbDirectory);
        // JBController
        _jbController = new JBController(
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbFundingCycleStore,
      _jbTokenStore,
      _jbSplitsStore
    );
        _jbDirectory.setIsAllowedToSetFirstController(address(_jbController), true);
        // JBETHPaymentTerminalStore
        _jbPaymentTerminalStore = new JBSingleTokenPaymentTerminalStore(
      _jbDirectory,
      _jbFundingCycleStore,
      _jbPrices
    );
        // AccessJBLib
        _accessJBLib = new AccessJBLib();
        // JBETHPaymentTerminal
        _jbETHPaymentTerminal = new JBETHPaymentTerminal(
      _accessJBLib.ETH(),
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbSplitsStore,
      _jbPrices,
      _jbPaymentTerminalStore,
      _multisig
    );
        //vm.prank(_multisig);
        _jbToken = new JBToken('MyToken', 'MT', 1);
        //vm.prank(_multisig);
        _jbToken.mint(1, _multisig, 100 * 10 ** 18);
        // JBERC20PaymentTerminal
        _jbERC20PaymentTerminal = new JBERC20PaymentTerminal(
      _jbToken,
      _accessJBLib.ETH(), // currency
      _accessJBLib.ETH(), // base weight currency
      1, // JBSplitsGroupe
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbSplitsStore,
      _jbPrices,
      _jbPaymentTerminalStore,
      _multisig
    );

        // Done with the Juicebox aspect, lets label them
        vm.label(_multisig, "projectOwner");
        vm.label(_beneficiary, "beneficiary");
        vm.label(address(_jbOperatorStore), "JBOperatorStore");
        vm.label(address(_jbProjects), "JBProjects");
        vm.label(address(_jbPrices), "JBPrices");
        vm.label(address(_jbFundingCycleStore), "JBFundingCycleStore");
        vm.label(address(_jbDirectory), "JBDirectory");
        vm.label(address(_jbTokenStore), "JBTokenStore");
        vm.label(address(_jbSplitsStore), "JBSplitsStore");
        vm.label(address(_jbController), "JBController");
        vm.label(address(_jbETHPaymentTerminal), "JBETHPaymentTerminal");
        vm.label(address(_jbPaymentTerminalStore), "JBSingleTokenPaymentTerminalStore");
        vm.label(address(_jbERC20PaymentTerminal), "JBERC20PaymentTerminal");

        //vm.etch(address(this), "");

        IJBPaymentTerminal[] memory _terminals = new IJBPaymentTerminal[](1);
        _terminals[0] = _jbETHPaymentTerminal;

        // Start deploying the JBX <-> GSN contracts

        // Launch the project
        uint256 projectId = _jbController.launchProjectFor(
            // Project is owned by this contract.
            _multisig,
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
            new JBFundAccessConstraints[](0),
            _terminals,
            ""
        );

        // Deploy a paymaster for this project
        JBPaymaster paymaster = new JBPaymaster(
        projectId,
        _jbProjects,
        _jbDirectory,
        _jbOperatorStore
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
    }

    //https://ethereum.stackexchange.com/questions/24248/how-to-calculate-an-ethereum-contracts-address-during-its-creation-using-the-so
    function addressFrom(address _origin, uint256 _nonce) internal pure returns (address _address) {
        bytes memory data;
        if (_nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
        } else if (_nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
        } else if (_nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
        } else if (_nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
        } else if (_nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
        }
        bytes32 hash = keccak256(data);
        assembly {
            mstore(0, hash)
            _address := mload(0)
        }
    }
}
