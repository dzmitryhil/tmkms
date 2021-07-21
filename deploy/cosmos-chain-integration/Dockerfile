FROM onomy/tmkms-builder:local as builder


ARG TMKMS_DIR=/home/developer/tmkms
RUN git clone https://github.com/iqlusioninc/tmkms.git $TMKMS_DIR
WORKDIR $TMKMS_DIR

RUN cargo build --release --features=softsign

FROM onomy/gravity-bridge-single-node-runner-rinkeby:local

RUN apt-get update -y -q && apt-get upgrade -yq
# common (DEBIAN_FRONTEND is a fix for tzdata)
RUN DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -yq software-properties-common \
                                                curl \
                                                build-essential \
                                                ca-certificates \
                                                tar \
                                                git

# install golang
RUN curl https://dl.google.com/go/go1.16.4.linux-amd64.tar.gz --output go.tar.gz
RUN tar -C /usr/local -xzf go.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"
ENV GOPATH=/go
ENV PATH=$PATH:$GOPATH/bin

# copy tmkms
COPY --from=builder /home/developer/tmkms/target/release/tmkms /usr/bin/tmkms

# build tm-signer-harness
ARG TENDERMIN_DIR=/go/src/github.com/tendermint/tendermint/
RUN git clone https://github.com/tendermint/tendermint.git $TENDERMIN_DIR
WORKDIR $TENDERMIN_DIR/tools/tm-signer-harness
RUN make build
RUN cp $TENDERMIN_DIR/build/tm-signer-harness /usr/bin/tm-signer-harness

COPY deploy/cosmos-chain-integration/assets /root/home/assets
COPY deploy/cosmos-chain-integration/scripts /root/home/scripts

CMD /bin/bash /root/home/scripts/run.sh

