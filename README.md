# OpenVPN Installation Script

This script automates the process of installing and configuring OpenVPN on a Ubuntu server.

## Usage

To use this script, run the following command:

```bash
curl -O https://raw.githubusercontent.com/robocoder-repo/openvpn-install-script/main/install_openvpn.sh && chmod +x install_openvpn.sh && sudo ./install_openvpn.sh
```

## Features

- Automatic installation of OpenVPN and required dependencies
- Configuration of server and client certificates
- Creation of client configuration file
- Automatic setup of Nginx for serving client configuration file

## Note

Please ensure you have root access to your server before running this script.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
