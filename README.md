# arnauabella.net

## Run With Docker Compose

Start the site in the background:

```sh
docker compose up -d
```

Restart the Zola container:

```sh
docker compose restart zola-server
```

To update Zola, change the `image` tag in `docker-compose.yaml` to the desired
release, then pull the image and recreate the container:

```sh
docker compose pull zola-server
docker compose up -d --force-recreate --no-build zola-server
```

Show live logs:

```sh
docker compose logs -f zola-server
```

Show the last 100 log lines:

```sh
docker compose logs --tail=100 zola-server
```
