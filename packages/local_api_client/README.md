# local_api_client

Typed UI/CLI/MCP-facing Local API client. The current adapter connects directly
to loopback and bypasses external HTTP proxies.

JSON commands remain bounded separately from attachment transfer. Attachment
upload/download uses backpressured streams, a longer transfer deadline, and the
same loopback session proof without buffering the full payload in the client.
