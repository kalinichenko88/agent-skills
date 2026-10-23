# kalinichenko:docker

Every image that a Dockerfile or a compose file names is the newest stable
release, pinned exactly, on the smallest base that runs the app.

## When it starts

- You write or review a Dockerfile, a compose file, a `.dockerignore` or a
  container entrypoint script.
- You add or bump an image: `FROM`, `COPY --from`, `image:` under a service.
- You choose a base image, or set up Dependabot or Renovate for images.
- A container takes ten seconds to stop.

## What you get

- **A version looked up today, not recalled.** The agent reads the release
  lines and the registry tags, and confirms that the tag resolves. The
  project's runtime pin chooses the line. A pre-release is never used.
- **An exact pin.** `node:<x.y.z>-alpine`, never `node:<x>-alpine`, `latest`
  or a bare name. The OS release stays out of the tag, so updaters can keep
  moving it. An image without version tags is pinned by digest.
- **Something that bumps the pin.** Renovate or Dependabot covers every file
  the change touched. On GitHub, the missing Dependabot entries go into the
  same change.
- **No surprise migrations.** An image that the task is not about keeps its
  major and its variant. A database keeps the major and the distribution that
  its volume was made with. The agent asks before it moves either.
- **The smallest base.** Distroless for a static binary. `-alpine` for Node,
  Python, Ruby and compose services. `-slim` only when a dependency ships
  glibc-only binaries, with a comment that names it.
- **A `.dockerignore` next to every `COPY . .`.** It keeps out secrets, `.git`,
  installed dependencies and build output.
- **A clean stop.** The server gets SIGTERM, through `init: true`, `tini` or
  its own handler. An entrypoint script ends with `exec`.
