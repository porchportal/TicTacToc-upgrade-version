# GitHub Actions Secrets Configuration

This document outlines the required secrets for the CI/CD workflows to function properly.

## Required Secrets

### `KUBE_CONFIG`
- **Description**: Base64-encoded Kubernetes configuration file
- **Required for**: Production deployments, rollbacks
- **How to generate**:
  ```bash
  # Get your kubeconfig file
  kubectl config view --raw
  
  # Encode it to base64
  kubectl config view --raw | base64 -w 0
  ```
- **Usage**: Used to authenticate with Kubernetes clusters for production deployments

### Optional Secrets

### `DOCKER_USERNAME` and `DOCKER_PASSWORD`
- **Description**: Docker Hub credentials (if using Docker Hub instead of GitHub Container Registry)
- **Required for**: Docker image pushing to Docker Hub
- **Usage**: Alternative to GitHub Container Registry

### `SLACK_WEBHOOK_URL`
- **Description**: Slack webhook URL for notifications
- **Required for**: Deployment notifications
- **Usage**: Send deployment status updates to Slack channels

### `EMAIL_SMTP_HOST`, `EMAIL_SMTP_PORT`, `EMAIL_USERNAME`, `EMAIL_PASSWORD`
- **Description**: SMTP configuration for email notifications
- **Required for**: Email deployment notifications
- **Usage**: Send deployment status updates via email

## Environment Protection Rules

### Production Environment
- **Required reviewers**: At least 1 approval
- **Deployment branches**: `main` branch only
- **Wait timer**: 0 minutes (immediate deployment)

### Staging Environment
- **Required reviewers**: None (automatic deployment)
- **Deployment branches**: `develop` branch
- **Wait timer**: 0 minutes (immediate deployment)

## Setting Up Secrets

1. **Go to your repository settings**
   - Navigate to Settings → Secrets and variables → Actions

2. **Add each secret**
   - Click "New repository secret"
   - Enter the secret name and value
   - Click "Add secret"

3. **Verify secrets are set**
   - Secrets are masked in logs
   - Use `${{ secrets.SECRET_NAME }}` in workflows

## Security Best Practices

- **Never commit secrets to code**
- **Use environment-specific secrets**
- **Rotate secrets regularly**
- **Limit secret access to necessary workflows**
- **Use least privilege principle**

## Troubleshooting

### Common Issues

1. **"Secret not found" error**
   - Verify secret name matches exactly
   - Check if secret is set in repository settings

2. **"Permission denied" error**
   - Verify kubeconfig has correct permissions
   - Check if service account has required roles

3. **"Authentication failed" error**
   - Verify credentials are correct
   - Check if tokens haven't expired

### Debug Mode

To debug secret issues, add this step to your workflow:
```yaml
- name: Debug secrets (masked)
  run: |
    echo "Secret exists: ${{ secrets.KUBE_CONFIG != '' }}"
    echo "Secret length: ${{ secrets.KUBE_CONFIG != '' && length(secrets.KUBE_CONFIG) }}"
```

## Example Configuration

```yaml
# Example workflow using secrets
- name: Deploy to Production
  env:
    KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }}
    SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    echo "$KUBE_CONFIG" | base64 -d > kubeconfig.yaml
    export KUBECONFIG=kubeconfig.yaml
    kubectl apply -f k8s/
```
