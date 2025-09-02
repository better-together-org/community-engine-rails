# Raspberry Pi Setup

For app-specific external services and required environment variables, see:

- [External Services Configuration](./external-services-to-configure.md)

- Flash OS to SD card

- configure static IP for ethernet and wlan

- disable wifi

- disable bluetooth

- mute audio

- connect to gigabit ethernet

- update repositories `sudo apt-get update`

- upgrade software `sudo apt-get upgrade -y`

- install docker (debian) - https://docs.docker.com/engine/install/debian/

- docker Linux post-install (group modifications) - https://docs.docker.com/engine/install/linux-postinstall/

- Install cloudflared - https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel/#1-download-and-install-cloudflared

- Create and/or connect Cloudflare tunnel

- install nordvpn - https://nordvpn.com/download/linux/

  - to login from CLI, run `nordvpn login` in the terminal and copy the link it provides
  - open the link in the browser and log in with Nord account
  - after login, copy the URL of the 'continue' button
  - in the terminal, use `nordvpn login --callback "{your success URL}"` to login

- configure nordvpn

  - enable meshnet `nordvpn set meshnet on`
  - enable lan-discovery `nordvpn set lan-discovery on`
  - enable cybersec `nordvpn set cybersec on`

- configure pi hardening

  - https://sunknudsen.com/privacy-guides/how-to-configure-hardened-raspberry-pi

  - http://www.arch13.com/security-setup-hardening-of-raspberry-pi-os-buster/

  - outline:

    - ensure pi user not used

    - ensure sudo with password

      - `rm /etc/sudoers.d/010_*`

    - disable root user history

      - ```
        echo "HISTFILESIZE=0" >> ~/.bashrc
        history -c; history -w
        source ~/.bashrc
        ```

    - disable root login and password auth

      - ```
        sed -i -E 's/^(#)?PermitRootLogin (prohibit-password|yes)/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i -E 's/^(#)?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        systemctl restart ssh
        ```

        

    - ensure non-default hostname

    - install ufw firewall

      - `sudo apt-get install ufw`
      - `sudo ufw enable`
      - `sudo ufw allow http`
      - `sudo ufw allow https`
      - `sudo ufw limit ssh`

    - install fail2ban `sudo apt-get install fail2ban
    
    - install unattended upgrades
    
      - `sudo apt-get install unattended-upgrades`
    
      - enable unattended upgrades `sudo dpkg-reconfigure --priority=low unattended-upgrades`
        - You’ll be presented with a confirmation screen that you want to enable automatic software updates. Select `Yes` to proceed.

- install borgbackup `sudo apt install borgbackup`

- configure borgbackup - https://borgbackup.readthedocs.io/en/stable/quickstart.html

  - create initial repo `borg init --encryption=repokey /path/to/storage/{hostname}
  - run initial full backup `sudo borg create --verbose --stats --compression lz4 /storage-hdd/backups/{hostname}::full_{now} /etc /home /root /var /usr/local/bin /usr/local/sbin /usr/local/etc /usr/local/src /opt /srv`
  - configure borg automated backup

- install and configure cosmos-server - https://cosmos-cloud.io/doc/1%20index/

  - `docker run -d --network host  --privileged --name cosmos-server -h cosmos-server --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v /:/mnt/host -v /{external storage path}/cosmos:/config azukaar/cosmos-server:latest`
  - Don't use https for cosmos. This is handled via the Cloudflare tunnel

- configure automount external storage (if present)

  - https://unix.stackexchange.com/a/654953

- install cosmos apps

  - Nextcloud
    - Set up cron
    - Set up plugins
      - Mount ffmpeg binaries
        - `/storage-hdd/utilities/ffmpeg-6.1/ffmpeg:/usr/bin/ffmpeg`
        - `/storage-hdd/utilities/ffmpeg-6.1/ffprobe:/usr/bin/ffprobe`
  - Ghost

- Install Discourse

  - Install launcher
  - configure & deploy data container
  - configure & deploy web container
    - Expose ports
  - Add cosmos URL to route traffic to web container

- Install Collective Commerce (Solidus)





# Dokku

For Dokku on raspi, use arm64 version of docker images when needed:

Postgres

- `dokku postgres:create community-engine-db --image imresamu/postgis --image-version latest`
