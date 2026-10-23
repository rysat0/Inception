# User documentation

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

Only HTTPS port 443 is published. MariaDB and PHP-FPM are reached internally
by the other services; they have no separate browser interface.

## Start and stop the project

Ensure the VM and Docker are running, then start the project:

```sh
make
make ps
```

All three services (`mariadb`, `wordpress`, and `nginx`) should appear as `Up`.
The first startup may take longer while WordPress is downloaded and installed.
Use the checks below to confirm that the website is ready.

| Command | Result |
| --- | --- |
| `make stop` | Stops the services and keeps their containers and data. |
| `make` | Starts the project again and builds images if needed. |
| `make restart` | Restarts the existing containers. |
| `make down` | Removes containers and the project network, preserving website and database volumes. |
| `make re` | Removes the containers, then builds and starts the project again. Preserves the volumes. |

Saved website content survives these commands because it is stored in named
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

The database accounts are for database administration and service connections;
use a WordPress account for the website login. View password files only in a
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

Expect three services to remain `Up`, with port `443` published by NGINX.
Repeated `Restarting` or `Exited` states indicate a startup problem.
Press Ctrl+C to leave the log viewer; this does not stop the services.

For one service only, use its name:

```sh
docker compose -f srcs/docker-compose.yml logs --tail=100 wordpress
```

Replace `wordpress` with `mariadb` or `nginx` to inspect the other services.

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

## Common problems

| Symptom | What to check |
| --- | --- |
| The browser cannot find `rysato.42.fr`. | Check `/etc/hosts` on the computer running the browser and verify the VM's current IP address. |
| A certificate warning appears. | The project uses a self-signed certificate. Confirm that the address is your configured project domain before accepting it. |
| HTTP fails to connect. | Use `https://`; port 80 is not published. |
| HTTPS fails to connect. | Check that the VM and Docker are running, `make ps` shows NGINX as `Up`, and port 443 is reachable from the browser's computer. |
| The site returns `502 Bad Gateway`. | Inspect WordPress and NGINX logs; PHP-FPM may still be starting or may have exited. |
| WordPress reports a database connection error. | Inspect MariaDB and WordPress logs. Check that the database account and stored WordPress configuration agree. |
| A password file is missing or empty. | Restore the correct file listed above, then run `make`. Replacing it with a new password will not update an existing account. |
| Login fails after a password change. | Use the current WordPress password; its initial secret file may be out of date. Ask the administrator to reset the account if necessary. |
| A comment does not appear. | Check whether comments are enabled on the post and whether the comment is pending approval in the administrator's **Comments** screen. |

For environment setup and storage checks, consult the [README](README.md) and
[developer documentation](DEV_DOC.md).
