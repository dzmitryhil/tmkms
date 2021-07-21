#!/bin/bash
set -eu

cd /root/home
# Initial dir
CURRENT_WORKING_DIR=$(pwd)
# Name of the network to bootstrap
CHAINID="testchain"
# Name of the gravity artifact
GRAVITY=gravity
# The name of the gravity node
GRAVITY_NODE_NAME="gravity-val1"
# The address to run gravity node
GRAVITY_HOST="0.0.0.0"
# Home folder for gravity config
GRAVITY_HOME="$CURRENT_WORKING_DIR/$CHAINID/$GRAVITY_NODE_NAME"
# Home flag for home folder
GRAVITY_HOME_FLAG="--home $GRAVITY_HOME"
# Config directories for gravity node
GRAVITY_HOME_CONFIG="$GRAVITY_HOME/config"
# Config file for gravity node
GRAVITY_NODE_CONFIG="$GRAVITY_HOME_CONFIG/config.toml"
# App config file for gravity node
GRAVITY_APP_CONFIG="$GRAVITY_HOME_CONFIG/app.toml"
# Keyring flag
GRAVITY_KEYRING_FLAG="--keyring-backend test"
# Chain ID flag
GRAVITY_CHAINID_FLAG="--chain-id $CHAINID"
# The name of the gravity validator
GRAVITY_VALIDATOR_NAME=val1


GRAVITY_ROOT_ID=2554b98417e308c55d3d42fa36e85e377355f4d0
GRAVITY_ROOT_HOST=gravity-root
GRAVITY_ROOT_PORT=26656


# Gravity chain demons
STAKE_DENOM="stake"
NORMAL_DENOM="samoleans"

TMKMS_BIN="tmkms"
TMKMS_HOME="/root/home/tmkms"
TMKMS_CONFIG="$TMKMS_HOME/tmkms.toml"

HARNESS_BIN="tm-signer-harness"

# ------------------ Init gravity ------------------

echo "Cleaning gravity"
# clean prev gravity home

cp $CURRENT_WORKING_DIR/$CHAINID/gravity/config/genesis.json /root/home/genesis.json
rm -rf $CURRENT_WORKING_DIR/$CHAINID/gravity

echo "Creating $GRAVITY_NODE_NAME validator with chain-id=$CHAINID..."
echo "Initializing genesis files"

# Initialize the home directory and add some keys
echo "Init test chain"
$GRAVITY $GRAVITY_HOME_FLAG $GRAVITY_CHAINID_FLAG init $GRAVITY_NODE_NAME

# copy genesis
cp -rf /root/home/genesis.json $GRAVITY_HOME/config/genesis.json

cat $GRAVITY_HOME/config/genesis.json

echo "Exposing ports and APIs of the $GRAVITY_NODE_NAME"
# Switch sed command in the case of linux
fsed() {
  if [ `uname` = 'Linux' ]; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Change ports
fsed "s#\"tcp://127.0.0.1:26656\"#\"tcp://$GRAVITY_HOST:26656\"#g" $GRAVITY_NODE_CONFIG
fsed "s#\"tcp://127.0.0.1:26657\"#\"tcp://$GRAVITY_HOST:26657\"#g" $GRAVITY_NODE_CONFIG
fsed 's#addr_book_strict = true#addr_book_strict = false#g' $GRAVITY_NODE_CONFIG
fsed 's#external_address = ""#external_address = "tcp://'$GRAVITY_HOST:26656'"#g' $GRAVITY_NODE_CONFIG
# set up validator working with remove signer (tmkms)
# fsed 's#priv_validator_laddr = ""#priv_validator_laddr = "tcp://'$GRAVITY_HOST:26658'"#g' $GRAVITY_NODE_CONFIG

# update seed of parent chain
fsed 's#seeds = ""#seeds = "'$GRAVITY_ROOT_ID@$GRAVITY_ROOT_HOST:$GRAVITY_ROOT_PORT'"#g' $GRAVITY_NODE_CONFIG

fsed 's#enable = false#enable = true#g' $GRAVITY_APP_CONFIG
fsed 's#swagger = false#swagger = true#g' $GRAVITY_APP_CONFIG

cat $GRAVITY_NODE_CONFIG

# run the node

# ------------------ Run the node to create the validator ------------------

while ! timeout 1 bash -c "</dev/tcp/$GRAVITY_ROOT_HOST/$GRAVITY_ROOT_PORT"; do
  sleep 1
done

$GRAVITY $GRAVITY_HOME_FLAG start &

# create a new account
$GRAVITY $GRAVITY_HOME_FLAG keys add $GRAVITY_VALIDATOR_NAME $GRAVITY_KEYRING_FLAG

# list keys
$GRAVITY $GRAVITY_HOME_FLAG keys list $GRAVITY_KEYRING_FLAG

# get addresses
VALIDATOR_ADDRESS=$($GRAVITY $GRAVITY_HOME_FLAG keys show -a $GRAVITY_VALIDATOR_NAME $GRAVITY_KEYRING_FLAG)
$GRAVITY $GRAVITY_HOME_FLAG query bank balances $VALIDATOR_ADDRESS

# recover key and send stake to val1
ORCH_NAME=orch
ORCH_MEMO="warrior away frost estate roof express afford since sock hundred dinner laptop slice desert gas tackle chest during injury rebel morning venture layer plunge"
$GRAVITY $GRAVITY_HOME_FLAG keys add $ORCH_NAME --recover $GRAVITY_KEYRING_FLAG <<< $ORCH_MEMO
ORCH_ADDRESS=$($GRAVITY $GRAVITY_HOME_FLAG keys show -a $ORCH_NAME $GRAVITY_KEYRING_FLAG)

sleep 10

$GRAVITY $GRAVITY_HOME_FLAG tx bank send $ORCH_ADDRESS $VALIDATOR_ADDRESS 100000000stake $GRAVITY_CHAINID_FLAG $GRAVITY_KEYRING_FLAG -y
$GRAVITY $GRAVITY_HOME_FLAG tx bank send $ORCH_ADDRESS $VALIDATOR_ADDRESS 10000000samoleans $GRAVITY_CHAINID_FLAG $GRAVITY_KEYRING_FLAG -y

sleep 10

VALIDATOR_PUBKEY=$($GRAVITY $GRAVITY_HOME_FLAG tendermint show-validator)
echo "VALIDATOR_PUBKEY:$VALIDATOR_PUBKEY"

$GRAVITY $GRAVITY_HOME_FLAG tx staking create-validator \
 --amount=100000000stake \
 --pubkey=$VALIDATOR_PUBKEY \
 --moniker=$GRAVITY_NODE_NAME \
 --chain-id=$CHAINID \
 --commission-rate="0.10" \
 --commission-max-rate="0.20" \
 --commission-max-change-rate="0.01" \
 --min-self-delegation="1" \
 --gas="auto" \
 --gas-adjustment=1.5 \
 --gas-prices="0samoleans" \
 --from=$GRAVITY_VALIDATOR_NAME \
 $GRAVITY_KEYRING_FLAG -y

echo "new validator is created"
echo "stopping to restart in remove validator mode"
pkill gravity

sleep 10

# ------------------ Init tmkms ------------------

# Generate consensus key
#${TMKMS_BIN} softsign keygen -t consensus "$TMKMS_HOME/signing.key"
# Generate connection key
#${TMKMS_BIN} softsign keygen "$TMKMS_HOME/secret.key"

${TMKMS_BIN} init $TMKMS_HOME
cp -rf "/root/home/assets/tmkms.toml" $TMKMS_CONFIG

# Import signing key
${TMKMS_BIN} softsign import "$GRAVITY_HOME/config/priv_validator_key.json" "$TMKMS_HOME/secrets/consensus.key"

echo -e "private key: \n"
cat $GRAVITY_HOME/config/priv_validator_key.json

echo -e "consensus key from private key: \n"
cat $TMKMS_HOME/secrets/consensus.key

# run rm kms in background (it should be run before the gravity)
echo -e "\n starting tmkms"
${TMKMS_BIN} start -c ${TMKMS_CONFIG} -v &

# ------------------ Start gravity ------------------

# Await gravity-root to start

# set up validator working with remove signer (tmkms)
fsed 's#priv_validator_laddr = ""#priv_validator_laddr = "tcp://'$GRAVITY_HOST:26658'"#g' $GRAVITY_NODE_CONFIG

#echo "starting gravity with tmkms validator"
$GRAVITY $GRAVITY_HOME_FLAG start


# Run the test harness in the foreground
#${HARNESS_BIN} run \
#    -accept-retries 1000 \
#    -addr tcp://0.0.0.0:26658 \
#    -tmhome ${GRAVITY_HOME}
#HARNESS_EXIT_CODE=$?