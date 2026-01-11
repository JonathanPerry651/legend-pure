# Pure Java Code Generation

This package manages the translation of Pure models into executable Java code.

## Workflow
1.  **Orchestration**: `JavaCodeGeneration.java` is the main entry point. It coordinates the generation of interfaces, implementation classes, and metadata.
2.  **Platform Standard**: `JavaModelFactoryGenerator` defines the standard class structure.

## Partitioning (`JavaSourcePartitioner`)
Due to the size of the generated code (tens of thousands of files), we cannot feed them all into `javac` at once.
*   **Input**: `dependencies.json` (produced during generation).
*   **Logic**:
    1.  Builds a dependency graph of the generated Java classes.
    2.  Finds Strongly Connected Components (SCCs) to handle cycles.
    3.  Groups SCCs into "shards" up to a max size (e.g., 2000 files).
*   **Output**: A map of Shard Name -> List of Files.
*   **Bazel Integration**: The `.bzl` rules use this map to create `java_library` targets for each shard dynamically.

## Runtime Execution (`run_shell`)
Code generation often happens within a `run_shell` action in Bazel.
*   **Tool Runfiles**: Crucially, the generator must have access to its own runtime dependencies (the compiler itself). These are passed via `inputs` in the Bazel rule.
