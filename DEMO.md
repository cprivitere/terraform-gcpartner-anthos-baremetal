# Demo Steps

## Install git if you don't have it already

https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

    ```sh
    git clone https://github.com/cprivitere/terraform-gcpartner-anthos-baremetal
    cd terraform-gcpartner-anthos-baremetal
    terraform init -upgrade
    ```

## Edit the terraform.tfvars file to have your API key and Project ID

    ```sh
    terraform plan
    terraform apply
    terraform output kubeconfig | grep -v EOT > ~/anthos.kubeconfig
    cd ~
    export KUBECONFIG=./anthos.kubeconfig
    ```

## Install kubectl if you don't have it already

https://kubernetes.io/docs/tasks/tools/

## Validate the cluster is working

    ```sh
    kubectl get nodes
    kubectl get pods
    kubectl patch storageclass local-shared -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class": "true"}}}'
    ```

## Install Helm if you don't have it already

https://helm.sh/docs/intro/install/

    ```sh
    git clone https://github.com/open-webui/open-webui/
    cd open-webui
    helm package ./kubernetes/helm/
    helm install ollama-webui ./open-webui-1.0.0.tgz --set webui.ingress.enabled=true
    kubectl get ingress open-webui
    ```

## Open a web browser and go to http://<the address in the output above>

## Go to settings->Connections edit the ollama url and remove the /api at the end

## click the little reload button next to the ollama url

## Wait for it to pop up that it connected to ollama

## Now go to the Settings->Models

## Type `gemma:2b` into the "Pull a model from Ollama.com" box and click the download button

## Wait for it to say the model has been successfully downloaded. This will take a while, even after it says 100%.

## Close Settings

## Choose gemma:2b from the models drop down

## Type a prompt and see if it works
