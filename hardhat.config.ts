// Note: Do not edit, this only gets used to setup a local environment because OpenGSN uses hardhat.
// Everything else uses Foundry
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-web3";
import type { HardhatUserConfig } from "hardhat/config";
import { readFileSync } from 'fs';
const mnemonic = readFileSync('./.secret', 'utf-8');

import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";

task("accounts", "Prints the list of accounts", async (_taskArgs, hre) => {
  const accounts: Signer[] = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress());
  }
});

if (!mnemonic) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      accounts: {
        mnemonic,
      }
    },
    goerli: {
      url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
      accounts: {
        mnemonic,
      }
    },
    local: {
      url: "http://127.0.0.1:8545",
      accounts: {
        mnemonic,
      }
    }
  },

  solidity: {
    version: "0.8.17",
  }
};

export default config;