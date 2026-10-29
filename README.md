*This project has been created as part of the 42 curriculum by rysato.*

# Inception

## Description

Inception is a system administration project that runs a WordPress website
inside a Linux virtual machine using Docker Compose. It focuses on building
service images, configuring networking and TLS, initializing a database, and
preserving application data across container recreation and VM reboots.

The stack contains five services built from custom Dockerfiles based on
`debian:bookworm`. The mandatory services are NGINX, WordPress with PHP-FPM,
and MariaDB. Two bonus services provide a static introduction to 42 Tokyo
and the Adminer database management interface.

## Project description

### Architecture

```text
Browser
   |
   | HTTPS :443 (TLS 1.2 or TLS 1.3)
   v
 NGINX
   |-- /            -- FastCGI :9000 --> wordpress -- SQL :3306 --> mariadb
   |-- /intro/      -- HTTP    :8080 --> website
   `-- /adminer/    -- FastCGI :9000 --> adminer   -- SQL :3306 --> mariadb
```

| Service | Role | Persistent data |
| --- | --- | --- |
| `nginx` | Terminates TLS, serves WordPress static files, and routes requests to WordPress, the introduction site, and Adminer. | Reads `wordpress_data` at `/var/www/html` through a read-only mount. |
| `wordpress` | Initializes WordPress with WP-CLI and runs PHP-FPM 8.2. | Writes website files to `wordpress_data` at `/var/www/html`. |
| `mariadb` | Initializes the database and the WordPress database account, then runs MariaDB. | Stores database files in `mariadb_data` at `/var/lib/mysql`. |
| `website` | Runs a separate NGINX instance serving the HTML/CSS introduction to 42 Tokyo on internal port 8080. | Static files are copied into its image; no persistent volume. |
| `adminer` | Runs Adminer with PHP-FPM 8.2 on internal port 9000 for browser-based database access. | Application files are in its image; database changes are stored by MariaDB. |

Only NGINX publishes a host port: `443`. Port `80` is not published, so there
is no HTTP-to-HTTPS redirect. PHP-FPM and MariaDB communicate with other
containers through the Compose bridge network using service names.

### Bonus features

- **Static website:** `https://rysato.42.fr/intro/` serves a simple 42 Tokyo
  introduction written in HTML and CSS. The frontend NGINX proxies requests
  to the dedicated `website` container over HTTP. `/intro` redirects to `/intro/`.
- **Adminer:** `https://rysato.42.fr/adminer/` provides a database management
  interface. The frontend NGINX forwards FastCGI requests to the dedicated
  `adminer` container, which connects to MariaDB. `/adminer` redirects to `/adminer/`.

Both services have their own Dockerfiles and containers and are started by the
same `make` command as the mandatory services.

### Initialization and design choices

- **MariaDB:** creates its system tables when needed, then runs initialization
  SQL with `--bootstrap --skip-networking`. `FLUSH PRIVILEGES` precedes account
  operations. The `.inception-initialized` marker is written only after the SQL
  succeeds, allowing a later startup to retry an interrupted initialization.
- **WordPress:** downloads the core files and creates `wp-config.php` when
  absent. It waits for a successful database query before installing WordPress
  and creating two distinct accounts: an administrator and an author.
- **NGINX:** generates a self-signed certificate for `DOMAIN_NAME`, substitutes
  that variable into its configuration template, and checks the configuration
  before starting. Only TLS 1.2 and TLS 1.3 are enabled.
- **Process lifecycle:** the mandatory service entrypoints finish with `exec`.
  The `website` and `adminer` images use exec-form `CMD` to run NGINX and PHP-FPM
  directly in the foreground. Compose uses `restart: unless-stopped` for all
  five services.
- **Storage:** two named volumes preserve database and website files. Docker's
  data-root is configured under `/home/rysato/data` in the VM so these volumes
  satisfy the project's storage location requirement.

### Required comparisons

| Comparison | Difference and choice in this project |
| --- | --- |
| **Virtual Machines vs Docker** | A VM runs its own operating system and kernel. Containers run isolated processes that share their host's kernel. This project uses both: a Linux VM provides the host, and Docker separates the three services inside it. See [Docker's container overview](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/). |
| **Secrets vs Environment Variables** | Environment variables carry configuration such as domain and account names. Passwords come from separate Compose secret files mounted under `/run/secrets`, with access granted per service. Local Compose secrets are file mounts, not an encrypted secret store. See [Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/). |
| **Docker Network vs Host Network** | A user-defined bridge gives containers their own network interfaces and service-name resolution. Host networking shares the host's network namespace. This stack uses a [bridge network](https://docs.docker.com/engine/network/drivers/bridge/) and explicitly publishes only port 443; it does not use [host networking](https://docs.docker.com/engine/network/drivers/host/). |
| **Docker Volumes vs Bind Mounts** | Docker manages named volumes and their storage locations. Bind mounts attach a specific host path to a container. This project uses two [named volumes](https://docs.docker.com/engine/storage/volumes/) for application data, without bind-mount driver options. Secret files are mounted separately by Compose. See also [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/). |

### Included sources

```text
.
├── Makefile
├── README.md
├── DEV_DOC.md
├── DEV_DOC_JA.md
├── USER_DOC.md
├── USER_DOC_JA.md
├── Inception.pdf
└── srcs/
    ├── .env.example
    ├── docker-compose.yml
    ├── config/
    │   └── daemon.json.example
    └── requirements/
        ├── mariadb/
        ├── nginx/
        ├── wordpress/
        └── bonus/
            ├── website/
            └── adminer/
```

Each service directory contains a `Dockerfile` and configuration files in `conf/`.
The mandatory services also contain entrypoint scripts in `tools/`, and the
`website` service contains its HTML/CSS in `site/`. The local `srcs/.env` and root
`secrets/` directory are excluded from Git. User and developer guides are
available in English and Japanese.

## Instructions

### Prerequisites

Use a Linux VM with Docker Engine, the Docker Compose plugin, Make, OpenSSL,
and curl. The VM needs internet access to download packages, WP-CLI, Adminer, and
WordPress. Its clock must be synchronized for package repository and TLS checks.
Docker must be running, and the current user must be able to run Docker commands.

Official installation instructions are available for
[Ubuntu](https://docs.docker.com/engine/install/ubuntu/) and
[Debian](https://docs.docker.com/engine/install/debian/).

### 1. Get the sources

```sh
git clone https://github.com/rysat0/Inception.git
cd Inception
```

Run the remaining project commands from this directory.

### 2. Configure Docker storage

Before creating the project's volumes, configure Docker's `data-root` as
`/home/rysato/data`. If adapting the project for another login, use
`/home/<login>/data` instead.

Create the directory and edit `/etc/docker/daemon.json` with administrator
privileges. Add the following setting, preserving any existing settings:

```json
{
  "data-root": "/home/rysato/data"
}
```

Validate the configuration, restart Docker, and check the active path:

```sh
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl restart docker
docker info --format '{{.DockerRootDir}}'
```

Changing this setting does not migrate existing Docker data. The
[developer documentation](DEV_DOC.md) provides the storage setup and volume
verification procedure. See also [Docker daemon configuration](https://docs.docker.com/engine/daemon/).

### 3. Create the environment file

Create `srcs/.env` with these values, adjusting account names and email addresses
as needed:

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

The two WordPress usernames must differ. The administrator username must not
contain `admin` or `administrator`, including capitalization variants.
Use simple letters, digits, and underscores for database and database user names;
the initialization script inserts these values directly into SQL.

### 4. Create the password files

The following commands generate four independent passwords without overwriting
existing files. The hexadecimal format is compatible with the initialization SQL.

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

| File | Purpose |
| --- | --- |
| `secrets/db_root_password.txt` | MariaDB root password. |
| `secrets/db_password.txt` | Password for the WordPress database account. |
| `secrets/wp_admin_password.txt` | WordPress administrator password. |
| `secrets/wp_user_password.txt` | WordPress author password. |

Keep these files private and outside version control. WordPress also stores its
database credentials in the generated `wp-config.php` inside `wordpress_data`.

### 5. Configure domain resolution

On the machine running the browser, add an entry to `/etc/hosts` so
`rysato.42.fr` resolves to the VM's IP address:

```text
<VM_IP_ADDRESS> rysato.42.fr
```

If the browser runs inside the VM, use `127.0.0.1`. If it runs on the host
computer, use the VM address reachable from that computer. Keep this hostname
consistent with `DOMAIN_NAME`.

### 6. Build and start

```sh
docker compose -f srcs/docker-compose.yml config --quiet
make
make ps
```

The first startup downloads and installs WordPress. A container being `Up` does
not by itself mean initialization has finished; use `make logs` to inspect startup.

Open `https://rysato.42.fr/`. A certificate warning is expected because the
certificate is self-signed. After accepting it for this local project, sign in at
`https://rysato.42.fr/wp-admin/` with `WP_ADMIN_USER` and the password from
`secrets/wp_admin_password.txt`. The author account uses `WP_USER` and
`secrets/wp_user_password.txt`.

### Website addresses and Adminer login

| Page | URL |
| --- | --- |
| WordPress | `https://rysato.42.fr/` |
| WordPress administration | `https://rysato.42.fr/wp-admin/` |
| Static 42 Tokyo introduction | `https://rysato.42.fr/intro/` |
| Adminer | `https://rysato.42.fr/adminer/` |

In Adminer, select MySQL if a system selector is shown. Set the server to
`mariadb`, the username to `DB_USER`, and the database to `DB_NAME` from
`srcs/.env`. Use that database account's current password, initially supplied
by `secrets/db_password.txt`. WordPress website accounts are separate from
database accounts. Adminer receives credentials through its login form and
does not mount the password files.

See [USER_DOC.md](USER_DOC.md) or its [Japanese version](USER_DOC_JA.md) for
operation, and [DEV_DOC.md](DEV_DOC.md) or its [Japanese version](DEV_DOC_JA.md)
for development and storage details.

### Available commands

| Command | Action |
| --- | --- |
| `make` / `make up` | Build images and start the stack in the background. |
| `make build` | Build images without starting containers. |
| `make ps` | Show service status and published ports. |
| `make logs` | Follow the last 100 log lines per service; press Ctrl+C to exit. |
| `make stop` | Stop containers while keeping them and their volumes. |
| `make restart` | Restart existing containers. |
| `make down` | Remove project containers and the network, preserving named volumes. |
| `make re` | Run `down`, then rebuild and start the stack. |

`make restart` does not apply changes to images or Compose configuration.
Use `make up` after changing build files or service configuration.
Initial database and WordPress settings are applied when the relevant data is
created. Editing `.env` or secret files alone does not update existing database
passwords, WordPress account passwords, or the stored WordPress configuration.

### Verify the installation

Check WordPress initialization:

```sh
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html core is-installed
```

Check HTTPS from inside the VM without relying on a hosts-file entry:

```sh
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/
```

`-k` skips certificate verification for the self-signed certificate in this test.
An initialized site should return `HTTP/1.1 200 OK`.

Check the bonus routes and stylesheet:

```sh
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/style.css
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/adminer/
```

Expect `200 OK`, with `Content-Type: text/css` for the stylesheet. In a browser,
check the introduction page's layout, sign in to Adminer, and view an existing
WordPress table such as `wp_posts`. Also check that WordPress still works.

## Validation

The mandatory three-service stack was manually tested on an Ubuntu 22.04.5 LTS
ARM64 VM with Docker Engine 29.9.2 and Docker Compose 5.6.1. The following
results cover that earlier validation, before the bonus services were added:

- All three images built and all services remained running.
- WP-CLI reported that WordPress was installed, and HTTPS returned `200 OK`.
- The administrator could sign in, edit a page, and save it.
- The author account could sign in and submit a comment that was displayed.
- Saved content survived `make re` and a VM reboot.
- Both named volume mountpoints were under `/home/rysato/data`.
- Connections restricted to TLS 1.2 and TLS 1.3 each returned `200 OK`.
- Connecting to HTTP port 80 failed, as expected for this configuration.

For the five-service deployment, use the verification procedure above and
confirm that all five services remain running, both bonus pages work after
container recreation and a VM reboot, and saved WordPress content remains.

## Resources

- [Project subject](Inception.pdf): assignment requirements.
- [Docker Compose documentation](https://docs.docker.com/compose/): multi-service configuration and lifecycle.
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/): persistent storage.
- [Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/): per-service access to password files.
- [MariaDB installation utility](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db): database system table initialization.
- [WP-CLI installation guide](https://make.wordpress.org/cli/handbook/guides/installing/) and [commands](https://developer.wordpress.org/cli/commands/): WordPress setup and account management.
- [NGINX HTTPS configuration](https://nginx.org/en/docs/http/configuring_https_servers.html): certificates and TLS settings.
- [NGINX FastCGI module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html): forwarding PHP requests to PHP-FPM.
- [NGINX proxy module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html): forwarding HTTP requests to the static website.
- [Adminer](https://www.adminer.org/): the database management application.
- [42 Tokyo](https://42tokyo.jp/): source information for the static introduction page.

### AI assistance

AI assistance was used to explain shell syntax, SQL initialization, Docker,
FastCGI, and TLS; draft and review Dockerfiles, configuration, and startup logic;
and correct MariaDB's initialization order and completion marker. It also helped
prepare the Makefile, English and Japanese documentation, the static website's
HTML/CSS, and the Adminer container and routing configuration. VM setup and
troubleshooting were supported by AI explanations.

MariaDB initialization and retry behavior were checked with isolated tests.
The mandatory stack was built and manually exercised in the VM, including
account access, content editing, comments, persistence, and TLS connections.
