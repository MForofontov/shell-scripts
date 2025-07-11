# Shell Scripts

A curated collection of standalone shell scripts for system administration, development workflows, network diagnostics and more. Each script lives in its own file and can be executed directly or via the provided wrapper script.

## Getting Started

### Clone the repository
```bash
git clone https://github.com/your-username/shell-scripts.git
cd shell-scripts
```

### Make scripts executable
```bash
chmod +x shell-scripts.sh */*.sh */*/*.sh
```

### Running a script
List all available scripts:
```bash
./shell-scripts.sh
```
Run a script by name:
```bash
./shell-scripts.sh <script_name> [arguments]
```
You can also execute scripts directly by running `./path/to/script.sh`.

## Directory Overview

### system-scripts
Utilities for monitoring and managing your system (e.g. `cpu-monitor.sh`, `disk-usage.sh`, `system-report.sh`).

### file-scripts
Operations on files and directories such as archiving, cleanup and renaming (e.g. `create-zip.sh`, `clean-old-files.sh`).

### network-and-connectivity
Network tools including `network-speed-test.sh`, `port-scanner.sh` and `active-host-scanner.sh`.

### development-and-code-management
Helpers for development tasks. Examples include `git/git-add-commit-push.sh` and `dependencies-updater/dependency-updater-npm.sh`.

### security-and-access
Scripts focused on security like `ssh_key_manager.sh`, `firewall_configurator.sh` and `password_generator.sh`.

### k8s-scripts
Kubernetes administration utilities such as `list-clusters.sh`, `scale-cluster-local.sh` and node management scripts.

### utils
Miscellaneous helpers: Docker management (`docker-cleanup.sh`), npm utilities and PostgreSQL backup scripts.

## Contributing
Contributions are welcome. Add new scripts in the appropriate folder and include clear usage instructions in the script file.

## License
This project is licensed under the terms of the [GNU General Public License v3.0](LICENSE).
