# Legend Pure Index

`legend-pure` contains the definition and implementation of the Pure language.

## Modules

### [Core](legend-pure-core/README.md)
The heart of the language.
*   **M3 Core**: The meta-metamodel definitions.
*   **M4**: The low-level graphing structure.

### [Runtime](legend-pure-runtime/README.md)
Execution engines for Pure.
*   [Compiled](legend-pure-runtime/legend-pure-runtime-java-engine-compiled/src/main/java/org/finos/legend/pure/runtime/java/compiled/generation/README.md): Compiles Pure to Java.
*   **Interpreted**: Runs Pure directly (slower, used for REPL/IDE).
*   [Serialization](legend-pure-runtime/legend-pure-runtime-java-engine-compiled/src/main/java/org/finos/legend/pure/runtime/java/compiled/serialization/binary/README.md): Logic for persisting the Pure graph.

### [DSL](legend-pure-dsl/README.md)
Domain Specific Languages built on top of Pure.
*   **Diagram**: Visualization.
*   **Graph**: Core graph structures.
*   **Mapping**: Model-to-model mapping.
*   **TDS**: Tabular Data Structures.

### [Store](legend-pure-store/README.md)
Store implementations.
*   **Relational**: SQL database interaction.
