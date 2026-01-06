load("@rules_java//java:defs.bzl", "java_common")
load("//tools:zip_tree_artifacts.bzl", "zip_tree_artifacts")

def _relational_impl_gen_impl(ctx):
    out_srcjar = ctx.outputs.srcjar
    out_resjar = ctx.outputs.resources_jar
    tool = ctx.executable.tool

    # Declare directories
    gen_sources = ctx.actions.declare_directory(ctx.label.name + "_sources")
    gen_resources = ctx.actions.declare_directory(ctx.label.name + "_resources")

    # Tool args: <repo_name> <resources_dir> <sources_dir>
    # Note from genrule: platform_store_relational generated-resources generated-sources

    args = ctx.actions.args()
    args.add("platform_store_relational")
    args.add(gen_resources.path)
    args.add(gen_sources.path)

    # Tool execution
    # We also need to patch the registry.
    # Since patching modifies the output of the tool, we can do it in a subsequent action,
    # OR do it in the same shell script if we want to treat it as "generation".
    # For hermeticity, separate actions are fine but we need to declare intermediate dir if we want to modify it?
    # Actually, we can modify the directory content in place if we own the directory creation in the action.
    # The tool writes to it.

    # Let's use a single shell command for generation + patching to keep it simple and avoid copying.

    patch_script = """
    set -e
    # Run Tool
    {tool_path} "$@"
    
    # Patch Registry
    # Resolve sources dir (genrule logic: explicit check for generated-sources vs generated-test-sources is not needed if we know where tool writes)
    # The tool writes to the 3rd arg (gen_sources).
    
    SOURCES_DIR="{sources_path}"
    REGISTRY_NAME="platform_store_relationalJavaModelFactoryRegistry.java"
    TARGET_NAME="RelationalJavaModelFactoryRegistry.java"
    
    # Find registry
    FOUND_REGISTRY=$(find "$SOURCES_DIR" -name "$REGISTRY_NAME")
    if [ -z "$FOUND_REGISTRY" ]; then
         echo "Registry file $REGISTRY_NAME NOT found in $SOURCES_DIR"
         # exit 1 
         # Wait, if generation fails or produces nothing?
         # Proceeding only if found.
         exit 1
    fi
    
    DIR=$(dirname "$FOUND_REGISTRY")
    mv "$FOUND_REGISTRY" "$DIR/$TARGET_NAME"
    sed -i 's/platform_store_relational/Relational/g' "$DIR/$TARGET_NAME"
    """.format(
        tool_path = tool.path,
        sources_path = gen_sources.path,
    )

    ctx.actions.run_shell(
        outputs = [gen_sources, gen_resources],
        inputs = ctx.files.srcs,  # Inputs (par files?)
        tools = [tool],
        arguments = [args],
        command = patch_script,
        mnemonic = "RelationalImplGen",
    )

    # Zip artifacts
    zip_tree_artifacts(
        ctx,
        output = out_srcjar,
        inputs = [gen_sources],
        java_runtime_target = ctx.attr._jdk,
    )
    zip_tree_artifacts(
        ctx,
        output = out_resjar,
        inputs = [gen_resources],
        java_runtime_target = ctx.attr._jdk,
    )

    return [DefaultInfo(files = depset([out_srcjar, out_resjar]))]

relational_impl_gen = rule(
    implementation = _relational_impl_gen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "tool": attr.label(mandatory = True, executable = True, cfg = "exec"),
        "_jdk": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo],
        ),
    },
    outputs = {
        "srcjar": "%{name}.srcjar",
        "resources_jar": "%{name}_resources.jar",
    },
)
