#!/bin/bash
DEBUG=false

while getopts ":d" opt; do
  case ${opt} in
    d) 
      DEBUG=true
      ;;
    \?) 
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done

# Start the gsn relay asynchronously in the background
echo "Staring the hardhat node and GNS relayer..."
if [ "$DEBUG" = true ]; then
  npx gsn start --withNode 2>&1 | tee /tmp/gsn_output.txt &
else
  npx gsn start --withNode > /tmp/gsn_output.txt 2>&1 &
fi

# Save the process id of the gsn relay
GSN_RELAY_PID=$!

# Sleep the main script until the gsn relay outputs "Relay is active,"
# but keep the gsn relay running in the background
while true; do
  if grep -q "Relay is active, URL" /tmp/gsn_output.txt; then
    break
  fi
  sleep 1
done

# Run the forge script
echo "Compiling contracts and running the script on the local node..."
forge script ./script/ConfigureLocalNetwork.sol --via-ir --fork-url http://127.0.0.1:8545 --mnemonic-paths .secret --slow --broadcast -vvvv --sender 0x64a5496bf70c3800d7b7b606725c6f6239c7446b

if [ $? -ne 0 ]; then
  # If the previous command failed, kill the gsn relay and report an error
  kill $GSN_RELAY_PID
  echo "Error: Failed to run forge script" >&2
  exit 1
fi

# Run the hardhat script
npx hardhat run client-script/gaslessCallable.ts --network local

if [ $? -ne 0 ]; then
  # If the previous command failed, kill the gsn relay and report an error
  kill $GSN_RELAY_PID
  echo "Error: Failed to run hardhat script" >&2
  exit 1
fi

# If both commands run successfully, kill the gsn relay
kill $GSN_RELAY_PID
