#!/bin/bash -x

# This is all based off of the tutorial here:
# https://cloud.google.com/community/tutorials/kube-mqtt
# You are expected to have the following done already:
# 1. Kube cluster already created.
# 2. Applicable API's enabled
# 3. You are in the chosed gcloud project

export PROJECT=$(gcloud config list project --format "value(core.project)")
export REGION=us-central1
export REGISTRY=gadgets
export DEVICE=bridge

# Gen keys for SSL
./gen_keys.sh

# Delete existing deployment, we are starting from scratch
kubectl delete --wait -n default deployment iot-core-bridge

# Create IoT Core resources if needed
gcloud pubsub topics delete device-events
gcloud pubsub subscriptions delete debug
gcloud iot devices delete $DEVICE --region $REGION --registry $REGISTRY --quiet 
gcloud iot registries delete $REGISTRY --region=$REGION --quiet

# Build the bridge manager container# 
pushd refresher-container
gcloud builds submit --tag gcr.io/$PROJECT/refresher .
popd

# Create the device keys
pushd bridge
rm -rf *.pem
openssl ecparam -genkey -name prime256v1 -noout -out ec_private.pem
openssl ec -in ec_private.pem -pubout -out ec_public.pem
popd

sleep 1

gcloud pubsub topics create device-events
sleep 1
gcloud pubsub subscriptions create debug --topic device-events
sleep 1

gcloud iot registries create $REGISTRY \
--region=$REGION \
--event-notification-config topic=device-events

sleep 1
gcloud iot devices create $DEVICE \
--region $REGION \
--registry $REGISTRY \
--public-key path=bridge/ec_public.pem,type=es256-pem

# Get the specific address for the bridge manager container# 
IMAGE=$(gcloud container images describe gcr.io/$PROJECT/refresher --format="value(image_summary.fully_qualified_digest)")

# setup all the variables fro the bridge
sed -i "s/PROJECT_ID:.*/PROJECT_ID: $PROJECT/"            bridge/device-config.yaml
sed -i "s/REGISTRY_ID:.*/REGISTRY_ID: $REGISTRY/"         bridge/device-config.yaml
sed -i "s/BRIDGE_DEVICE_ID:.*/BRIDGE_DEVICE_ID: $DEVICE/" bridge/device-config.yaml
sed -i "s/CLOUD_REGION:.*/CLOUD_REGION: $REGION/"         bridge/device-config.yaml
sed -i "s|image:.*|image: $IMAGE|"                        bridge/project-image.yaml

# Deploy the bridge
kubectl apply -k bridge/

# Wait for bridge
sleep 1
kubectl wait --for=condition=Ready pod -l "app=iot-core-bridge"


