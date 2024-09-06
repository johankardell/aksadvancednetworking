# https://learn.microsoft.com/en-us/azure/aks/advanced-network-observability-cli?tabs=non-cilium

# Install the aks-preview extension
az extension add --name aks-preview

# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview

az account set -s one

az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingPreview"
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingPreview"

# Set environment variables for the resource group name and location. Make sure to replace the placeholders with your own values.
export RESOURCE_GROUP="rg-aks-advanced-networking"
export LOCATION="swedencentral"
export CLUSTER_NAME="aks-advanced-networking"
export AZURE_MONITOR_NAME="log-aks-advanced-networking"
export GRAFANA_NAME="grafana-aks"

# Create a resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

az aks create --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --generate-ssh-keys --network-plugin azure --network-plugin-mode overlay --pod-cidr 192.168.0.0/16 --enable-advanced-network-observability

az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --overwrite-existing

az resource create \
    --resource-group $RESOURCE_GROUP \
    --namespace microsoft.monitor \
    --resource-type accounts \
    --name $AZURE_MONITOR_NAME \
    --location $LOCATION \
    --properties '{}'

az grafana create --name $GRAFANA_NAME --resource-group $RESOURCE_GROUP

grafanaId=$(az grafana show --name $GRAFANA_NAME --resource-group $RESOURCE_GROUP --query id --output tsv)
azuremonitorId=$(az resource show --resource-group $RESOURCE_GROUP --name $AZURE_MONITOR_NAME --resource-type "Microsoft.Monitor/accounts" --query id --output tsv)

az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --enable-azure-monitor-metrics --azure-monitor-workspace-resource-id $azuremonitorId --grafana-resource-id $grafanaId

# Set environment variables
export HUBBLE_VERSION=v0.11.0
export HUBBLE_ARCH=amd64

#Install Hubble CLI
curl -L --fail --remote-name-all "https://github.com/cilium/hubble/releases/download/v1.16.0/hubble-linux-amd64.tar.gz"
sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
rm hubble-linux-amd64.tar.gz

kubectl get pods -o wide -n kube-system -l k8s-app=hubble-relay

./hubblemtls.sh

kubectl get secrets -n kube-system | grep hubble-

# hubble relay service

kubectl apply -f hubble-ui.yaml

kubectl -n kube-system port-forward svc/hubble-ui 12000:80


# az group delete -n $RESOURCE_GROUP