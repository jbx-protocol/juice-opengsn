import hre from 'hardhat'
import Web3Adapter from '@safe-global/safe-web3-lib'
import Safe, { SafeFactory } from '@safe-global/safe-core-sdk'
import SafeServiceClient from '@safe-global/safe-service-client'
import { SafeTransactionDataPartial } from '@safe-global/safe-core-sdk-types'
import { RelayProvider, GSNConfig } from '@opengsn/provider';
import Web3 from 'web3';

async function main() {

    /**
     * Config Options
    */

    let JBPaymasterAddress = "0x55594C11540f75aEF83cB31049942F42D2b36a61";
    let safeAddress = "0xC9074Ec91075b03F9Bd39be0FD68a19A517B893F";
    let safeOwner = "0x64a5496bf70C3800d7B7b606725c6F6239c7446B";

    // The tx hash to execute (optional: if empty a new tx will be build)
    let safeTxHash = "";

    // If `safeTxHash` is empty the following will be used
    // `performCall` method on the `Callable` mock contract
    const calldata = "0x7cd485a5";
    // Callable contract
    const callTarget = "0x0702f6e896cFa61F85E8b38dA99bDf1022De04ca";
    
    const config: Partial<GSNConfig> = { 
        paymasterAddress: JBPaymasterAddress,
        loggerConfiguration: {
            logLevel: 'debug'
        }
    }

    /**
     * Logic
     */

    // Wrap our provider with the OpenGSN wrapper
    const provider = RelayProvider.newProvider({ provider: hre.web3.eth.currentProvider as any, config });
    await provider.init();
    
    // Create the Web3 Provider ad signer
    const web3P = new Web3(provider);
    const from = provider.newAccount().address

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

    if(safeTxHash == ""){
        // Initialize the web3 adapter for the safe owner
        const safeOwnerSdk = await Safe.create({ 
            ethAdapter: new Web3Adapter({
                web3: web3P,
                signerAddress: safeOwner
            }),
            safeAddress
         })

        // Create a new safe transaction
        const safeTransactionData: SafeTransactionDataPartial = {
            to: callTarget,
            data: calldata,
            value: "0"
        }
        const safeTransaction = await safeOwnerSdk.createTransaction({ safeTransactionData })

        // Sign the transaction with the owners wallet
        safeTxHash = await safeOwnerSdk.getTransactionHash(safeTransaction)
        const senderSignature = await safeOwnerSdk.signTransactionHash(safeTxHash)

        // Propose the signed transaction
        await safeService.proposeTransaction({
            safeAddress,
            safeTransactionData: safeTransaction.data,
            safeTxHash,
            senderAddress: safeOwner,
            senderSignature: senderSignature.data
        })
    }
    
    // Get the existing (or new) transaction from the service
    const safeTransaction = await safeService.getTransaction(safeTxHash);
    // Validate it being a valid transaction
    const isValidTx = await safeSdk.isValidTransaction(safeTransaction)

    // Execute the transaction using OpenGSN with the Juicebox paymaster
    const executeTxResponse = await safeSdk.executeTransaction(safeTransaction)
    // Get the execution receipt
    const receipt = executeTxResponse.transactionResponse && (await executeTxResponse.transactionResponse.wait())
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

