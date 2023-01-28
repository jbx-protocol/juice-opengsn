import hre, { ethers, web3 } from 'hardhat'
import Web3Adapter from '@safe-global/safe-web3-lib'
import Safe, { SafeFactory } from '@safe-global/safe-core-sdk'
import SafeServiceClient from '@safe-global/safe-service-client'
import { SafeTransactionDataPartial } from '@safe-global/safe-core-sdk-types'
import { RelayProvider, GSNConfig, Web3ProviderBaseInterface } from '@opengsn/provider';
import forwarder from "../build/gsn/Forwarder.json";
import paymaster from "../build/gsn/Paymaster.json";
import Callable from "../out/Callable.sol/Callable.json"
import TerminalABI from "../out/JBETHPaymentTerminal.sol/JBETHPaymentTerminal.json";
import forgeScriptTransactions from "../broadcast/ConfigureLocalNetwork.sol/31337/run-latest.json";
import Web3 from 'web3';
import { AbiItem } from 'web3-utils'

async function main() {
    let JBPaymasterAddress = "0x55594C11540f75aEF83cB31049942F42D2b36a61";
    let safeAddress = "0xC9074Ec91075b03F9Bd39be0FD68a19A517B893F";
    let safeTxHash = "0x7fc69645ef0ceeb3caa40cfb258088966e80fdd98ff9d048bcb2f138b9969969";

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
    const from = "0x64a5496bf70C3800d7B7b606725c6F6239c7446B"

    // Initialize the web3 adapter for safe
    const ethAdapter = new Web3Adapter({
        web3: web3P,
        signerAddress: from
    })
   
    // Initialize the Safe Service
    const txServiceUrl = 'https://safe-transaction.goerli.gnosis.io'
    const safeService = new SafeServiceClient({ txServiceUrl, ethAdapter })

    // Initialize the Safe SDK
    const safeFactory = await SafeFactory.create({ ethAdapter })
    const safeSdk = await Safe.create({ ethAdapter, safeAddress })

    // 
    const calldata = "0x7cd485a5";//new web3P.eth.Contract(Callable.abi as AbiItem[]).methods.performCall().encodeABI();

    if(safeTxHash == ""){
        // Create a new safe transaction
        const safeTransactionData: SafeTransactionDataPartial = {
            to: "0x0702f6e896cFa61F85E8b38dA99bDf1022De04ca", // Callable contract
            data: calldata,
            value: "0",
            // operation, // Optional
            // safeTxGas, // Optional
            // baseGas, // Optional
            // gasPrice, // Optional
            // gasToken, // Optional
            // refundReceiver, // Optional
            // nonce // Optional
        }
        const safeTransaction = await safeSdk.createTransaction({ safeTransactionData })

        safeTxHash = await safeSdk.getTransactionHash(safeTransaction)
        const senderSignature = await safeSdk.signTransactionHash(safeTxHash)

        await safeService.proposeTransaction({
            safeAddress,
            safeTransactionData: safeTransaction.data,
            safeTxHash,
            senderAddress: from,
            senderSignature: senderSignature.data
        })

        // Sign the transaction
        //const hash = safeTransaction.safeTxHash
        //let signature = await safeSdk.signTransactionHash(safeTxHash)
        //await safeService.confirmTransaction(safeTxHash, signature.data)
    }
    
    //safeService.proposeTransaction()
    const safeTransaction = await safeService.getTransaction(safeTxHash);
    console.log(safeTransaction);
    const isValidTx = await safeSdk.isValidTransaction(safeTransaction)
    const executeTxResponse = await safeSdk.executeTransaction(safeTransaction)
    const receipt = executeTxResponse.transactionResponse && (await executeTxResponse.transactionResponse.wait())
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

