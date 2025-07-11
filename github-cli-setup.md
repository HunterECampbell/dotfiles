# GitHub CLI (`gh`) Setup Guide

This guide details how to install and authenticate the GitHub CLI (`gh`) on your Arch Linux system, which is essential for seamless Git operations (like `git push` and `git pull`) without repeatedly entering your password.

## 1. Install GitHub CLI

The `gh` package is available in the official Arch Linux repositories. (This will be auto installed when running the `run_all_scripts.sh` script.)

```
sudo pacman -S github-cli
```

## 2. Authenticate GitHub CLI

Once `gh` is installed, use its authentication command. This will guide you through the process of linking your terminal to your GitHub account.

```
gh auth login
```

Follow the interactive prompts:

- **"What account do you want to log into?":**

    - Choose `GitHub.com` (unless you're using GitHub Enterprise).

- **"What is your preferred protocol for Git operations?":**

    - **SSH (Recommended):** If you have SSH keys set up for GitHub (or plan to), choose SSH. This is generally more secure and convenient as it doesn't require password prompts for Git operations after the initial setup. <ins>**To setup SSH, reference the [Troubleshooting SSH Authentication](#4-troubleshooting-ssh-authentication-permission-denied-publickey) section.**</ins>

    - **HTTPS:** If you don't use SSH keys, choose HTTPS. gh will configure a credential helper, so you won't need to type your password, but it relies on a Personal Access Token (PAT) managed by gh.

- **"Authenticate Git with your GitHub credentials?":**

    - Choose `Yes`. This allows `gh` to configure Git to use its authentication helper, so you don't have to type credentials repeatedly for `git push`/`git pull`.

- **"How would you like to authenticate GitHub CLI?":**

    - **Login with a web browser (Recommended):** This is the easiest and most secure method. `gh` will open a browser window, and you'll log in there and authorize the CLI.

        - `gh` will display a unique **one-time code** (e.g., `XXXX-XXXX`).

        - It will then prompt you to press `Enter` to open your browser.

        - Your browser will open to `github.com/login/device`.

        - **Paste the one-time code** into the field on the GitHub page and click "Continue."

        - On the next screen, click "Authorize GitHub CLI."

        - Once authorized in the browser, return to your terminal. `gh` will detect the successful authentication.

You should see a success message like: `✓ Authenticated via web browser` and `✓ Configured git to use ssh` (or `https` depending on your choice).

## 3. Verify Authentication

You can quickly check if you're authenticated and which account is active:

```
gh auth status
```

This should show your GitHub account and the authentication method used.

## 4. Troubleshooting SSH Authentication (`Permission denied (publickey)`)

If you chose SSH and later encounter `Permission denied (publickey)` when trying to `git push`, it means your SSH key isn't being used correctly by GitHub.

### 4.1. Check Your Remote URL

Ensure your Git remote URL is set to use SSH:

```
cd ~/dotfiles/ # Or your repository directory
git remote -v
```

It should show `git@github.com:your-username/your-repo.git` (fetch and push).
If it shows `https://`, you need to change it:

```
git remote remove origin
git remote add origin git@github.com:your-username/your-repo.git
```

### 4.2. Check for Existing SSH Keys

SSH keys are typically in `~/.ssh/`.

```
ls -al ~/.ssh/
```

Look for files like `id_rsa`, `id_ed25519`, etc., and their corresponding `.pub` (public key) files. If you don't see any `id_*` files, you need to generate a key pair.

### 4.3. Generate a New SSH Key Pair (If needed)

If you don't have a key, generate a new ED25519 key (modern and recommended):

```
ssh-keygen -t ed25519 -C "your_email@example.com"
```

- Press `Enter` for the default file location (`~/.ssh/id_ed25519`).

- Enter a strong passphrase when prompted. This encrypts your private key.

### 4.4. Start `ssh-agent` and Add Your Key

The `ssh-agent` holds your private keys in memory.

**1. Start ssh-agent:**

```
eval "$(ssh-agent -s)"
```

**2. Add your private key:**

```
ssh-add ~/.ssh/id_ed25519 # Use your key filename if different
```

Enter your passphrase if you set one.

**3. Verify key is loaded:**

```
ssh-add -l
```

### 4.5. Add Your Public SSH Key to GitHub

GitHub needs your public key to authorize your pushes.

**1. Copy your public key:**

```
cat ~/.ssh/id_ed25519.pub | wl-copy # For Wayland/Hyprland with wl-clipboard
# Or manually copy the output of `cat ~/.ssh/id_ed25519.pub`
```

**2. Go to GitHub.com:**

- Log in to your account.

- Go to **Settings** (via your profile picture).

- In the left sidebar, click **SSH and GPG keys**.

- Click **"New SSH key."**

- **Title:** Give it a descriptive name.

- **Key:** Paste your copied public key.

- Click **"Add SSH key."**

### 4.6. Test SSH Connection to GitHub

```
ssh -T git@github.com
```

Accept the host authenticity warning if prompted. A successful message will confirm authentication.

After following these steps, your `git push` and `git pull` commands should work seamlessly using SSH.