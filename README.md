# Dev-Cluster

Provisioning, configuration and manifests for my Kubernetes dev cluster on Hetzner Cloud, set up for GitOps with Flux CD.

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/)
- [SOPS](https://github.com/mozilla/sops)
- [Age](https://github.com/FiloSottile/age)
- A Hetzner Cloud account and API token
- Cloudflare DNS API token
- A GitHub account and personal access token (for Flux)
- S3 compatible storage credentials

## Deployment

1. **Generate an Age key:**

   ```
   age-keygen -o key.txt
   ```

2. **Edit `.sops.yaml` file in project root:**

   ```yaml
   creation_rules:
     - unencrypted_regex: "^(apiVersion|metadata|kind|type)$"
       age: <your-age-public-key>
   ```

   Replace `<your-age-public-key>` with the public key from your `key.txt` file.

3. **Create a `secrets.yaml` file with your sensitive data:**

   ```bash
   cd provisioning
   ```

   ```yaml
   username: <your-username>
   user_hashed_password: <your-hashed-password>
   user_ssh_public_keys: |
      <your-ssh-public-key>
   domain_name: <your-domain-name>
   ```

4. **Encrypt the secrets file:**

   ```
   sops -e secrets.yaml > secrets.enc.yaml
   ```

5. **Create a `terraform.tfvars` file for your Hetzner Cloud token and Cloudflare Token:**

   ```hcl
   hcloud_token = "your-hetzner-cloud-token"
   cloudflare_api_token = "your-cloudflare-token
   ```

6. **Create `s3_env.yaml` file with your S3 compatible storage credentials**

   `AWS_ENDPOINT_URL_S3`
   `AWS_ACCESS_KEY_ID`
   `AWS_REGION`
   `AWS_SECRET_ACCESS_KEY`

7. **Encrypt the `s3_env.yaml` file:**

   ```bash
   sops -e s3_env.yaml > s3_env.enc.yaml
   ```

8. **Run OpenTofu:**

   ```bash
   sops exec-env s3_env.enc.yaml 'tofu init'
   sops exec-env s3_env.enc.yaml 'tofu apply'
   ```

## Post Deployment

1. **Connect to the server**

   Replace username with your username and public ip with the output value of `tofu apply`

   ```bash
   ssh ${username}@${public_ip}
   ```

2. **Create sops secret**

   Use the key generated in step 1. of the deployment

   ```bash
   kubectl create ns flux-system
   echo 'AGE-SECRET-KEY-...' | kubectl create secret generic sops-age \
   --namespace=flux-system \
   --from-file=age.agekey=/dev/stdin
   ```

3. **Create GitHub access token**

   [https://fluxcd.io/flux/installation/bootstrap/github/](https://fluxcd.io/flux/installation/bootstrap/github/)

3. **Bootstrap flux**

   ```bash
   export GITHUB_TOKEN=your_github_token
   export GITHUB_USERNAME=your_github_username
   export GITHUB_REPO=your_github_repo
   flux bootstrap github \
      --owner=$GITHUB_USERNAME \
      --repository=$GITHUB_REPO \
      --components-extra=image-reflector-controller,image-automation-controller \
      --path=clusters/prod --personal
   ```
