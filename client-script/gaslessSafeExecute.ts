import hre, { ethers, web3 } from 'hardhat'
import Web3Adapter from '@safe-global/safe-web3-lib'
import Safe, { SafeFactory } from '@safe-global/safe-core-sdk'
import SafeServiceClient from '@safe-global/safe-service-client'
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
    let safeAddress = "";
    let safeTxHash = "";

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

    // Wrap our provider with the OpenGSN wrapper
    const provider = RelayProvider.newProvider({ provider: hre.web3.eth.currentProvider as any, config });
    await provider.init();
    
    // Create the Web3 Provider ad signer
    const web3P = new Web3(provider);
    const from = provider.newAccount().address

    // Initialize the web3 adapter for safe
    const ethAdapter = new Web3Adapter({
        web3P,
        signerAddress: from
    })
   
    // Initialize the Safe Service
    const txServiceUrl = 'https://safe-transaction-mainnet.safe.global'
    const safeService = new SafeServiceClient({ txServiceUrl, ethAdapter })

    // Initialize the Safe SDK
    const safeFactory = await SafeFactory.create({ ethAdapter })
    const safeSdk = await Safe.create({ ethAdapter, safeAddress })

    const safeTransaction = await safeService.getTransaction(safeTxHash);
    const executeTxResponse = await safeSdk.executeTransaction(safeTransaction)
    const receipt = executeTxResponse.transactionResponse && (await executeTxResponse.transactionResponse.wait())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

