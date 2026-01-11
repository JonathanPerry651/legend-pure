# Pure Graph Serialization

This package handles the binary serialization and deserialization of the Pure graph. This is critical for:
*   **Performance**: Loading pre-compiled graphs starting is much faster than parsing text.
*   **Incremental Builds**: Allowing valid parts of the graph to be reused.
*   **Distribution**: Sending compiled models to execution nodes.

## Critical Components

### `DistributedBinaryRepositorySerializer`
Responsible for writing the graph elements of a specific repository (e.g., `platform`, `core`) to binary format.

**Key Logic: Orphan Adoption**
A critical fix was implemented here to handle `FunctionType` instances.
*   **Problem**: Generated `FunctionType` instances (e.g., from `GenericType` references) often reside in the `platform` codebase but are logically attributed to the `core` repository (or have no source).
*   **Issue**: The `platform` serializer would skip them ("different source"), and the `core` serializer would miss them ("not reachable").
*   **Fix**: The serializer explicitly **allows** `FunctionType` instances to be serialized even if `isFromDifferentSource()` returns true. This ensures they are not "orphaned" and lost, preventing `UnknownInstanceException`.

### `MetadataLazy`
Handles the lazy loading of graph nodes. It uses the `.idx` files to locate exactly which binary partition contains a requested node ID.
