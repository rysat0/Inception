# User documentation

[日本語版](USER_DOC_JA.md)

This guide explains how to operate the Inception website after its initial
configuration. For a fresh installation, follow the [README](README.md).
Run terminal commands inside the VM from the project root, where the `Makefile`
is located.

## Services provided

| Service | What it provides |
| --- | --- |
| NGINX | The HTTPS entry point at `https://rysato.42.fr/`. |
| WordPress / PHP-FPM | The website, content editor, accounts, and comments. |
| MariaDB | Storage for posts, pages, comments, accounts, and website settings. |
| Static website (`website`) | An HTML/CSS introduction to 42 Tokyo at `https://rysato.42.fr/intro/`. |
| Adminer | Browser-based database access at `https://rysato.42.fr/adminer/`. |
| Redis | An in-memory WordPress object cache, used internally without a public URL. |

Only HTTPS port 443 is published by the frontend NGINX. It routes requests to
WordPress, the static website, and Adminer. Database access from a browser goes
through Adminer; MariaDB and PHP-FPM ports are not published on the VM.

## Start and stop the project

Ensure the VM and Docker are running, then start the project:

```sh
make
make ps
```

All six services (`mariadb`, `wordpress`, `nginx`, `website`, `adminer`, and `redis`)
should appear as `Up`.
The first startup may take longer while WordPress is downloaded and installed.
Use the checks below to confirm that the website is ready.

| Command | Result |
| --- | --- |
| `make stop` | Stops the services and keeps their containers and data. |
| `make` | Starts the project again and builds images if needed. |
| `make restart` | Restarts the existing containers. |
| `make down` | Removes containers and the project networks, preserving website and database volumes. |
| `make re` | Removes the containers, then builds and starts the project again. Preserves the volumes. |

Saved WordPress content survives these commands because it is stored in named
volumes. Deleting those volumes removes the stored data. Use `make` after a VM
reboot if the services have not started automatically.

## Access the website and administration panel

The examples use `rysato.42.fr`. If `DOMAIN_NAME` in `srcs/.env` was changed,
use the configured hostname instead.

1. On the computer running the browser, ensure `/etc/hosts` maps the hostname
   to the VM's reachable IP address. Use `127.0.0.1` when browsing inside the VM.
2. Open `https://rysato.42.fr/` to view the website.
3. Accept the self-signed certificate for this local project when the browser
   displays its certificate warning.
4. Open `https://rysato.42.fr/wp-admin/` to sign in.

Use the administrator account to manage the website and the author account
for normal content publishing. The initial account details are listed in the
credentials section below. Signing in as an author gives fewer dashboard options
than signing in as an administrator.

Always include `https://` in the address. HTTP on port 80 is not available.

| Page | URL |
| --- | --- |
| WordPress | `https://rysato.42.fr/` |
| WordPress administration | `https://rysato.42.fr/wp-admin/` |
| Static 42 Tokyo introduction | `https://rysato.42.fr/intro/` |
| Adminer | `https://rysato.42.fr/adminer/` |

`/intro` and `/adminer` redirect to the corresponding paths with a trailing `/`.
The static page is public and requires no login.

### Sign in to Adminer

Open `https://rysato.42.fr/adminer/` and enter the database account details:

| Field | Value |
| --- | --- |
| System, if shown | MySQL, which also connects to MariaDB. |
| Server | `mariadb` |
| Username | `DB_USER` from `srcs/.env`. |
| Password | The database account's current password; initially from `secrets/db_password.txt`. |
| Database | `DB_NAME` from `srcs/.env`. |

After signing in, select a table such as `wp_posts` and view its rows.
Use the database account listed above for Adminer. WordPress administrator and
author accounts belong to the WordPress website and use different credentials.
The MariaDB root account is configured for local access in the database container.

### Edit content and check comments

To edit an existing page, sign in as the administrator, open **Pages**, and
select the page. Make a change, save it using the editor's save or update button,
then open the public page to check the result. Use **Posts** to manage blog posts.

To test comments, sign in as the author, open a published post that accepts
comments, and submit a comment through its comment form. If it is awaiting
moderation, sign in as the administrator and approve it in **Comments**.
Reload the public post to confirm that it appears. Comment permissions and
moderation rules can be adjusted under **Settings > Discussion**.
See the [WordPress comments guide](https://wordpress.org/documentation/article/comments-screen/).

## Locate and manage credentials

The initial usernames are configured in `srcs/.env`. Passwords are stored in
local files under `secrets/`, relative to the project root.

| Account | Username setting | Initial password file |
| --- | --- | --- |
| WordPress administrator | `WP_ADMIN_USER` in `srcs/.env` | `secrets/wp_admin_password.txt` |
| WordPress author | `WP_USER` in `srcs/.env` | `secrets/wp_user_password.txt` |
| WordPress database account | `DB_USER` in `srcs/.env` | `secrets/db_password.txt` |
| MariaDB administrator | `root` | `secrets/db_root_password.txt` |

Use the database account for Adminer and service connections, and a WordPress
account for the WordPress website login. View password files only in a
private session. Keep `srcs/.env` and `secrets/` outside version control and
restrict password file access to the VM operator.

### Change a WordPress password

1. Sign in and open your **Profile** from the dashboard or account menu.
2. Find **Account Management** and generate or enter a new strong password.
3. Save the profile and use the new password for subsequent logins.

An administrator can also open **Users**, select another account, and set its
password. See the [WordPress profile guide](https://wordpress.org/documentation/article/users-your-profile-screen/).

The secret files contain the passwords used for initial account creation.
Changing a password in WordPress does not rewrite these files. Keep your private
credential record current; if the files are intended to record current passwords,
update them securely as well. A restart will not reset an existing WordPress
account to the password in its secret file.

Editing a database password file alone does not change the account in MariaDB.
Database password changes must be coordinated with the existing database account
and WordPress's stored `wp-config.php`; ask the VM operator to perform them.
This stack does not configure an email delivery service, so do not rely on
password-reset email for account recovery.

## Check that the services are running correctly

### Container status and logs

```sh
make ps
make logs
```

Expect all six services to remain `Up`, with port `443` published by NGINX.
Repeated `Restarting` or `Exited` states indicate a startup problem.
Press Ctrl+C to leave the log viewer; this does not stop the services.

For one service only, use its name:

```sh
docker compose -f srcs/docker-compose.yml logs --tail=100 wordpress
```

Replace `wordpress` with `mariadb`, `nginx`, `website`, `adminer`, or `redis` to inspect
the other services.

### WordPress and database readiness

```sh
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html core is-installed \
    && echo "WordPress initialization: OK"
```

The success message confirms that WordPress is installed. Check that WordPress
can query its database:

```sh
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html db query 'SELECT 1;' --connect-timeout=2
```

The query should succeed and return `1`.

### HTTPS response

Run this inside the VM:

```sh
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/
```

An initialized website should return `HTTP/1.1 200 OK`. Here `--resolve` directs
the request to the local VM without depending on `/etc/hosts`, and `-k` skips
certificate verification for the self-signed certificate. Also open the website
in a browser and check that saved content is visible.

### Static website and Adminer

```sh
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/style.css
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/adminer/
```

Expect `200 OK`; the stylesheet should have `Content-Type: text/css`.
In a browser, check that the introduction page is styled and that Adminer can
sign in and display the existing WordPress tables. Also check the WordPress
homepage and dashboard after rebuilding or rebooting the VM.

The static website files and Adminer application are included in their images.
The developer must rebuild the relevant image after editing source files.
Database changes made through Adminer are stored in MariaDB's existing volume.

### Redis object cache

Redis is enabled automatically when WordPress starts. It caches objects across
requests; posts, accounts, and other persistent data remain in MariaDB.
Restarting Redis discards its cache, which WordPress rebuilds as needed.

```sh
docker compose -f srcs/docker-compose.yml exec redis redis-cli ping
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html redis status
```

Expect `PONG` and a connected cache with a valid drop-in. An administrator can
also check **Settings > Redis** in the WordPress dashboard. Redis uses a
dedicated internal network shared with WordPress and has no public port or login page.
Redis is a runtime dependency; WordPress requests may fail while it is unavailable.

## Common problems

| Symptom | What to check |
| --- | --- |
| The browser cannot find `rysato.42.fr`. | Check `/etc/hosts` on the computer running the browser and verify the VM's current IP address. |
| A certificate warning appears. | The project uses a self-signed certificate. Confirm that the address is your configured project domain before accepting it. |
| HTTP fails to connect. | Use `https://`; port 80 is not published. |
| HTTPS fails to connect. | Check that the VM and Docker are running, `make ps` shows NGINX as `Up`, and port 443 is reachable from the browser's computer. |
| A page returns `502 Bad Gateway`. | Inspect NGINX and the target service logs: `website` for `/intro/`, `adminer` for `/adminer/`, or `wordpress` for the WordPress site. |
| The introduction page has no styling or shows old content. | Check `/intro/style.css`, rebuild with `make up` after source changes, and reload the page without the browser cache. |
| Adminer rejects the login. | Use server `mariadb`, `DB_USER`, `DB_NAME`, and the current database password. Check MariaDB's logs and account settings. |
| WordPress reports a database connection error. | Inspect MariaDB and WordPress logs. Check that the database account and stored WordPress configuration agree. |
| WordPress reports a Redis connection error. | Check that `redis` is running, inspect its logs, and run the Redis checks above. Use `make up` to start the complete stack. |
| A password file is missing or empty. | Restore the correct file listed above, then run `make`. Replacing it with a new password will not update an existing account. |
| Login fails after a password change. | Use the current WordPress password; its initial secret file may be out of date. Ask the administrator to reset the account if necessary. |
| A comment does not appear. | Check whether comments are enabled on the post and whether the comment is pending approval in the administrator's **Comments** screen. |

For environment setup and storage checks, consult the [README](README.md) and
[developer documentation](DEV_DOC.md).
