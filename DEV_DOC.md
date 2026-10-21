# Developer documentation

## Persistent storage

The stack uses two Docker named volumes:

- `mariadb_data`: MariaDB database files.
- `wordpress_data`: WordPress website files.

Neither volume uses bind-mount driver options.

Docker's data-root must be `/home/<login>/data` on the VM.
Replace `<login>` with your 42 login.

## Docker storage setup on the VM

These instructions assume a fresh Debian VM with Docker Engine,
Docker Compose, and systemd. Configure storage before creating
the project's containers and volumes.

If Docker already contains data that must be preserved, plan its
migration before changing data-root. Changing this setting does
not move existing data.

1. Create `/home/<login>/data` and `/etc/docker`.
2. Open `/etc/docker/daemon.json` with administrator privileges.
3. Add the configuration from `srcs/config/daemon.json.example`,
   replacing `your_login` with your actual login.
   Preserve other settings if the configuration file already exists.
4. Validate the configuration:

   ```sh
   sudo dockerd --validate --config-file=/etc/docker/daemon.json
   ```

5. Restart Docker:

   ```sh
   sudo systemctl restart docker
   ```

6. Check the active storage directory:

   ```sh
   sudo docker info --format '{{.DockerRootDir}}'
   ```

   The output must be `/home/<login>/data`.

## Volume verification after starting the stack

Run:

```sh
sudo docker volume inspect inception_mariadb_data inception_wordpress_data \
  --format '{{.Name}}: {{.Mountpoint}}'
```

Both paths must start with `/home/<login>/data/`.

The expected paths are:

- `/home/<login>/data/volumes/inception_mariadb_data/_data`
- `/home/<login>/data/volumes/inception_wordpress_data/_data`

## Persistence verification

After all services have been implemented:

1. Start the stack and edit a WordPress page.
2. Record the change and the volume mountpoints.
3. Reboot the VM.
4. Start the stack again if necessary.
5. Verify that the page change and database contents remain.
6. Verify both volume mountpoints again.

Do not delete the volumes during this test.
