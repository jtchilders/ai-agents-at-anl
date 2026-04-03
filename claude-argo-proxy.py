#!/usr/bin/env python3
import asyncio
import aiohttp
import aiohttp.web

LISTEN_PORT = 8083
TARGET_HOST = "apps.inside.anl.gov"
TUNNEL_HOST = "127.0.0.1"
TARGET_PORT = 8082

async def proxy_request(request):
    # Build target URL using tunnel host but with correct path
    url = f"https://{TUNNEL_HOST}:{TARGET_PORT}{request.path_qs}"
    
    # Copy headers, override Host
    headers = dict(request.headers)
    headers["Host"] = TARGET_HOST
    headers.pop("Content-Length", None)

    body = await request.read()

    ssl_ctx = False  # skip cert verification

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
                # Stream response back to client
                response = aiohttp.web.StreamResponse(
                    status=resp.status,
                    headers={k: v for k, v in resp.headers.items()
                             if k.lower() not in ('transfer-encoding', 'content-encoding')}
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
