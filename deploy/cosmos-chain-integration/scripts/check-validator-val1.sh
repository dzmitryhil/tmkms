#!/bin/bash


cd /root/home
# Initial dir
CURRENT_WORKING_DIR=$(pwd)
# Name of the network to bootstrap
CHAINID="testchain"
# Name of the gravity artifact
GRAVITY=gravity
# The name of the gravity node
GRAVITY_NODE_NAME="gravity-val1"
# Home folder for gravity config
GRAVITY_HOME="$CURRENT_WORKING_DIR/$CHAINID/$GRAVITY_NODE_NAME"
# Home flag for home folder
GRAVITY_HOME_FLAG="--home $GRAVITY_HOME"
# chain id cli flag
GRAVITY_CHAINID_FLAG="--chain-id $CHAINID"
# Keyring flag
GRAVITY_KEYRING_FLAG="--keyring-backend test"
# The name of the gravity validator
GRAVITY_VALIDATOR_NAME=val1
# The name of the gravity orchestrator
TEST_ACCOUNT_NAME=account1

# check that current validator is alive

# query all validators
$GRAVITY $GRAVITY_HOME_FLAG query tendermint-validator-set

# get node consensus address (validator pub key)
VALIDATOR_PUBKEY=$($GRAVITY $GRAVITY_HOME_FLAG tendermint show-validator)
echo "VALIDATOR_PUBKEY:$VALIDATOR_PUBKEY"

# the output should be without errors
$GRAVITY $GRAVITY_HOME_FLAG query slashing signing-info $VALIDATOR_PUBKEY $GRAVITY_CHAINID_FLAG

# ------ execute transaction -----

# create a new account
$GRAVITY $GRAVITY_HOME_FLAG keys add $TEST_ACCOUNT_NAME $GRAVITY_KEYRING_FLAG

# get addresses
VALIDATOR_ADDRESS=$($GRAVITY $GRAVITY_HOME_FLAG keys show -a $GRAVITY_VALIDATOR_NAME $GRAVITY_KEYRING_FLAG)
TEST_ACCOUNT_ADDRESS=$($GRAVITY $GRAVITY_HOME_FLAG keys show -a $TEST_ACCOUNT_NAME $GRAVITY_KEYRING_FLAG)

# get balances one more time
$GRAVITY $GRAVITY_HOME_FLAG query bank balances $VALIDATOR_ADDRESS
$GRAVITY $GRAVITY_HOME_FLAG query bank balances $TEST_ACCOUNT_ADDRESS

# send 1 samoleans to test account
$GRAVITY $GRAVITY_HOME_FLAG tx bank send $VALIDATOR_ADDRESS $TEST_ACCOUNT_ADDRESS 1samoleans $GRAVITY_CHAINID_FLAG $GRAVITY_KEYRING_FLAG -y

# get balances one more time
$GRAVITY $GRAVITY_HOME_FLAG query bank balances $VALIDATOR_ADDRESS
$GRAVITY $GRAVITY_HOME_FLAG query bank balances $TEST_ACCOUNT_ADDRESS