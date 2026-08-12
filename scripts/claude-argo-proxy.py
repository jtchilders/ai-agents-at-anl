#!/usr/bin/env python3
"""Local HTTP proxy that forwards Claude Code requests to Argo over an SSH tunnel.

Claude Code talks plain HTTP to this proxy on 127.0.0.1:8083. The proxy rewrites the
Host header and forwards each request to 127.0.0.1:8082, which is an SSH -L tunnel to
apps.inside.anl.gov:443 (Argo). This lets you use Argo from a laptop that is off the
Argonne network.

Usage (see guides/claude-code-argo.md, Option B):
    Terminal 1:  ssh -L 8082:apps.inside.anl.gov:443 -N homes.cels.anl.gov
    Terminal 2:  python3 scripts/claude-argo-proxy.py
    Terminal 3:  ANTHROPIC_BASE_URL="http://127.0.0.1:8083/argoapi/" \
                 ANTHROPIC_AUTH_TOKEN="$USER" \
                 CLAUDE_CODE_SKIP_ANTHROPIC_AUTH=1 claude
"""
import aiohttp
import aiohttp.web

LISTEN_PORT = 8083
TARGET_HOST = "apps.inside.anl.gov"
TUNNEL_HOST = "127.0.0.1"
TARGET_PORT = 8082


async def proxy_request(request):
    # Reach Argo via the local end of the SSH tunnel, preserving the request path.
    url = f"https://{TUNNEL_HOST}:{TARGET_PORT}{request.path_qs}"

    # Copy headers, override Host so Argo's vhost routing works over the tunnel.
    headers = dict(request.headers)
    headers["Host"] = TARGET_HOST
    headers.pop("Content-Length", None)

    body = await request.read()

    ssl_ctx = False  # tunnel terminates TLS at Argo; skip local cert verification

    async with aiohttp.ClientSession() as session:
        try:
            async with session.request(
                method=request.method,
                url=url,
                headers=headers,
                data=body if body else None,
                ssl=ssl_ctx,
                allow_redirects=False,
            ) as resp:
                # Stream the response back to Claude Code (needed for SSE streaming).
                response = aiohttp.web.StreamResponse(
                    status=resp.status,
                    headers={
                        k: v
                        for k, v in resp.headers.items()
                        if k.lower() not in ("transfer-encoding", "content-encoding")
                    },
                )
                await response.prepare(request)
                async for chunk in resp.content.iter_any():
                    await response.write(chunk)
                await response.write_eof()
                return response

        except Exception as e:
            print(f"ERROR: {request.method} {request.path} - {type(e).__name__}: {e}")
            return aiohttp.web.Response(status=500, text=str(e))


app = aiohttp.web.Application()
app.router.add_route("*", "/{path_info:.*}", proxy_request)

if __name__ == "__main__":
    print(f"Argo proxy listening on http://127.0.0.1:{LISTEN_PORT}")
    aiohttp.web.run_app(app, host="127.0.0.1", port=LISTEN_PORT, print=None)
