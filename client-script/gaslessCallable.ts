import hre, { ethers, web3 } from 'hardhat'
import { RelayProvider, GSNConfig, Web3ProviderBaseInterface } from '@opengsn/provider';
import forwarder from "../build/gsn/Forwarder.json";
import paymaster from "../build/gsn/Paymaster.json";
import Callable from "../out/Callable.sol/Callable.json"
import forgeScriptTransactions from "../broadcast/ConfigureLocalNetwork.sol/31337/run-latest.json";
import Web3 from 'web3';
import { AbiItem } from 'web3-utils'

async function main() {
    let JBPaymasterAddress = "0x3189e9F4193e01A184f562d73EF5c97829489034";
    let CallableAddress = "0x44e1E0aF3dFaD1cf5233e0bE82475D5D8b29a2Bb";
    
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

    console.log(JBPaymasterAddress, CallableAddress, hre.web3.currentProvider);
    //if(!hre.web3.currentProvider) return;
    console.log(hre.network.config, hre.ethers.provider);
    const provider = RelayProvider.newProvider({ provider: hre.web3.eth.currentProvider, config });
    await provider.init();

    
    const web3P = new Web3(provider);
    const from = provider.newAccount().address
    const CallableContract = new web3P.eth.Contract(Callable.abi as AbiItem[], CallableAddress);

    //console.log(Callable)
    
    // Perform the call
    console.log("The tx receipt: ", await CallableContract.methods.performCall().send({ from, gasLimit: 50000 }));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

