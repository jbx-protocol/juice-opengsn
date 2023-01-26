import hre, { ethers, web3 } from 'hardhat'
import { RelayProvider, GSNConfig, Web3ProviderBaseInterface } from '@opengsn/provider';
import forwarder from "../build/gsn/Forwarder.json";
import paymaster from "../build/gsn/Paymaster.json";
import Callable from "../out/Callable.sol/Callable.json"
import TerminalABI from "../out/JBETHPaymentTerminal.sol/JBETHPaymentTerminal.json";
import forgeScriptTransactions from "../broadcast/ConfigureLocalNetwork.sol/31337/run-latest.json";
import Web3 from 'web3';
import { AbiItem } from 'web3-utils'

async function main() {
    let JBPaymasterAddress = "0x205d871722cb1da1d0c9A24199fc1A886Dc5F9A4";
    let terminalAddress = "0x55d4dfb578daA4d60380995ffF7a706471d7c719";
    let projectId = 306;
    let amount = ethers.utils.parseEther("0.1");

    // for (let index = 0; index < forgeScriptTransactions.transactions.length; index++) {
    //     const tx = forgeScriptTransactions.transactions[index];
    //     if(tx.contractName == "JBPaymaster"){
    //         JBPaymasterAddress = tx.contractAddress;
    //     }
    
    //     if(tx.contractName == "Callable"){
    //         CallableAddress = tx.contractAddress;
    //     }
    // }
    
    const config: Partial<GSNConfig> = { 
        paymasterAddress: JBPaymasterAddress,
        loggerConfiguration: {
            logLevel: 'debug'
        }
    }

    //console.log(JBPaymasterAddress, CallableAddress, hre.web3.currentProvider);
    //if(!hre.web3.currentProvider) return;
    //console.log(hre.network.config, hre.ethers.provider);
    const provider = RelayProvider.newProvider({ provider: hre.web3.eth.currentProvider as any, config });
    await provider.init();

    
    const web3P = new Web3(provider);
    const from = provider.newAccount().address
    const CallableContract = new web3P.eth.Contract(TerminalABI.abi as AbiItem[], terminalAddress);

    //console.log(Callable)
    
    // Perform the call
    console.log("The tx receipt: ",
     await CallableContract.methods.distributePayoutsOf(
        projectId,
        amount,
        1, // JBCurrencies.ETH
        "0x000000000000000000000000000000000000EEEe", // JBTokens.ETH
        0,
        "⛽ OpenGSN Distribute",
     ).send({ from, gasLimit: 300000 }));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

