
# If any step fails we want to kill all processes
trap 'kill $(jobs -pr)' SIGINT SIGTERM EXIT
# Have OpenGSN CLI start a local node and deploy the contracts 
npx gsn start --withNode &
# Optimistically wait 10 seconds and start the foundry script on the hardhat node
sleep 10
# Deploy the JBX-OpenGSN contracts
forge script ./script/ConfigureLocalNetwork.sol --via-ir --fork-url http://127.0.0.1:8545 --mnemonic-paths .secret --slow --broadcast -vvvv --sender 0x64a5496bf70c3800d7b7b606725c6f6239c7446b
sleep 1000