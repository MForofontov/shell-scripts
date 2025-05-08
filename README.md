# Shell Scripts Repository

A collection of modular and reusable shell scripts designed to simplify various tasks, including system monitoring, file management, network utilities, and more.

---

## Table of Contents

- [Overview](#overview)
- [Usage](#usage)
- [Scripts](#scripts)
  - [System Scripts](#system-scripts)
  - [File Management Scripts](#file-management-scripts)
  - [Network Utilities](#network-utilities)
  - [Development Tools](#development-tools)
  - [Security Utilities](#security-utilities)
  - [General Utilities](#general-utilities)
- [Setup](#setup)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This repository contains a variety of shell scripts organized into categories. Each script is self-contained and includes detailed usage instructions. The scripts are designed to automate repetitive tasks, enhance productivity, and streamline workflows.

---

## Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/shell-scripts.git
   cd shell-scripts
   ```

2. Make the scripts executable:
   ```bash
   chmod +x */*.sh
   ```

3. Run a script:
   ```bash
   ./path/to/script.sh [arguments]
   ```

4. For help with a specific script, use the `--help` flag:
   ```bash
   ./path/to/script.sh --help
   ```

---

## Scripts

### System Scripts
Scripts for monitoring and managing system resources.

- **[cpu-monitor.sh](system-scripts/cpu-monitor.sh)**: Monitor CPU usage and send alerts if thresholds are exceeded.
- **[disk-usage.sh](system-scripts/disk-usage.sh)**: Check disk usage and send alerts if thresholds are exceeded.
- **[system-report.sh](system-scripts/system-report.sh)**: Generate a detailed system report.
- **[check-services.sh](system-scripts/check-services.sh)**: Verify if specific services are running.

### File Management Scripts
Scripts for managing files and directories.

- **[create-zip.sh](file-scripts/create-zip.sh)**: Create a zip archive of a file or directory.
- **[extract-tar.sh](file-scripts/extract-tar.sh)**: Extract tar archives.
- **[clean-old-files.sh](file-scripts/clean-old-files.sh)**: Delete files older than a specified number of days.
- **[add-prefix-to-files.sh](file-scripts/add-prefix-to-files.sh)**: Add a prefix to all files in a directory.

### Network Utilities
Scripts for network diagnostics and monitoring.

- **[network-speed-test.sh](network-and-connectivity/network-speed-test.sh)**: Test network speed using `speedtest-cli`.
- **[active-host-scanner.sh](network-and-connectivity/active-host-scanner.sh)**: Scan a network for active hosts.
- **[http-status-code-checker.sh](network-and-connectivity/http-status-code-checker.sh)**: Check HTTP status codes for a list of URLs.

### Development Tools
Scripts for managing development workflows.

- **[git-add-commit-push.sh](development-tools/git-add-commit-push.sh)**: Automate Git add, commit, and push operations.
- **[generate-changelog.sh](development-tools/generate-changelog.sh)**: Generate a changelog from Git logs.
- **[npm-update-all.sh](development-tools/npm-update-all.sh)**: Update all globally installed npm packages.

### Security Utilities
Scripts for managing security and access.

- **[secure-file-permissions.sh](security-utilities/secure-file-permissions.sh)**: Set secure permissions for sensitive files.
- **[ssh-key-manager.sh](security-utilities/ssh-key-manager.sh)**: Generate and distribute SSH keys.
- **[malware-scanner.sh](security-utilities/malware-scanner.sh)**: Scan directories for suspicious files.

### General Utilities
General-purpose utility scripts.

- **[generate-ssh-key.sh](utils/generate-ssh-key.sh)**: Generate an SSH key pair.
- **[docker-cleanup.sh](utils/docker-utils/docker-cleanup.sh)**: Clean up Docker containers, images, and volumes.
- **[backup-postgresql.sh](utils/services-utils/backup-postgresql.sh)**: Backup a PostgreSQL database.

---

## Setup

1. Ensure you have the required dependencies installed (e.g., `bash`, `curl`, `rsync`, `docker`, etc.).
2. Clone the repository and navigate to the desired script's directory.
3. Follow the usage instructions provided in each script.

---

## Contributing

Contributions are welcome! If you have a script to add or improvements to suggest, please fork the repository, make your changes, and submit a pull request.

---

## License

This repository is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.