# Pure Build Rules (`pure.bzl`)

This directory contains the core build logic for the Pure language, specifically the `pure_generation` and `pure_par` rules defined in `pure.bzl` (located in `tools/build_rules` or loaded here).

## Key Concepts

### Metadata Partitioning
Large Pure models are too big to compile as a single unit or even a single Java compilation target. We use **Partitioning** to split them.
*   **Metadata Analysis**: The build analyzes the Pure graph (`FunctionType`, `Class`, etc.) to find dependencies.
*   **Shard Generation**: Based on the graph, sources are grouped into "shards" (e.g., `shard01`, `shard02`).
*   **Parallel Compilation**: Each shard is compiled to Java independently.

### `pure_par` behavior
1.  **Generate**: Runs the `PureJarGenerator` tool to produce Java sources and metadata files (`bin`, `idx`).
2.  **Partition**: Uses `JavaSourcePartitioner` (consuming `dependencies.json`) to split sources.
3.  **Compile**: Invokes `java_library` for each partition.
4.  **Archive**: Bundles everything into a final JAR.

## Critical Files
*   `pure.bzl`: The Starlark implementation.
*   `platform.properties`: Generated file containing version information.
