# Dev-Cluster GitOps Provisioning

Provisioning, configuration and manifests for my Kubernetes dev cluster on Hetzner Cloud, set up for GitOps with Flux CD.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed
- [SOPS](https://github.com/mozilla/sops) installed
- [Age](https://github.com/FiloSottile/age) installed (for encryption)
- A Hetzner Cloud account and API token
- A GitHub account and personal access token (for Flux)

## Setup Steps

1. **Generate an Age key:**
   ```
   age-keygen -o key.txt
   ```

2. **Create a `.sops.yaml` file in your project root:**
   ```yaml
   creation_rules:
     - path_regex: secrets\.enc\.yaml$
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
   ```

4. **Encrypt the secrets file:**
   ```
   sops -e secrets.yaml > secrets.enc.yaml
   ```

5. **Create a `terraform.tfvars` file for your Hetzner Cloud token:**
   ```hcl
   hcloud_token = "your-hetzner-cloud-token"
   ```

6. **Initialize Terraform:**
   ```
   terraform init
   ```

7. **Plan your Terraform deployment:**
   ```
   terraform plan
   ```

8. **Apply your Terraform configuration:**
   ```
   terraform apply
   ```

## File Structure

- `main.tf`: Main Terraform configuration file
- `variables.tf`: Terraform variables definition
- `cloud-init.yaml`: Cloud-init configuration template
- `secrets.enc.yaml`: Encrypted secrets file (do not commit to version control)
- `terraform.tfvars`: Terraform variables values (do not commit to version control)
- `.sops.yaml`: SOPS configuration file

## Usage

After successful provisioning, you can access your new server using SSH:

```
ssh <your-username>@<server-ip>
```

The server IP will be output by Terraform after successful application.

## Customization

- Modify `cloud-init.yaml` to change the initial server setup.
- Adjust `main.tf` to change Hetzner Cloud resources or add additional configurations.

## Security Notes

- Never commit `secrets.yaml`, `secrets.enc.yaml`, or `terraform.tfvars` to version control.
- Keep your `key.txt` file secure and backed up. Losing this file means losing access to your encrypted secrets.

## Troubleshooting

If you encounter issues:
1. Check Terraform output for errors.
2. Review cloud-init logs on the server: `/var/log/cloud-init-output.log`
3. Ensure all required variables are correctly set in your encrypted secrets file.

For further assistance, please open an issue in the project repository.