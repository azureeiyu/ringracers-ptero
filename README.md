# Dr. Robotnik's Ring Racers Pterodactyl Egg

A fully self-contained [Pterodactyl](https://pterodactyl.io) egg and Docker image for running a dedicated [Dr. Robotnik's Ring Racers](https://www.kartkrew.org/) v2.4 server.

---

## Disclaimer

This image and its accompanying Pterodactyl egg were developed with the assistance of **Claude** (Anthropic AI). While tested and functional, please review the Dockerfile and egg configuration before deploying in a production environment.

---

## Features

- **Zero setup** — game binary and all data files are compiled and baked into the image at build time. No manual downloads required on install.
- **Automatic mod loading** — place addon files (`.pk3`, `.wad`) into the appropriate subdirectory and they are loaded automatically on server start in the correct order:
  - `addons/loadfirst/` — dependency mods
  - `addons/chars/` — character packs
  - `addons/tracks/` — map packs
  - `addons/loadlast/` — anything that needs to load after everything else
- **Built-in mod file server** — a lightweight nginx instance runs alongside Ring Racers on a second allocated port, serving your addons folder over HTTP. Clients automatically download missing mods on join when a public URL is configured.
- **Automatic `http_source` management** — set the `HTTP_SOURCE` variable in Pterodactyl and the entrypoint script writes it to `ringserv.cfg` automatically on every start. No manual config editing needed.
- **Pterodactyl-native** — runs as UID 1000 (`container` user), fully compatible with Wings. Startup command, variables, and port allocations all work through the standard Pterodactyl interface.

---

## Requirements

- Pterodactyl Panel with Wings
- Two port allocations on your node — one for the game (UDP/TCP) and one for the mod file server (TCP)
- A way to make the mod file server publicly accessible, either:
  - **Direct** — a Pterodactyl node with a public IP and the HTTP port open on your firewall, or
  - **Reverse proxy** — a reverse proxy such as Nginx Proxy Manager forwarding a public URL to your node (recommended for home lab / NAT setups)

---

## Usage

### 1. Import the egg

Download the egg JSON from this repository and import it into your Pterodactyl panel under **Admin → Nests → Import Egg**.

➡️ [Download egg-ring-racers.json](https://github.com/azureeiyu/ringracers-ptero/raw/main/egg-ring-racers.json)

### 2. Create a server

Create a new server using the egg. Configure the following variables:

| Variable | Description |
|---|---|
| `SERVER_NAME` | Name shown in the server browser |
| `MAX_PLAYERS` | Maximum players (2-16, recommended 8 or fewer) |
| `HTTP_PORT` | Port for the mod file server (must be a second allocated port) |
| `HTTP_SOURCE` | Public URL where clients download mods (e.g. `http://rr.yourdomain.com/repo`) |
| `EXTRA_PARAMS` | Any additional launch arguments |

### 3. Install and start

Run the install script and start the server. The install script creates the addon directory structure automatically:

```
addons/
├── chars/
├── tracks/
├── loadfirst/
└── loadlast/
```

### 4. Set up mod file serving

There are two ways to make the mod file server publicly accessible:

**Option A — Direct (public IP, no reverse proxy)**

If your Pterodactyl node has a public IP address, open the HTTP port on your firewall and set `HTTP_SOURCE` to:

```
http://YOUR_PUBLIC_IP:HTTP_PORT/repo
```

**Option B — Reverse proxy (recommended for home labs / NAT setups)**

Add a custom location `/repo/` on your proxy host forwarding to `YOUR_SERVER_IP:HTTP_PORT`, then set `HTTP_SOURCE` to your public domain:

```
http://rr.yourdomain.com/repo
```

### 5. Add mods

Upload mod files to the appropriate subdirectory via the Pterodactyl file manager. Restart the server — mods load automatically and clients download them on join.

---

## Notes

- Ring Racers does not support SRV records — players must specify the port when connecting (e.g. `rr.yourdomain.com:40004`)
- UDP must be enabled on your firewall and any reverse proxy streams for the game port
- The mod file server only requires TCP
- The `http_source` URL in `ringserv.cfg` is overwritten automatically on each start from the `HTTP_SOURCE` variable — do not edit it manually
- Ring Racers plays best with 8 or fewer players — the game itself warns you when joining servers with more than 8

---

## Source

- Dr. Robotnik's Ring Racers: https://www.kartkrew.org/
- Ring Racers GitHub: https://github.com/KartKrewDev/RingRacers
- Pterodactyl: https://pterodactyl.io
- Docker Hub: https://hub.docker.com/r/trishjoushi/ringracers-ptero
- GitHub: https://github.com/azureeiyu/ringracers-ptero
# ringracers-ptero
