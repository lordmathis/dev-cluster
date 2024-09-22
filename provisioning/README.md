# Dev-Cluster GitOps Provisioning

Provisioning, configuration and manifests for my Kubernetes dev cluster on Hetzner Cloud, set up for GitOps with Flux CD.

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/)
- [SOPS](https://github.com/mozilla/sops)
- [Age](https://github.com/FiloSottile/age)
- A Hetzner Cloud account and API token
- Cloudflare DNS API token
- A GitHub account and personal access token (for Flux)
- S3 compatible storage credentials

## Setup Steps

1. **Generate an Age key:**
   ```
   age-keygen -o key.txt
   ```

2. **Edit `.sops.yaml` file in your project root:**
   ```yaml
   creation_rules:
     - unencrypted_regex: "^(apiVersion|metadata|kind|type)$"
       age: <your-age-public-key>
   ```
   Replace `<your-age-public-key>` with the public key from your `key.txt` file.

3. **Create a `secrets.yaml` file with your sensitive data:**

   ```yaml
   username: <your-username>
   user_hashed_password: <your-hashed-password>
   user_ssh_public_key: <your-ssh-public-key>
   github_username: <your-github-username>
   github_repo: <your-flux-repo-name>
   github_token: <your-github-token>
   ```

4. **Encrypt the secrets file:**
   ```
   sops -e secrets.yaml > secrets.enc.yaml
   ```

5. **Create a `terraform.tfvars` file for your Hetzner Cloud token:**
   ```hcl
   hcloud_token = "your-hetzner-cloud-token"

   ```

6. **Create `s3_env.yaml` file with your S3 compatible storage credentials**

   `AWS_ENDPOINT_URL_S3`
   `AWS_ACCESS_KEY_ID`
   `AWS_REGION`
   `AWS_SECRET_ACCESS_KEY`

7. **Encrypt the `s3_env.yaml` file:**
   ```
   sops -e s3_env.yaml > s3_env.enc.yaml
   ```

6. **Initialize OpenTofu:**

   ```bash
   sops exec-env s3_env.enc.yaml 'tofu init'
   ```

   ```bash
   tofu init
   tofu plan
   tofu apply
   ```
