# client_application

Commands, queries and persistence ports for the common UI/CLI/MCP application
path. Transactional command deduplication and Operation Log orchestration live
here. Search is exposed through application-owned ports; the current adapter is
a rebuildable projection and is not a public Isar dependency.
