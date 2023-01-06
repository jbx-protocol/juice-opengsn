# Juicebox OpenGSN (WIP)
Extension to allow customizable usage of GSN from a Juicebox project

*This uses the OpenGSN V3 contracts which are not available on mainnet yet*

## Why?
Juicebox projects may want to incentivize users to perform certain actions by paying gas for its users. Some examples of this are:
- Pay the gas for a user when they pay the project more than 100 DAI
- Pay the gas for a user when they are voting in governance
- Pay the gas for a user when they call `distribute`
- Allow automating on-chain tasks (like cron jobs)

This extension attempts to create a minimal base implementation that can be build upon and configured by projects to their liking.

## Testing
This repo contains both forge tests and a E2E test using both forge and hardhat (this combo is needed as OpenGSN uses hardhat). Make sure to run `yarn install` before attempting either of the below tests. 

### To run the forge tests
```
forge test --fork-url [Gorli-RPC-URL] --via-ir 
```

### To run the E2E test
Create a `.secret` file and in it place a mnemonic, this can be an empty wallet it will get funded automatically. Edit `launch-local-testnet.sh` and replace the `sender` address with one from the mnemonic you entered.
```
bash launch-local-testnet.sh
```