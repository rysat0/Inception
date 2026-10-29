# Developer documentation

[日本語版](DEV_DOC_JA.md)

This guide covers environment setup, configuration, builds, container management,
and persistent storage. For the architecture and design comparisons, see the
[README](README.md). For website operation, see [USER_DOC.md](USER_DOC.md).

## Set up the environment from scratch

### Prerequisites

Use a Linux VM with systemd and administrator access. The full stack has been
tested on Ubuntu 22.04.5 LTS ARM64. The container images use Debian Bookworm
regardless of the VM's distribution.

On Ubuntu or Debian, install the host tools:

```sh
sudo apt-get update
sudo apt-get install -y git make openssl curl
```

Install Docker Engine and its Compose plugin using the official instructions for
[Ubuntu](https://docs.docker.com/engine/install/ubuntu/) or
[Debian](https://docs.docker.com/engine/install/debian/). The Makefile uses
`docker compose`, so the standalone legacy `docker-compose` command is not enough.
Configure Docker access for the account that will run Make, then verify:

```sh
docker version
docker compose version
timedatectl status
```

Both Docker client and server information must be available. Ensure the VM has
internet access and a synchronized clock; builds fetch packages, WP-CLI, and Adminer,
and the first WordPress startup downloads the core files.

Clone the repository:

```sh
git clone https://github.com/rysat0/Inception.git
cd Inception
```

Run the remaining project commands from this root directory. The examples use
the login `rysato`; replace it with your own login when adapting the project.

### Configure Docker storage before the first build

The two application volumes must be stored under `/home/<login>/data` in the VM.
This project uses Docker named volumes without bind-mount driver options, so
configure the regular, rootful Docker daemon's `data-root` before creating them.

If Docker already contains data that must be preserved, plan its migration
first. Changing `data-root` does not move existing data.

Create the directories and edit Docker's configuration:

```sh
sudo mkdir -p /home/rysato/data /etc/docker
sudoedit /etc/docker/daemon.json
```

Add the following setting, preserving any other settings already in the file.
The repository also includes [a configuration example](srcs/config/daemon.json.example).

```json
{
  "data-root": "/home/rysato/data"
}
```

Validate the configuration and restart Docker:

```sh
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl restart docker
docker info --format '{{.DockerRootDir}}'
```

The last command must print `/home/rysato/data`. This setting governs the named
volume location. On fresh Docker Engine 29+ installations using the containerd
image store, image contents and snapshots use containerd's separate storage;
`data-root` does not relocate that storage. See
[Docker daemon configuration](https://docs.docker.com/engine/daemon/).

### Create the environment file

Create the ignored file `srcs/.env`:

```dotenv
DB_NAME=wordpress
DB_USER=wpuser
DOMAIN_NAME=rysato.42.fr
WP_TITLE="Inception"
WP_ADMIN_USER=rysato_owner
WP_ADMIN_EMAIL=owner@example.com
WP_USER=rysato_author
WP_USER_EMAIL=author@example.com
```

All eight variables are required by Compose. The WordPress usernames must be
different, and the administrator username must not contain `admin` or
`administrator`, including capitalization variants. Replace the sample email
addresses with the intended account addresses.

Use letters, digits, and underscores for `DB_NAME` and `DB_USER`. The current
MariaDB initialization SQL interpolates configuration directly and does not
escape arbitrary SQL characters.

### Create secrets

Generate the four required password files, keeping any existing files:

```sh
umask 077
mkdir -p secrets
for name in db_root_password db_password wp_admin_password wp_user_password; do
    secret_file="secrets/$name.txt"
    if [ ! -e "$secret_file" ]; then
        openssl rand -hex 24 > "$secret_file"
    fi
done
```

The hexadecimal passwords avoid quotation characters that the initialization SQL
does not escape. Existing files must also contain nonempty, compatible passwords.

| Host file | Container secret | Services with access |
| --- | --- | --- |
| `secrets/db_root_password.txt` | `/run/secrets/db_root_password` | MariaDB |
| `secrets/db_password.txt` | `/run/secrets/db_password` | MariaDB, WordPress |
| `secrets/wp_admin_password.txt` | `/run/secrets/wp_admin_password` | WordPress |
| `secrets/wp_user_password.txt` | `/run/secrets/wp_user_password` | WordPress |

Compose resolves these host paths relative to `srcs/docker-compose.yml`.
The entrypoints read the files using their corresponding `*_PASSWORD_FILE`
environment variables. Keep `.env` and password files local; `.gitignore`
excludes `srcs/.env` and `secrets/*`.

### Configure domain resolution

On the computer running the browser, add the VM's reachable IP address and
`rysato.42.fr` to `/etc/hosts`. Use `127.0.0.1` if browsing inside the VM.
The hostname must match `DOMAIN_NAME`. NGINX publishes port 443; configure the
VM's networking so that the browser can reach this port.

## Build and launch

Validate configuration without printing the resolved environment, then build
and launch the stack:

```sh
docker compose -f srcs/docker-compose.yml config --quiet
make
make ps
```

`make` defaults to `up`, which runs
`docker compose -f srcs/docker-compose.yml up -d --build`.
To build without starting containers, use `make build`.

The Compose project name is `inception`. It builds five local images:
`mariadb:inception`, `wordpress:inception`, `nginx:inception`,
`website:inception`, and `adminer:inception`.
The mandatory services use entrypoint scripts. The two bonus services run
NGINX or PHP-FPM directly using exec-form `CMD`.

All five services are included in the same Compose file and start with `make`.
Only the frontend NGINX publishes a host port. The `website` service listens
internally on 8080, while WordPress and Adminer each listen on 9000 in their
own containers. Separate containers can use the same internal port number.

`depends_on` sets startup order; it does not establish application readiness.
WordPress therefore retries a database query up to 30 times before proceeding.
Follow startup output with `make logs`; Ctrl+C exits the viewer without stopping
the containers.

## Develop and manage containers

| Source | Purpose |
| --- | --- |
| `Makefile` | Build and lifecycle commands. |
| `srcs/docker-compose.yml` | Service wiring, configuration, secrets, volumes, and network. |
| `srcs/requirements/<service>/Dockerfile` | Packages, copied files, and entrypoint for each image. |
| `srcs/requirements/<service>/conf/` | MariaDB, PHP-FPM, and NGINX configuration. |
| `srcs/requirements/<service>/tools/entrypoint.sh` | Startup validation and initialization. |
| `srcs/requirements/bonus/website/` | Static site Dockerfile, NGINX configuration, and `site/` HTML/CSS. |
| `srcs/requirements/bonus/adminer/` | Adminer Dockerfile and PHP-FPM pool configuration. |

Dockerfiles copy configuration and scripts into images. After editing them, run
`make up` to rebuild and let Compose recreate affected containers. For a complete
container recreation, use `make re`; it retains both data volumes. A simple
`make restart` runs existing containers and does not apply image or Compose
configuration changes. See the [Compose up reference](https://docs.docker.com/reference/cli/docker/compose/up/).

Useful inspection commands:

```sh
docker compose -f srcs/docker-compose.yml ps -a
docker compose -f srcs/docker-compose.yml images
docker compose -f srcs/docker-compose.yml logs --tail=100 mariadb
docker compose -f srcs/docker-compose.yml exec wordpress sh
docker compose -f srcs/docker-compose.yml exec nginx nginx -t
docker compose -f srcs/docker-compose.yml exec website nginx -t
docker compose -f srcs/docker-compose.yml exec adminer php-fpm8.2 -t
docker compose -f srcs/docker-compose.yml exec adminer php -l /var/www/adminer/index.php
docker network inspect inception_inception
```

Use `exit` to leave the container shell. Changes made directly in a container's
writable layer disappear when that container is recreated; update source files
and rebuild to retain code or configuration changes.

Use `make stop` to stop containers, `make restart` to restart them, and `make down`
to remove containers and the network. The Makefile's `down` target does not pass
`--volumes`, so it preserves the named volumes. See the
[Compose down reference](https://docs.docker.com/reference/cli/docker/compose/down/).

### Initialization and changes to existing data

- MariaDB creates system tables if `/var/lib/mysql/mysql` is missing. It runs
  the initialization SQL if `/var/lib/mysql/.inception-initialized` is absent,
  and creates that marker only after success. `FLUSH PRIVILEGES` must remain
  before the account statements in bootstrap mode.
- WordPress downloads core files when `wp-load.php` is absent, creates
  `wp-config.php` when absent, and installs the site only if it is not already
  installed. It creates the author account only if that username does not exist.
- NGINX creates its certificate and key when either file is missing or empty.
  They live in the container filesystem, so container recreation generates a
  new certificate. The NGINX configuration is generated on every startup.

Changing `.env` or secret files does not migrate existing database accounts,
WordPress passwords, the saved site URL, or `wp-config.php`. Handle those as
explicit changes to the existing application and database. In particular,
coordinate a database password change with the WordPress configuration stored
in its volume. Removing the MariaDB marker is not a password rotation procedure.

## Develop the bonus services

### Static introduction site

Edit `srcs/requirements/bonus/website/site/index.html` and `style.css`.
The Dockerfile copies `site/` to `/var/www/website` in the `website` image.
Its NGINX configuration is in
`srcs/requirements/bonus/website/conf/website.conf` and listens on 8080.

In the frontend's `srcs/requirements/nginx/conf/nginx.conf`, `/intro` redirects
to `/intro/`, and the `/intro/` location proxies HTTP to `website:8080`.
The trailing `/` in `proxy_pass http://website:8080/;` replaces the `/intro/`
prefix with `/` when forwarding requests. Relative asset links such as
`./style.css` therefore work under the public prefix.

After editing the static files or server configuration, rebuild:

```sh
make up
```

Static files are copied into the image rather than bind-mounted from the host.
Rebuilding applies source changes; restarting an existing container alone
does not. This service does not require a persistent volume.

### Adminer database interface

`srcs/requirements/bonus/adminer/Dockerfile` installs PHP-FPM, PHP CLI, and the
MySQL extension on Debian Bookworm. It downloads the pinned Adminer 6.2.0
MySQL/MariaDB distribution as `/var/www/adminer/index.php` and checks it with
`php -l` during the build. Its pool configuration is
`srcs/requirements/bonus/adminer/conf/www.conf`; it uses on-demand workers
and listens on 9000.

The frontend redirects `/adminer` to `/adminer/` and uses a dedicated FastCGI
location with `fastcgi_pass adminer:9000`. It passes the fixed
`SCRIPT_FILENAME` `/var/www/adminer/index.php`, which is a path inside the
Adminer container. The frontend does not need a copy of this PHP file.

Adminer connects to MariaDB over the bridge network. Use server `mariadb`,
`DB_USER`, `DB_NAME`, and the current database password in its login form;
the initial password is stored in `secrets/db_password.txt`.
No additional environment variables, secret files, or persistent volumes are
needed for these two bonus services. Adminer does not mount the password files.
For the login procedure, see [USER_DOC.md](USER_DOC.md).

## Manage volumes and locate project data

| Compose volume | Docker volume name | Container path | Contents |
| --- | --- | --- | --- |
| `mariadb_data` | `inception_mariadb_data` | `/var/lib/mysql` in MariaDB | System tables, website database, and initialization marker. |
| `wordpress_data` | `inception_wordpress_data` | `/var/www/html` in WordPress and NGINX | WordPress core, configuration, themes, plugins, and uploaded files. |

WordPress has read-write access to its files; NGINX mounts the same volume
read-only. MariaDB's volume uses `nocopy: true` so the entrypoint initializes
the database rather than relying on image contents copied into the volume.

List the project's volumes and inspect their actual locations:

```sh
docker volume ls --filter label=com.docker.compose.project=inception
docker volume inspect inception_mariadb_data inception_wordpress_data \
    --format '{{.Name}}: {{.Mountpoint}}'
```

With the storage configuration above, the expected mountpoints are:

- `/home/rysato/data/volumes/inception_mariadb_data/_data`
- `/home/rysato/data/volumes/inception_wordpress_data/_data`

Posts, pages, comments, and accounts are stored in MariaDB. Website files and
uploads are stored in the WordPress volume. Both volumes outlive container
replacement and normal VM reboots. The WordPress volume also contains database
credentials in `wp-config.php`, so treat its contents as private.

The bonus services do not add data volumes: static files and the Adminer
application are part of their images. Adminer operates on the database stored
in `mariadb_data`. Its login session is not persisted by a dedicated volume,
so signing in again may be necessary after container recreation.

Do not edit MariaDB's raw database files while the server is running. Volume
deletion, including `docker compose down --volumes`, removes persistent data
and is not part of the normal rebuild workflow.

## Verify a development change

After `make up`, inspect status and logs, then check WordPress, database access,
and HTTPS from inside the VM:

```sh
make ps
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html core is-installed \
    && echo "WordPress initialization: OK"
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html db query 'SELECT 1;' --connect-timeout=2
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/style.css
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/adminer/
```

Expect the initialization success message, a successful query returning `1`,
and `HTTP/1.1 200 OK`. The curl options bypass local DNS and certificate
verification for this self-signed local setup. Also test the changed behavior
in a browser; container status alone does not establish application correctness.

Expect all five services to remain running. Check that the static stylesheet
is served as `text/css` and the introduction page renders correctly. Sign in
to Adminer and inspect an existing table such as `wp_posts`.
Also check that `/intro` and `/adminer` return redirects to the slash-terminated
URLs, and that the WordPress homepage and dashboard still work.

For a persistence check:

1. Edit and save a WordPress page, then record the content and volume mountpoints.
2. Run `make re` and confirm that the saved content remains.
3. Reboot the VM and run `make` if the stack does not start automatically.
4. Confirm that the page and accounts remain available and inspect the volume
   mountpoints again.
5. Open `/intro/` and `/adminer/` again. Check the static page and sign in to
   Adminer to confirm that the existing WordPress tables remain accessible.

Keep both volumes throughout this check. Existing VM validation results are
recorded in the [README](README.md#validation).
